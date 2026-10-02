#requires -Version 7.2

Describe 'TypeVault core project' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $script:content = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
        $script:launcher = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'TypeVault.py') -Raw -Encoding utf8
    }

    It 'has exactly one current-release changelog heading' {
        $changelog = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'CHANGELOG.md') -Raw -Encoding utf8
        ([regex]::Matches($changelog, '(?m)^## 1\.7\.0 - 2026-10-01$')).Count | Should -Be 1
    }

    It 'declares the current release version' {
        $script:content | Should -Match "\$script:Version = '1.7.0'"
    }

    It 'targets Windows and PowerShell 7.2+' {
        $script:content | Should -Match '#requires -Version 7.2'
        $script:content | Should -Match '\$IsWindows'
        $script:content | Should -Match 'Windows 11 build 22000 or later'
    }

    It 'uses Windows DPAPI through SecureString conversion' {
        $script:content | Should -Match 'ConvertFrom-SecureString'
        $script:content | Should -Match 'ConvertTo-SecureString'
    }

    It 'uses Win32 SendInput and does not use SendKeys' {
        $script:content | Should -Match 'SendInput'
        $script:content | Should -Not -Match '\bSendKeys::|\.SendKeys\b'
    }

    It 'uses the full Win32 INPUT union layout' {
        $script:content | Should -Match 'public MOUSEINPUT mi;'
        $script:content | Should -Match 'public KEYBDINPUT ki;'
        $script:content | Should -Match 'public HARDWAREINPUT hi;'
        $script:content | Should -Match 'Marshal.SizeOf<INPUT>()'
    }

    It 'protects local credential data from accidental Git inclusion' {
        $gitignore = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' '.gitignore') -Raw -Encoding utf8
        $gitignore | Should -Match '(?m)^Credentials/$'
        $gitignore | Should -Match '(?m)^Settings\.json$'
    }

    It 'keeps all runtime data outside the project directory' {
        $script:content | Should -Match '\$script:RootPath = Join-Path \$env:LOCALAPPDATA \$script:AppName'
        $script:content | Should -Not -Match '\$PSScriptRoot.*(Set-Content|Add-Content|Out-File|WriteAllText|WriteAllBytes|FileStream)'
        $script:content | Should -Not -Match '\$script:SettingsPath'
    }

    It 'does not implement a disable-authentication escape hatch' {
        $script:content | Should -Not -Match 'ValidateSet\(.*Disabled'
        $script:content | Should -Not -Match 'Disable authentication'
        $script:content | Should -Not -Match "AuthenticationMode = 'Disabled'"
        $script:content | Should -Not -Match 'Set-AuthenticationMode'
        $script:content | Should -Not -Match 'Save-Settings'
        $script:content | Should -Not -Match 'Get-Settings'
    }

    It 'authenticates before selecting the destination window' {
        $invokeType = ($script:content -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
        $invokeType | Should -Match '\$ownerWindow = \[TypeVault.NativeMethods\]::GetActiveWindowHandle\(\)'
    }

    It 'requires Windows Hello before decrypting a credential' {
        $invokeType = ($script:content -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $decryptIndex = $invokeType.IndexOf('\$password = Get-CredentialPassword')
        $authIndex | Should -BeGreaterThan -1
        $decryptIndex | Should -BeGreaterThan $authIndex
    }

    It 'checks the target window before typing and again before Enter' {
        $script:content | Should -Match 'Target window changed before keyboard input was sent'
        $script:content | Should -Match 'Target window changed before Enter was sent'
    }

    It 'supports a zero delay without requiring an additional foreground switch' {
        $script:content | Should -Match '\$DelayMs -eq 0'
    }

    It 'preserves profile creation time and tracks updates separately' {
        $script:content | Should -Match 'CreatedUtc = \$createdUtc'
        $script:content | Should -Match 'UpdatedUtc = '
    }

    It 'rejects Windows reserved device names' {
        $script:content | Should -Match 'COM|LPT'
        $script:content | Should -Match 'reserved by Windows'
        $script:content | Should -Match "'CON', 'PRN', 'AUX', 'NUL'"
    }

    It 'rejects trailing spaces and full stops in profile names' {
        $script:content | Should -Match '\\[ \.\\]\
    }

    It 'validates profile metadata before decryption' {
        $script:content | Should -Match 'Credential profile metadata does not match'
    }

    It 'protects profile deletion with ShouldProcess' {
        $script:content | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'provides Back and Exit navigation' {
        $script:content | Should -Match '\[0\] Back'
        $script:content | Should -Match '\[0\] Exit'
        $script:content | Should -Match 'return \$null'
    }

    It 'provides a separate interactive Windows Hello integration test' {
        $script:content | Should -Match "'TestHello'"
        $script:content | Should -Match '\[8\] Test Windows Hello'
        $script:content | Should -Match 'Invoke-WindowsHelloTest'
    }

    It 'keeps Windows Hello mandatory in the main menu' {
        $script:content | Should -Match '\[6\] Authentication status'
        $script:content | Should -Match 'Windows Hello \(required\)'
        $script:content | Should -Match 'Windows Hello is required before every credential is typed'
    }

    It 'does not create Settings.json during normal operation' {
        $script:content | Should -Not -Match 'Settings\.json'
    }

    It 'prevents Python bytecode generation' {
        $script:launcher | Should -Match 'dont_write_bytecode = True'
    }

    It 'uses a fixed-width menu renderer' {
        $script:content | Should -Match '\$script:MenuWidth = 62'
        $script:content | Should -Match 'PadRight\(\$script:MenuWidth\)'
        $script:content | Should -Match 'Write-MenuBorder'
        $script:content | Should -Match 'Write-MenuCentered'
    }

    It 'provides the restored diagnostic banner' {
        $script:content | Should -Match 'function Show-Banner'
        $script:content | Should -Match 'Secure Credential Manager'
    }

    It 'uses a three-second post-authentication default delay' {
        $script:content | Should -Match '\$DelayMilliseconds = 3000'
    }
}


Describe 'Target window capture' {
    It 'captures only the final foreground window after the post-authentication countdown' {
        $script:content | Should -Match 'Capture only the final foreground window when the countdown has ended'
        $script:content | Should -Not -Match 'Target window changed during the countdown'
    }
}

Describe 'Authentication-first interactive target flow' {
    BeforeAll {
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'TypeVault.ps1') -Raw -Encoding utf8
    }

    It 'authenticates before selecting the destination window' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
    }

    It 'uses the active TypeVault window as the Windows Hello owner' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $invokeType | Should -Match '\$ownerWindow = \[TypeVault\.NativeMethods\]::GetActiveWindowHandle\(\)'
        $invokeType | Should -Match 'Invoke-WindowsHelloAuthentication -OwnerWindow \$ownerWindow'
    }

    It 'does not decrypt the credential until the destination foreground check has passed' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $decryptIndex = $invokeType.IndexOf('\$password = Get-CredentialPassword')
        $focusIndex = $invokeType.IndexOf('The destination window is no longer in the foreground')
        $decryptIndex | Should -BeGreaterThan $focusIndex
    }

    It 'does not minimise or restore TypeVault during the typing workflow' {
        $source | Should -Not -Match 'MinimiseWindow\('
        $source | Should -Not -Match 'RestoreWindow\('
        $source | Should -Not -Match 'SetForegroundWindow\(\$ownerWindow\)'
    }

    It 'describes the required post-authentication countdown' {
        $source | Should -Match 'Switch to the destination window and leave the required field active'
        $source | Should -Match 'Typing will begin after \$delaySeconds second\(s\)'
    }
}

