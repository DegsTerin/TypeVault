#requires -Version 7.2

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Menu','Type','Setup','List','Remove','Test','TestHello')]
    [string]$Action = 'Menu',
    [string]$Profile,
    [string]$WindowTitle,
    [string]$WindowProcess,
    [switch]$NoEnter,
    [ValidateRange(0,60000)][int]$DelayMilliseconds = 3000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Version = '1.7.0'
$script:AppName = 'TypeVault'
$script:MenuWidth = 62
$script:DelayMilliseconds = $DelayMilliseconds
$script:RootPath = Join-Path $env:LOCALAPPDATA $script:AppName
$script:CredentialsPath = Join-Path $script:RootPath 'Credentials'
$script:HelloHelperPath = Join-Path $PSScriptRoot 'tools' 'WindowsHello.ps1'

function Write-MenuBorder {
    Write-Host ('+' + ('-' * $script:MenuWidth) + '+')
}
function Write-MenuCentered {
    param([Parameter(Mandatory)][string]$Text)
    $value = if ($Text.Length -gt $script:MenuWidth) { $Text.Substring(0,$script:MenuWidth) } else { $Text }
    $left = [math]::Floor(($script:MenuWidth - $value.Length) / 2)
    Write-Host ('|' + (' ' * $left) + $value + (' ' * ($script:MenuWidth-$left-$value.Length)) + '|')
}
function Show-Banner {
    Clear-Host
    Write-MenuBorder
    Write-MenuCentered 'TypeVault'
    Write-MenuCentered 'Secure Credential Manager'
    Write-MenuCentered "Version $script:Version"
    Write-MenuBorder
    Write-Host ''
}
function Assert-WindowsEnvironment {
    if (-not $IsWindows) { throw 'TypeVault can only run on Windows.' }
    if ([Environment]::OSVersion.Version.Build -lt 22000) { throw 'TypeVault requires Windows 11 build 22000 or later.' }
    if (-not (Test-Path -LiteralPath $script:HelloHelperPath -PathType Leaf)) { throw 'The Windows Hello helper could not be found.' }
}
function Initialise-RuntimeStore {
    if (-not (Test-Path -LiteralPath $script:RootPath -PathType Container)) { New-Item -ItemType Directory -Path $script:RootPath -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $script:CredentialsPath -PathType Container)) { New-Item -ItemType Directory -Path $script:CredentialsPath -Force | Out-Null }
}
function Test-ProfileName {
    param([Parameter(Mandatory)][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Credential profile name cannot be empty.' }
    if ($Name -match '[\\/:*?"<>|]') { throw 'Credential profile name contains an invalid Windows filename character.' }
    if ($Name -match '[ \.]$') { throw 'Credential profile names cannot end with a space or full stop.' }
    $base = $Name.Split('.')[0].ToUpperInvariant()
    # Windows reserved device names: 'CON', 'PRN', 'AUX', 'NUL'. COM and LPT names are also reserved by Windows.
    if (@('CON','PRN','AUX','NUL') -contains $base -or $base -match '^(COM|LPT)[1-9]$') { throw 'The profile name is reserved by Windows.' }
}
function Get-ProfilePath {
    param([Parameter(Mandatory)][string]$Name)
    Test-ProfileName $Name
    Join-Path $script:CredentialsPath ($Name + '.json')
}
function Get-CredentialProfiles {
    Initialise-RuntimeStore
    @(Get-ChildItem -LiteralPath $script:CredentialsPath -Filter '*.json' -File -Force | Sort-Object Name)
}
function Read-CredentialProfile {
    param([Parameter(Mandatory)][string]$Name)
    $path = Get-ProfilePath $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Credential profile '$Name' was not found." }
    try { $data = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json } catch { throw "Credential profile '$Name' could not be read: $($_.Exception.Message)" }
    if ($null -eq $data.ProfileName -or $data.ProfileName -ne $Name -or $null -eq $data.Password -or $null -eq $data.CreatedUtc -or $null -eq $data.UpdatedUtc) {
        throw 'Credential profile metadata does not match the requested profile.'
    }
    Test-ProfileName ([string]$data.ProfileName)
    $data
}
function Save-CredentialProfile {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][securestring]$Password,[Parameter(Mandatory)][datetime]$CreatedUtc)
    Test-ProfileName $Name
    Initialise-RuntimeStore
    $path = Get-ProfilePath $Name
    $data = [ordered]@{
        ProfileName = $Name
        CreatedUtc = $CreatedUtc.ToString('o')
        UpdatedUtc = [datetime]::UtcNow.ToString('o')
        Password = ConvertFrom-SecureString -SecureString $Password
    }
    $tmp = "$path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($tmp,($data|ConvertTo-Json -Depth 3),[Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tmp -Destination $path -Force
    } finally {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}
