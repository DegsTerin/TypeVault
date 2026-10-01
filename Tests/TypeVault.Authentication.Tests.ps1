#requires -Version 7.2

Describe 'TypeVault Windows Hello integration' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $helperPath = Join-Path $PSScriptRoot '..' 'tools' 'WindowsHello.ps1'
        $script:content = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
        $script:helperContent = Get-Content -LiteralPath $helperPath -Raw -Encoding utf8
    }

    It 'uses the dedicated Windows PowerShell 5.1 WinRT bridge' {
        $script:content | Should -Match 'WindowsPowerShell\\v1\.0\\powershell\.exe'
        $script:content | Should -Match 'tools\\WindowsHello\.ps1'
        $script:content | Should -Match "Invoke-WindowsHelloHelper -Mode Verify"
        $script:helperContent | Should -Match 'IUserConsentVerifierInterop'
        $script:helperContent | Should -Match 'WindowsRuntimeMarshal\.GetActivationFactory'
        $script:helperContent | Should -Match 'RequestVerificationForWindowAsync'
        $script:helperContent | Should -Match 'typeof\(IAsyncOperation<UserConsentVerificationResult>\)\.GUID'
    }

    It 'uses the documented desktop Windows Hello owner-window API' {
        $script:helperContent | Should -Match '39E050C3-4E74-441A-8DC0-B81104DF949C'
        $script:helperContent | Should -Match 'IntPtr appWindow'
        $script:helperContent | Should -Match 'IAsyncOperation<UserConsentVerificationResult>'
    }

    It 'waits for the projected asynchronous result instead of manually driving the ABI' {
        $script:helperContent | Should -Match 'WindowsRuntimeSystemExtensions\.AsTask\(operation\)'
        $script:helperContent | Should -Match 'GetAwaiter\(\)\.GetResult\(\)'
        $script:content | Should -Not -Match 'RoGetActivationFactory'
        $script:content | Should -Not -Match 'RequestVerificationForWindowDelegate'
        $script:content | Should -Not -Match 'IAsyncOperationCompletedHandler'
        $script:content | Should -Not -Match 'GetStatusDelegate'
        $script:content | Should -Not -Match 'PutCompletedSlot'
    }

    It 'uses CheckAvailabilityAsync for the authentication status screen' {
        $script:content | Should -Match 'Get-WindowsHelloAvailability'
        $script:content | Should -Match 'UserConsentVerifierAvailability'
        $script:helperContent | Should -Match 'CheckAvailabilityAsync'
    }

    It 'handles all documented verification result codes' {
        $script:content | Should -Match "1 \{ throw 'Windows Hello authentication is unavailable"
        $script:content | Should -Match "2 \{ throw 'Windows Hello is not configured"
        $script:content | Should -Match "3 \{ throw 'Windows Hello authentication is disabled"
        $script:content | Should -Match "4 \{ throw 'Windows Hello is busy"
        $script:content | Should -Match "5 \{ throw 'Windows Hello authentication was blocked"
        $script:content | Should -Match "6 \{ throw 'Windows Hello authentication was cancelled"
    }

    It 'does not allow authentication failure to continue' {
        $authFunction = ($script:content -split 'function Invoke-WindowsHelloAuthentication \{', 2)[1]
        $authFunction | Should -Match 'throw'
        $authFunction | Should -Match 'Invoke-WindowsHelloHelper -Mode Verify'
    }

    It 'keeps authentication mandatory' {
        $script:content | Should -Not -Match 'SettingsPath'
        $script:content | Should -Not -Match 'Disable authentication'
        $script:content | Should -Not -Match 'AuthenticationMode'
        $script:content | Should -Match 'Windows Hello \(required\)'
    }
}

Describe 'Windows Hello interactive flow' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $script:content = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
    }

    It 'gets the TypeVault foreground window before authentication' {
        $invokeType = ($script:content -split 'function Invoke-TypeCredential \{', 2)[1]
        $ownerIndex = $invokeType.IndexOf('$ownerWindow = [TypeVault.NativeMethods]::GetActiveWindowHandle()')
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication -OwnerWindow $ownerWindow')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $ownerIndex | Should -BeGreaterThan -1
        $authIndex | Should -BeGreaterThan $ownerIndex
        $targetIndex | Should -BeGreaterThan $authIndex
    }

    It 'performs no destination capture before authentication' {
        $invokeType = ($script:content -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $targetIndex = $invokeType.IndexOf('Select-TypeTargetWindow')
        $authIndex | Should -BeGreaterThan -1
        $targetIndex | Should -BeGreaterThan $authIndex
        $beforeAuth = $invokeType.Substring(0, $authIndex)
        $beforeAuth | Should -Not -Match 'Select-TypeTargetWindow'
        $beforeAuth | Should -Not -Match 'Wait-ForTargetWindow'
    }

    It 'starts the post-authentication delay through the target selector' {
        $selector = ($script:content -split 'function Select-TypeTargetWindow \{', 2)[1]
        $selector | Should -Match 'Start-Sleep -Milliseconds \$DelayMs'
        $selector | Should -Match 'Capture only the final foreground window when the countdown has ended'
    }

    It 'decrypts only after authentication and destination focus validation' {
        $invokeType = ($script:content -split 'function Invoke-TypeCredential \{', 2)[1]
        $authIndex = $invokeType.IndexOf('Invoke-WindowsHelloAuthentication')
        $focusIndex = $invokeType.IndexOf('The destination window is no longer in the foreground')
        $decryptIndex = $invokeType.IndexOf('$password = Get-CredentialPassword')
        $authIndex | Should -BeGreaterThan -1
        $focusIndex | Should -BeGreaterThan $authIndex
        $decryptIndex | Should -BeGreaterThan $focusIndex
    }

    It 'does not minimise or force TypeVault back to the foreground during the workflow' {
        $script:content | Should -Not -Match 'MinimiseWindow\('
        $script:content | Should -Not -Match 'RestoreWindow\('
        $script:content | Should -Not -Match 'SetForegroundWindow\(\$ownerWindow\)'
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