Describe 'Windows Hello interactive flow' {
    BeforeAll {
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'TypeVault.ps1') -Raw -Encoding utf8
    }

    It 'gets the TypeVault foreground window before authentication' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $ownerIndex = $invokeType.IndexOf('$ownerWindow = [TypeVault.NativeMethods]::GetActiveWindowHandle()')
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication -OwnerWindow $ownerWindow')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $ownerIndex | Should -BeGreaterThan -1
        $authIndex | Should -BeGreaterThan $ownerIndex
        $targetIndex | Should -BeGreaterThan $authIndex
    }

    It 'performs no destination capture before authentication' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
        $beforeAuth = $invokeType.Substring(0, $authIndex)
        $beforeAuth | Should -Not -Match 'Select-TypeTargetWindow'
        $beforeAuth | Should -Not -Match 'Wait-ForTargetWindow'
    }

    It 'starts the post-authentication delay through the target selector' {
        $selector = ($source -split 'function Select-TypeTargetWindow \{', 2)[1]
        $selector | Should -Match 'Start-Sleep -Milliseconds \$DelayMs'
        $selector | Should -Match 'Capture only the final foreground window when the countdown has ended'
    }

    It 'decrypts only after authentication and destination focus validation' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $focusIndex = $invokeType.IndexOf('The destination window is no longer in the foreground')
        $decryptIndex = $invokeType.IndexOf('$password = Get-CredentialPassword')
        $authIndex | Should -BeGreaterThan -1
        $focusIndex | Should -BeGreaterThan $authIndex
        $decryptIndex | Should -BeGreaterThan $focusIndex
    }

    It 'does not minimise or force TypeVault back to the foreground during the workflow' {
        $source | Should -Not -Match 'MinimiseWindow\('
        $source | Should -Not -Match 'RestoreWindow\('
        $source | Should -Not -Match 'SetForegroundWindow\(\$ownerWindow\)'
    }
}

