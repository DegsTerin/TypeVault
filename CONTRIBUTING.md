# Contributing to TypeVault

Thank you for contributing to TypeVault.

## Before making changes

Read `AGENTS.md` and keep the project PowerShell 7.2+ and Windows compatible.

## Development rules

- Use British English (en-GB) throughout the repository.
- Do not add passwords, tokens or other secrets to source files, tests or documentation.
- Do not use `SendKeys` for new functionality.
- Do not add `ExecutionPolicy Bypass` to launchers or examples.
- Keep the runtime dependency-free unless a dependency provides a clear and documented benefit.
- Update tests when behaviour changes.
- Update `CHANGELOG.md` for user-visible changes.

## Validation

Run:

```powershell
Invoke-Pester -Path .\Tests
.\TypeVault.ps1 -Action Test
```

For changes affecting Win32 interop or keyboard input, also perform a manual test on a supported Windows version.
