Describe 'TypeVault Python launcher' {
    BeforeAll {
        $launcherPath = Join-Path $PSScriptRoot '..' 'TypeVault.py'
        $scriptPath = Join-Path $PSScriptRoot '..' 'TypeVault.ps1'
        $script:launcherText = Get-Content -LiteralPath $launcherPath -Raw -Encoding utf8
        $script:scriptText = Get-Content -LiteralPath $scriptPath -Raw -Encoding utf8
    }

    It 'exists next to the PowerShell implementation' {
        Test-Path -LiteralPath $launcherPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $scriptPath -PathType Leaf | Should -BeTrue
    }

    It 'starts PowerShell 7 through a fixed argument list' {
        $script:launcherText | Should -Match 'pwsh\.exe'
        $script:launcherText | Should -Match '"-NoProfile"'
        $script:launcherText | Should -Match '"-ExecutionPolicy"'
        $script:launcherText | Should -Match '"Bypass"'
        $script:launcherText | Should -Match '"-File"'
        $script:launcherText | Should -Match '"-Action"'
        $script:launcherText | Should -Match '"Menu"'
    }

    It 'does not invoke a shell command string' {
        $script:launcherText | Should -Not -Match 'shell=True'
        $script:launcherText | Should -Not -Match 'os\.system\('
        $script:launcherText | Should -Not -Match 'subprocess\.Popen\([^\n]*shell'
    }

    It 'prevents source-tree bytecode writes' {
        $script:launcherText | Should -Match 'sys\.dont_write_bytecode = True'
    }

    It 'automatically removes the Windows download mark only when present' {
        $script:launcherText | Should -Match 'Unblock-File'
        $script:launcherText | Should -Match 'Zone\.Identifier'
        $script:launcherText | Should -Match 'TYPEVAULT_PROJECT_DIR'
        $script:launcherText | Should -Match 'Get-Item -LiteralPath \$file.FullName -Stream Zone.Identifier'
    }

    It 'targets the current release' {
        $script:scriptText | Should -Match "\$script:Version = '1.7.0'"
    }
    It 'includes the Windows Hello bridge helper' {
        $helperPath = Join-Path $PSScriptRoot '..' 'tools' 'WindowsHello.ps1'
        Test-Path -LiteralPath $helperPath -PathType Leaf | Should -BeTrue
        $script:scriptText | Should -Match 'tools\WindowsHello\.ps1'
    }

}