Describe 'Windows Hello test path' {
    It 'keeps TestHello independent from stored credential data' {
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $content = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
        $helloTest = ($content -split 'function Invoke-WindowsHelloTest \{', 2)[1]
        $helloTest | Should -Not -Match 'Get-CredentialPassword'
        $helloTest | Should -Not -Match 'Decrypt'
        $helloTest | Should -Not -Match 'TypeUnicode'
        $helloTest | Should -Match 'Invoke-WindowsHelloAuthentication'
    }
}

    }

    It 'validates profile metadata before decryption' {
        $script:content | Should -Match 'Credential profile metadata does not match'
    }

    It 'protects profile deletion with ShouldProcess' {
        $script:content | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'provides Back and Exit navigation' {
        $script:content | Should -Match '\[0\] Back'
        $script:content | Should -Match '\[0\] Exit'
        $script:content | Should -Match 'return \$null'
    }

    It 'provides a separate interactive Windows Hello integration test' {
        $script:content | Should -Match "'TestHello'"
        $script:content | Should -Match '\[8\] Test Windows Hello'
        $script:content | Should -Match 'Invoke-WindowsHelloTest'
    }

    It 'keeps Windows Hello mandatory in the main menu' {
        $script:content | Should -Match '\[6\] Authentication status'
        $script:content | Should -Match 'Windows Hello \(required\)'
        $script:content | Should -Match 'Windows Hello is required before every credential is typed'
    }

    It 'does not create Settings.json during normal operation' {
        $script:content | Should -Not -Match 'Settings\.json'
    }

    It 'prevents Python bytecode generation' {
        $script:launcher | Should -Match 'dont_write_bytecode = True'
    }

    It 'uses a fixed-width menu renderer' {
        $script:content | Should -Match '\$script:MenuWidth = 62'
        $script:content | Should -Match 'PadRight\(\$script:MenuWidth\)'
        $script:content | Should -Match 'Write-MenuBorder'
        $script:content | Should -Match 'Write-MenuCentered'
    }

    It 'provides the restored diagnostic banner' {
        $script:content | Should -Match 'function Show-Banner'
        $script:content | Should -Match 'Secure Credential Manager'
    }

    It 'uses a three-second post-authentication default delay' {
        $script:content | Should -Match '\$DelayMilliseconds = 3000'
    }
}