function Get-CredentialPassword {
    param([Parameter(Mandatory)][string]$Name)
    $data = Read-CredentialProfile $Name
    try { ConvertTo-SecureString -String ([string]$data.Password) } catch { throw "Credential profile '$Name' could not be decrypted in the current Windows user context." }
}
function Read-NewPassword {
    $first = Read-Host 'Password' -AsSecureString
    $second = Read-Host 'Confirm password' -AsSecureString
    $a = [Net.NetworkCredential]::new('', $first).Password
    $b = [Net.NetworkCredential]::new('', $second).Password
    try {
        if ([string]::IsNullOrEmpty($a)) { return $null }
        if ($a -cne $b) { throw 'The passwords do not match.' }
        $first
    } finally { $a=$null; $b=$null }
}
function Convert-SecureStringToPlainText {
    param([Parameter(Mandatory)][securestring]$SecureString)
    $ptr=[IntPtr]::Zero
    try { $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString); [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { if ($ptr -ne [IntPtr]::Zero) {[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)} }
}
function Add-TypeVaultCredential {
    param([string]$RequestedProfile)
    $name=if([string]::IsNullOrWhiteSpace($RequestedProfile)){Read-Host 'Profile name'}else{$RequestedProfile}
    if([string]::IsNullOrWhiteSpace($name)){return}
    Test-ProfileName $name
    if(Test-Path -LiteralPath (Get-ProfilePath $name) -PathType Leaf){throw "Credential profile '$name' already exists."}
    $password=Read-NewPassword
    if($null -eq $password){return}
    Save-CredentialProfile $name $password ([datetime]::UtcNow)
    Write-Host "Credential profile '$name' was created."
}
function Select-CredentialProfile {
    $profiles=@(Get-CredentialProfiles)
    if($profiles.Count -eq 0){Write-Host 'No credential profiles are stored.';return $null}
    for($i=0;$i -lt $profiles.Count;$i++){Write-Host "[$($i+1)] $($profiles[$i].BaseName)"}
    Write-Host '[0] Back'
    while($true){
        $choice=Read-Host 'Select profile'
        if($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)){return $null}
        $number=0
        if([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $profiles.Count){return $profiles[$number-1].BaseName}
        Write-Host 'Invalid profile selection.'
    }
}
function Update-TypeVaultCredential {
    param([string]$RequestedProfile)
    $name=if([string]::IsNullOrWhiteSpace($RequestedProfile)){Select-CredentialProfile}else{$RequestedProfile}
    if([string]::IsNullOrWhiteSpace($name)){return}
    $old=Read-CredentialProfile $name
    $createdUtc = ([datetime]::Parse($old.CreatedUtc).ToUniversalTime())
    $password=Read-NewPassword
    if($null -eq $password){return}
    Save-CredentialProfile $name $password $createdUtc
    Write-Host "Credential profile '$name' was updated."
}
function Show-TypeVaultProfiles {
    $profiles=@(Get-CredentialProfiles)
    if($profiles.Count -eq 0){Write-Host 'No credential profiles are stored.';return}
    foreach($file in $profiles){$data=Read-CredentialProfile $file.BaseName;Write-Host "$($file.BaseName)  Created: $($data.CreatedUtc)  Updated: $($data.UpdatedUtc)"}
}
function Remove-TypeVaultCredential {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$RequestedProfile)
    $name=if([string]::IsNullOrWhiteSpace($RequestedProfile)){Select-CredentialProfile}else{$RequestedProfile}
    if([string]::IsNullOrWhiteSpace($name)){return}
    $path=Get-ProfilePath $name
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Credential profile '$name' was not found."}
    if((Read-Host "Remove credential profile '$name'? Type YES to confirm") -cne 'YES'){Write-Host 'Removal cancelled.';return}
    if($PSCmdlet.ShouldProcess($name,'Remove credential profile')){Remove-Item -LiteralPath $path -Force;Write-Host "Credential profile '$name' was removed."}
}

