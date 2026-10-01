# TypeVault User Guide

## 1. Requirements

- Windows 11 build 22000 or later.
- PowerShell 7.2 or newer.
- Python 3.10+ for the double-click launcher.
- Windows Hello configured for the current Windows user.

## 2. Start TypeVault

For normal use, double-click **`TypeVault.py`**. This starts the PowerShell implementation automatically. You do not need to open CMD or PowerShell first.

The Python launcher uses a process-scoped `ExecutionPolicy Bypass` for its child PowerShell process only. It does not change persistent execution policy settings.

For development, the PowerShell implementation can also be started directly:

```powershell
.\TypeVault.ps1
```

## 3. Main menu navigation

```text
[1] Type credential
[2] Add credential
[3] List credentials
[4] Change password
[5] Remove credential
[6] Authentication status  [Windows Hello]
[7] Test TypeVault
[8] Test Windows Hello
[0] Exit
```

Interactive submenus use `[0] Back`. Choosing `[0] Exit` from the main menu closes TypeVault.

## 4. Add a credential

Choose `[2] Add credential`. Enter a profile name, password and confirmation. The password is stored using Windows DPAPI under `%LOCALAPPDATA%\TypeVault\Credentials`.

A profile name must be a valid Windows filename component. Windows reserved device names such as `CON`, `PRN`, `AUX`, `NUL`, `COM1` and `LPT1` are rejected. Names ending in a space or full stop are also rejected.

Press Enter at the profile-name prompt to cancel. Press Enter at the password prompt without entering a password to go back.

## 5. Type a credential

Choose `[1] Type credential`. Select a profile or `[0] Back`.

TypeVault then requests Windows Hello verification. Windows chooses the configured verification method, which may be fingerprint, Windows Hello PIN or another supported method.

If Windows Hello succeeds, TypeVault continues to the typing flow. If authentication fails, is cancelled, unavailable or not configured, the credential is not typed.

Only after successful authentication does the default three-second countdown begin. During the countdown, switch to the destination application and leave the required field active. When the countdown ends, TypeVault captures the final foreground window and types the credential there.

The credential is decrypted only after the target window passes the final foreground-window check.

TypeVault checks the foreground window again immediately before sending Enter.

## 6. Targeting a specific window

Use window filters for deterministic automation:

```powershell
.\TypeVault.ps1 -Action Type -Profile Work -WindowTitle '*Login*'
```

or:

```powershell
.\TypeVault.ps1 -Action Type -Profile Work -WindowProcess '<process-name>'
```

If multiple windows match, TypeVault refuses to guess and asks you to use a more specific filter.

## 7. Delay and Enter behaviour

The default delay is three seconds:

```powershell
-DelayMilliseconds 3000
```

Use `-NoEnter` to type only the credential:

```powershell
.\TypeVault.ps1 -Action Type -Profile Work -NoEnter
```

A zero delay uses the current foreground window immediately in unfiltered interactive mode.

## 8. Authentication status

Choose `[6] Authentication status`. Authentication is always required and cannot be disabled from TypeVault.

The screen reports the actual Windows Hello authentication-device availability returned by the Windows Runtime API. The self-test does not open a biometric prompt.

## 9. Change a password

Choose `[4] Change password`, select the profile or `[0] Back`, then enter the new password twice. The profile creation timestamp is preserved and the update timestamp changes.

## 10. Remove a credential

Choose `[5] Remove credential`, select the profile or `[0] Back`, and confirm the destructive action. The profile file is then removed.

## 11. List credentials

Choose `[3] List credentials`. Only profile metadata is displayed. Passwords are never shown.

## 12. Self-test

Choose `[7] Test TypeVault` or run:

```powershell
.\TypeVault.ps1 -Action Test
```

The self-test checks the SecureString conversion path, the Win32 `INPUT` structure size and Windows Hello API availability. It does not type text into another application and does not trigger a real Windows Hello verification.

## 13. Test Windows Hello

Choose `[8] Test Windows Hello` to run a real interactive Windows Hello verification without accessing or typing any stored credential. A successful test confirms that the TypeVault Windows Hello integration can receive the verification result and return control to the main application.

The self-test in `[7] Test TypeVault` does not open the Windows Hello prompt.

## 14. Files and timestamps

TypeVault does not write its source files during normal operation. Runtime data is kept under `%LOCALAPPDATA%\TypeVault`.

The Python launcher disables bytecode generation. A normal execution therefore does not create `__pycache__` or `.pyc` files in the project directory.

For debugging continuously changing Explorer modification times, extract the release to a normal local folder such as Downloads outside a synchronised workspace and compare the behaviour.

## 15. Troubleshooting

### Windows Hello dialog appears but TypeVault does not continue

Run `[8] Test Windows Hello` first. It should open the Windows Hello prompt, accept the configured verifier, report a successful test and return to the menu. The helper runs under the built-in Windows PowerShell 5.1 runtime because the desktop Windows Hello API uses WinRT interop. The current implementation delegates the desktop Windows Hello operation to a small Windows PowerShell 5.1 WinRT bridge, which waits for the projected asynchronous operation and returns only its numeric verification result.

If Windows Hello is unavailable, TypeVault refuses credential typing by design.

### `SendInput` reports zero events

Run the self-test. If the `INPUT` structure passes but an application still rejects input, the target may be protected by UIPI, running with different elevation, using a secure desktop, or explicitly rejecting synthetic input.

### Profile cannot be decrypted

DPAPI-protected credentials are tied to the Windows user and machine context that created them. Recreate the profile on the intended Windows account if the current context cannot decrypt it.

## 16. Security notes

TypeVault temporarily holds the clear-text credential in process memory while converting it to keyboard events. The value is not intentionally written to project files, logs or the clipboard.

Windows Hello verification authorises use of the credential for the current operation. It does not protect against malware, keyloggers, screen capture, process-memory inspection or a fully compromised Windows account.
