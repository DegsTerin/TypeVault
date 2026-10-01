# Security Policy

## Scope

TypeVault is a local Windows credential storage and keyboard-input utility. It protects stored credential material with Windows DPAPI and requires Windows Hello verification before every credential is typed.

## Security assumptions

TypeVault assumes the Windows user account and endpoint are not fully compromised. It does not defend against malware that can inspect the TypeVault process, memory, keyboard input, desktop, or the current user's DPAPI context.

## Protected data

Credential material is stored as DPAPI-protected `SecureString` data below `%LOCALAPPDATA%\TypeVault\Credentials`. TypeVault does not intentionally store clear-text passwords in the project directory, log files or clipboard.

## Authentication

Windows Hello is mandatory for credential typing. There is no TypeVault menu option that disables this requirement and TypeVault does not create or update a persistent authentication settings file. Windows decides whether the user verifies with fingerprint, Windows Hello PIN or another configured verifier.

The Windows Hello consent API returns only an authentication result to TypeVault. TypeVault does not receive or store fingerprint templates or the Windows Hello PIN.

## Input safety

TypeVault uses Win32 `SendInput` with Unicode keyboard events. It avoids legacy `SendKeys` parsing. The target window is checked during selection, immediately before credential input, and immediately before an optional Enter key.

## Known limitations

- The clear-text credential necessarily exists temporarily in managed process memory during conversion to keyboard input.
- Synthetic input can be rejected by UIPI, elevated applications, secure desktop controls or application-specific protections.
- Windows Hello authentication does not prove that the target application is safe or that synthetic input will be accepted.
- DPAPI does not defend against a fully compromised Windows user account or endpoint.
- The project does not provide independent third-party security certification.

## Project write isolation

Normal TypeVault execution writes runtime data only below `%LOCALAPPDATA%\TypeVault`. The source directory is not used as a runtime store. The Python launcher sets `sys.dont_write_bytecode = True` to prevent normal Python bytecode cache files.

## Vulnerability reporting

Do not disclose an exploitable vulnerability publicly before a correction is available. Include the TypeVault version, Windows version, PowerShell version, reproduction steps, observed impact and relevant non-secret input. Never include real passwords or DPAPI-protected credential files in a report.