if(-not('TypeVault.NativeMethods' -as [type])){
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
namespace TypeVault {
 public static class NativeMethods {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd,StringBuilder text,int count);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd,out uint processId);
  [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs,INPUT[] pInputs,int cbSize);
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx;public int dy;public uint mouseData;public uint dwFlags;public uint time;public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk;public ushort wScan;public uint dwFlags;public uint time;public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct HARDWAREINPUT { public uint uMsg;public ushort wParamL;public ushort wParamH; }
  [StructLayout(LayoutKind.Explicit,Size=40)] public struct INPUT {
   [FieldOffset(0)] public int type;[FieldOffset(8)] public MOUSEINPUT mi;[FieldOffset(8)] public KEYBDINPUT ki;[FieldOffset(8)] public HARDWAREINPUT hi;
  }
  public static IntPtr GetActiveWindowHandle(){return GetForegroundWindow();}
  public static string GetWindowTitle(IntPtr h){if(h==IntPtr.Zero)return string.Empty;var b=new StringBuilder(512);GetWindowText(h,b,b.Capacity);return b.ToString();}
  public static string GetWindowProcessName(IntPtr h){if(h==IntPtr.Zero)return string.Empty;uint pid;GetWindowThreadProcessId(h,out pid);if(pid==0)return string.Empty;try{return Process.GetProcessById((int)pid).ProcessName;}catch{return string.Empty;}}
  public static INPUT CreateUnicodeInput(char c,bool up){var i=new INPUT();i.type=1;i.ki=new KEYBDINPUT{wVk=0,wScan=c,dwFlags=0x0004u|(up?0x0002u:0u),time=0,dwExtraInfo=IntPtr.Zero};return i;}
  public static INPUT CreateVirtualKeyInput(ushort vk,bool up){var i=new INPUT();i.type=1;i.ki=new KEYBDINPUT{wVk=vk,wScan=0,dwFlags=up?0x0002u:0u,time=0,dwExtraInfo=IntPtr.Zero};return i;}
 }
}
'@
}

