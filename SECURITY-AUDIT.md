## 1.7.0 audit follow-up

The previous PowerShell 7 WinRT implementation used hand-written IInspectable/vtable and completion-handler interop. The observed failure occurred immediately after the verification request was submitted, before a usable completion result was returned. Version 1.7.0 removes that custom ABI/callback implementation.

Windows Hello is now isolated in `tools/WindowsHello.ps1`, executed by the built-in Windows PowerShell 5.1 runtime. The helper uses the classic .NET Windows Runtime projection and the documented `IUserConsentVerifierInterop::RequestVerificationForWindowAsync` desktop API, then waits for the projected `IAsyncOperation<UserConsentVerificationResult>` result.

The main PowerShell 7 process passes only an owner window handle and the fixed verification message. Stored credential data and decrypted passwords are never passed to the helper.

### Interactive credential flow

The required flow is now explicit:

1. Select a stored credential profile.
2. Request Windows Hello immediately.
3. Continue only after `UserConsentVerificationResult.Verified`.
4. Start the default three-second post-authentication countdown.
5. Capture the foreground window after the countdown.
6. Confirm that the foreground window is not the TypeVault owner window.
7. Decrypt the stored credential only after the focus safety check.
8. Send the Unicode keyboard events to the currently active window.
9. Check the foreground window again immediately before an optional Enter key.

No target window is captured before authentication in the normal interactive flow.

### Windows Hello availability

The authentication status screen now calls `UserConsentVerifier.CheckAvailabilityAsync` rather than treating activation-factory loading as proof that an authenticator is configured.

### Project file metadata

The Python launcher removes the Windows `Zone.Identifier` stream only when it is actually present on files inside the extracted project directory. Already-unblocked files are not passed to `Unblock-File`. This is intended to handle downloaded ZIP metadata without repeatedly touching project files.

### Authentication bypass

Windows Hello remains mandatory. The application has no persistent authentication setting, no disabled mode and no menu path that bypasses verification. Credential decryption occurs only after a verified result.

### Testing status

Static source and repository checks can be run with `tools/Invoke-Checks.ps1`. A real Windows Hello test still requires Windows 11 with Windows Hello configured. The Linux build environment used for source preparation cannot exercise the Windows biometric/PIN UI, so no live Windows Hello result is claimed here.

## Residual risks

The clear-text credential necessarily exists briefly in process memory while it is converted to keyboard input events. A fully compromised Windows endpoint remains outside the security boundary.

Synthetic input can be rejected by elevated targets, User Interface Privilege Isolation (UIPI), secure desktop controls or application-specific authentication controls. A successful Windows Hello verification does not make a target application trustworthy or guarantee that it will accept synthetic input.