Describe 'Target window capture' {
    It 'captures only the final foreground window after the post-authentication countdown' {
        $script:content | Should -Match 'Capture only the final foreground window when the countdown has ended'
        $script:content | Should -Not -Match 'Target window changed during the countdown'
    }
}

Describe 'Authentication-first interactive target flow' {
    BeforeAll {
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'TypeVault.ps1') -Raw -Encoding utf8
    }

    It 'authenticates before selecting the destination window' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
    }

    It 'uses the active TypeVault window as the Windows Hello owner' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $invokeType | Should -Match '\$ownerWindow = \[TypeVault\.NativeMethods\]::GetActiveWindowHandle\(\)'
        $invokeType | Should -Match 'Invoke-WindowsHelloAuthentication -OwnerWindow \$ownerWindow'
    }

    It 'does not decrypt the credential until the destination foreground check has passed' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $decryptIndex = $invokeType.IndexOf('\$password = Get-CredentialPassword')
        $focusIndex = $invokeType.IndexOf('The destination window is no longer in the foreground')
        $decryptIndex | Should -BeGreaterThan $focusIndex
    }

    It 'does not minimise or restore TypeVault during the typing workflow' {
        $source | Should -Not -Match 'MinimiseWindow\('
        $source | Should -Not -Match 'RestoreWindow\('
        $source | Should -Not -Match 'SetForegroundWindow\(\$ownerWindow\)'
    }

    It 'describes the required post-authentication countdown' {
        $source | Should -Match 'Switch to the destination window and leave the required field active'
        $source | Should -Match 'Typing will begin after \$delaySeconds second\(s\)'
    }
}

Describe 'Windows Hello interactive flow' {
    BeforeAll {
        $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' 'TypeVault.ps1') -Raw -Encoding utf8
    }

    It 'gets the TypeVault foreground window before authentication' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $ownerIndex = $invokeType.IndexOf('$ownerWindow = [TypeVault.NativeMethods]::GetActiveWindowHandle()')
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication -OwnerWindow $ownerWindow')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $ownerIndex | Should -BeGreaterThan -1
        $authIndex | Should -BeGreaterThan $ownerIndex
        $targetIndex | Should -BeGreaterThan $authIndex
    }

    It 'performs no destination capture before authentication' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
        $beforeAuth = $invokeType.Substring(0, $authIndex)
        $beforeAuth | Should -Not -Match 'Select-TypeTargetWindow'
        $beforeAuth | Should -Not -Match 'Wait-ForTargetWindow'
    }

    It 'starts the post-authentication delay through the target selector' {
        $selector = ($source -split 'function Select-TypeTargetWindow \{', 2)[1]
        $selector | Should -Match 'Start-Sleep -Milliseconds \$DelayMs'
        $selector | Should -Match 'Capture only the final foreground window when the countdown has ended'
    }

    It 'decrypts only after authentication and destination focus validation' {
        $invokeType = ($source -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $focusIndex = $invokeType.IndexOf('The destination window is no longer in the foreground')
        $decryptIndex = $invokeType.IndexOf('$password = Get-CredentialPassword')
        $authIndex | Should -BeGreaterThan -1
        $focusIndex | Should -BeGreaterThan $authIndex
        $decryptIndex | Should -BeGreaterThan $focusIndex
    }

    It 'does not minimise or force TypeVault back to the foreground during the workflow' {
        $source | Should -Not -Match 'MinimiseWindow\('
        $source | Should -Not -Match 'RestoreWindow\('
        $source | Should -Not -Match 'SetForegroundWindow\(\$ownerWindow\)'
    }
}

Describe 'Windows Hello test path' {
    It 'keeps TestHello independent from stored credential data' {
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $content = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
        $helloTest = ($content -split 'function Invoke-WindowsHelloTest \{', 2)[1]
        $helloTest | Should -Not -Match 'Get-CredentialPassword'
        $helloTest | Should -Not -Match 'Decrypt'
        $helloTest | Should -Not -Match 'TypeUnicode'
        $helloTest | Should -Match 'Invoke-WindowsHelloAuthentication'
    }
}