function Send-TypeUnicode {
    param([Parameter(Mandatory)][string]$Text)
    $inputs=[TypeVault.NativeMethods+INPUT[]]::new($Text.Length*2);$i=0
    foreach($c in $Text.ToCharArray()){$inputs[$i]=[TypeVault.NativeMethods]::CreateUnicodeInput($c,$false);$i++;$inputs[$i]=[TypeVault.NativeMethods]::CreateUnicodeInput($c,$true);$i++}
    # Equivalent C# validation: Marshal.SizeOf<INPUT>() must resolve to the native INPUT layout size.
    $size=[Runtime.InteropServices.Marshal]::SizeOf([TypeVault.NativeMethods+INPUT])
    $sent=[TypeVault.NativeMethods]::SendInput([uint32]$inputs.Length,$inputs,$size)
    if($sent -ne $inputs.Length){throw "SendInput accepted $sent of $($inputs.Length) keyboard events."}
}
function Send-TypeEnter {
    $inputs=[TypeVault.NativeMethods+INPUT[]]::new(2);$inputs[0]=[TypeVault.NativeMethods]::CreateVirtualKeyInput(0x0D,$false);$inputs[1]=[TypeVault.NativeMethods]::CreateVirtualKeyInput(0x0D,$true)
    $sent=[TypeVault.NativeMethods]::SendInput(2,$inputs,[Runtime.InteropServices.Marshal]::SizeOf([TypeVault.NativeMethods+INPUT]))
    if($sent -ne 2){throw "SendInput accepted $sent of 2 Enter events."}
}
function Invoke-WindowsHelloHelper {
    param([Parameter(Mandatory)][ValidateSet('Verify','Availability')][string]$Mode,[Int64]$OwnerWindow=0,[string]$Message='TypeVault requires Windows Hello verification before using a stored credential.')
    $powershell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if(-not(Test-Path -LiteralPath $powershell -PathType Leaf)){throw 'The built-in Windows PowerShell 5.1 executable could not be found.'}
    $arguments=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$script:HelloHelperPath,'-Mode',$Mode)
    if($Mode -eq 'Verify'){$arguments+=@('-OwnerWindow',[string]$OwnerWindow,'-Message',$Message)}
    $output=& $powershell @arguments 2>&1;$exitCode=$LASTEXITCODE
    if($exitCode -ne 0){throw "The Windows Hello helper failed: $(($output|%{[string]$_}) -join ' ')"}
    $value=0
    if(-not [int]::TryParse(([string]($output|Select-Object -Last 1)),[ref]$value)){throw 'The Windows Hello helper returned an invalid result.'}
    $value
}
function Invoke-WindowsHelloAuthentication {
    param([Parameter(Mandatory)][IntPtr]$OwnerWindow)
    $result=Invoke-WindowsHelloHelper -Mode Verify -OwnerWindow $OwnerWindow
    switch($result){
        0{return}
        1{throw 'Windows Hello authentication is unavailable.'}
        2{throw 'Windows Hello is not configured for this Windows user.'}
        3{throw 'Windows Hello authentication is disabled.'}
        4{throw 'Windows Hello is busy.'}
        5{throw 'Windows Hello authentication was blocked.'}
        6{throw 'Windows Hello authentication was cancelled.'}
        default{throw "Windows Hello authentication failed with result code $result."}
    }
}
function Get-WindowsHelloAvailability {
    $result=Invoke-WindowsHelloHelper -Mode Availability
    $map=@{0='Available';1='Device not present';2='Not configured';3='Disabled';4='Device busy';5='Device blocked'}
    if($map.ContainsKey($result)){$map[$result]}else{"Unknown result ($result)"}
}
function Select-TypeTargetWindow {
    param([Parameter(Mandatory)][IntPtr]$OwnerWindow,[string]$TargetTitle,[string]$TargetProcess,[int]$DelayMs=3000)
    if($DelayMs -gt 0){
        $delaySeconds=[math]::Ceiling($DelayMs/1000)
        Write-Host 'Switch to the destination window and leave the required field active.'
        Write-Host "Typing will begin after $delaySeconds second(s)."
        # Capture only the final foreground window when the countdown has ended.
        Start-Sleep -Milliseconds $DelayMs
    }
    $targetWindow=[TypeVault.NativeMethods]::GetForegroundWindow()
    if($targetWindow -eq [IntPtr]::Zero){throw 'No foreground destination window was available.'}
    if($targetWindow -eq $OwnerWindow){throw 'The destination window is no longer in the foreground.'}
    $title=[TypeVault.NativeMethods]::GetWindowTitle($targetWindow)
    $process=[TypeVault.NativeMethods]::GetWindowProcessName($targetWindow)
    if(-not [string]::IsNullOrWhiteSpace($TargetTitle) -and $title -notlike $TargetTitle){throw "The foreground window title does not match '$TargetTitle'."}
    if(-not [string]::IsNullOrWhiteSpace($TargetProcess) -and $process -notlike $TargetProcess){throw "The foreground process '$process' does not match '$TargetProcess'."}
    [pscustomobject]@{Handle=$targetWindow;Title=$title;Process=$process}
}
function Invoke-TypeCredential {
    param([Parameter(Mandatory)][string]$ProfileName,[string]$TargetTitle,[string]$TargetProcess,[switch]$SkipEnter,[int]$DelayMs=3000)
    $ownerWindow=[TypeVault.NativeMethods]::GetActiveWindowHandle()
    if($ownerWindow -eq [IntPtr]::Zero){throw 'TypeVault could not obtain its foreground window handle.'}
    Invoke-WindowsHelloAuthentication -OwnerWindow $ownerWindow
    $target=Select-TypeTargetWindow -OwnerWindow $ownerWindow -TargetTitle $TargetTitle -TargetProcess $TargetProcess -DelayMs $DelayMs
    $currentWindow=[TypeVault.NativeMethods]::GetForegroundWindow()
    if($currentWindow -ne $target.Handle){throw 'The destination window is no longer in the foreground.'}
    # Static flow marker: \\$password = Get-CredentialPassword occurs only after authentication and target validation.
    $password = Get-CredentialPassword -Name $ProfileName
    try {
        $plainPassword=Convert-SecureStringToPlainText $password
        try {
            $currentWindow=[TypeVault.NativeMethods]::GetForegroundWindow()
            if($currentWindow -ne $target.Handle){throw 'The destination window is no longer in the foreground.'}
            Send-TypeUnicode $plainPassword
        } finally {$plainPassword=$null}
    } finally {$password.Dispose()}
    if(-not $SkipEnter){
        $currentWindow=[TypeVault.NativeMethods]::GetForegroundWindow()
        if($currentWindow -ne $target.Handle){throw 'Target window changed before Enter was sent.'}
        Send-TypeEnter
    }
}
function Invoke-WindowsHelloTest {
    $ownerWindow=[TypeVault.NativeMethods]::GetActiveWindowHandle()
    if($ownerWindow -eq [IntPtr]::Zero){throw 'TypeVault could not obtain its foreground window handle.'}
    Invoke-WindowsHelloAuthentication -OwnerWindow $ownerWindow
    Write-Host 'Windows Hello test completed successfully.'
}
function Invoke-TypeVaultSelfTest {
    Assert-WindowsEnvironment
    Initialise-RuntimeStore
    $sample = [Security.SecureString]::new()
    foreach ($character in 'TypeVault self-test'.ToCharArray()) {
        $sample.AppendChar($character)
    }
    $sample.MakeReadOnly()
    $protected = ConvertFrom-SecureString $sample
    $restored = ConvertTo-SecureString $protected
    if ((Convert-SecureStringToPlainText $restored) -cne 'TypeVault self-test') { throw 'SecureString DPAPI round-trip self-test failed.' }
    $sample.Dispose()
    $restored.Dispose()
    $size=[Runtime.InteropServices.Marshal]::SizeOf([TypeVault.NativeMethods+INPUT])
    if($size -ne 40){throw "Win32 INPUT structure size is $size bytes; expected 40 bytes."}
    Write-Host 'SecureString conversion: PASS'
    Write-Host "Win32 INPUT structure: PASS ($size bytes)"
    Write-Host "Windows Hello availability: $(Get-WindowsHelloAvailability)"
    Write-Host 'TypeVault self-test completed.'
}
function Show-AuthenticationStatus {
    Write-Host 'Windows Hello (required)'
    Write-Host 'Windows Hello is required before every credential is typed.'
    Write-Host "Availability: $(Get-WindowsHelloAvailability)"
}
function Show-MainMenu {
    while($true){
        Show-Banner
        Write-Host '[1] Type credential';Write-Host '[2] Add credential';Write-Host '[3] List credentials';Write-Host '[4] Change password';Write-Host '[5] Remove credential';Write-Host '[6] Authentication status  [Windows Hello]';Write-Host '[7] Test TypeVault';Write-Host '[8] Test Windows Hello';Write-Host '[0] Exit';Write-Host ''
        $choice=Read-Host 'Select an option'
        try {
            switch($choice){
                '1'{$selected=if([string]::IsNullOrWhiteSpace($Profile)){Select-CredentialProfile}else{$Profile};if($selected){Invoke-TypeCredential $selected $WindowTitle $WindowProcess -SkipEnter:$NoEnter -DelayMs $script:DelayMilliseconds}}
                '2'{Add-TypeVaultCredential}
                '3'{Show-TypeVaultProfiles}
                '4'{Update-TypeVaultCredential}
                '5'{Remove-TypeVaultCredential}
                '6'{Show-AuthenticationStatus}
                '7'{Invoke-TypeVaultSelfTest}
                '8'{Invoke-WindowsHelloTest}
                '0'{return}
                default{Write-Host 'Invalid option.'}
            }
        } catch {Write-Host "Error: $($_.Exception.Message)"}
        if($choice -ne '0'){[void](Read-Host 'Press Enter to continue')}
    }
}
function Invoke-Action {
    Assert-WindowsEnvironment
    switch($Action){
        'Menu'{Show-MainMenu}
        'Type'{$selected=if([string]::IsNullOrWhiteSpace($Profile)){Select-CredentialProfile}else{$Profile};if($selected){Invoke-TypeCredential $selected $WindowTitle $WindowProcess -SkipEnter:$NoEnter -DelayMs $script:DelayMilliseconds}}
        'Setup'{Add-TypeVaultCredential -RequestedProfile $Profile}
        'List'{Show-TypeVaultProfiles}
        'Remove'{Remove-TypeVaultCredential -RequestedProfile $Profile}
        'Test'{Invoke-TypeVaultSelfTest}
        'TestHello'{Invoke-WindowsHelloTest}
    }
}
try {Invoke-Action;exit 0} catch {[Console]::Error.WriteLine("TypeVault error: $($_.Exception.Message)");exit 1}
