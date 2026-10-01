# TypeVault project instructions

## Language

Use British English (en-GB) for all comments, user-facing messages, documentation, tests, workflows and repository text.

## Security

Never add plain-text passwords, realistic example passwords, password logging or clipboard-based secret handling.
Never commit files generated under `%LOCALAPPDATA%\TypeVault\Credentials`.
Keep secret material in `SecureString` or DPAPI-protected storage for as long as practical.
Windows Hello is mandatory before every credential typing operation. Do not add a persistent setting or menu option that disables this requirement.

## Launching

The recommended user entry point is `TypeVault.py`. It must launch the PowerShell implementation by double-click without requiring a manually opened terminal. The launcher may use a process-scoped `ExecutionPolicy Bypass`; it must not modify persistent execution policy settings. `TypeVault.cmd` remains a compatibility entry point.

The launcher must set `sys.dont_write_bytecode = True` and must not create files inside the source tree during normal execution.

## Implementation

Target PowerShell 7.2 or newer on Windows.
Prefer built-in Windows capabilities and dependency-free operation.
Use Win32 `SendInput` for keyboard injection. Do not introduce `SendKeys` for new functionality.
Keep Windows Hello isolated in `tools/WindowsHello.ps1`. The helper uses the Windows PowerShell 5.1 Windows Runtime projection rather than hand-written WinRT ABI/vtable code.

## Navigation

The main menu uses `[0] Exit`. Every interactive submenu must provide `[0] Back` where returning to the previous menu is meaningful. Cancelled profile selection must never fall through into an operation.

## Testing

Run the Pester tests from PowerShell 7:

```powershell
Invoke-Pester -Path .\Tests
```

Run the verification suite:

```powershell
.\tools\Invoke-Checks.ps1
```

Run the built-in self-test:

```powershell
.\TypeVault.ps1 -Action Test
```

Use `[8] Test Windows Hello` or `-Action TestHello` for a real interactive Windows Hello integration test. Do not claim that static tests replace this live Windows test. Do not claim runtime validation on platforms where PowerShell 7, Windows APIs and Windows Hello are unavailable.
```
