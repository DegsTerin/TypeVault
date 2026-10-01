# Changelog

All notable changes to TypeVault are documented in this file.

## 1.7.0 - 2026-10-01

### Added

- Dedicated Windows PowerShell 5.1 bridge for desktop Windows Hello interoperability.
- Separate interactive Windows Hello integration test.
- Authentication-status check using the Windows Runtime availability API.
- Explicit source-tree metadata watcher for diagnosing unexpected file timestamp changes.
- Automatic removal of Windows `Zone.Identifier` download metadata only when present.

### Changed

- Windows Hello is mandatory before every stored credential typing operation.
- Credential decryption occurs only after successful Windows Hello verification and destination focus validation.
- The interactive typing flow is authentication-first, followed by the default three-second delay and final foreground-window capture.
- Keyboard injection remains implemented with Win32 `SendInput` Unicode events.
- The double-click launcher remains the recommended entry point and does not modify persistent execution-policy settings.

### Security

- Removed the previous hand-written WinRT ABI/vtable and completion-handler implementation.
- Removed the persistent authentication-settings model, including any disabled-authentication mode.
- Kept credential storage outside the source tree under `%LOCALAPPDATA%\TypeVault`.

## 1.6.9

- Revised the interactive authentication-first flow.
- Added explicit diagnostics around Windows Hello submission and result handling.

## 1.6.8

- Removed target-window minimisation and restoration from the typing workflow.
- Simplified foreground-window handling after authentication.

## 1.6.7

- Adjusted foreground-window handling around Windows Hello.
- Corrected assumptions about launcher ownership of the active window.

## 1.6.6

- Fixed Windows Hello test initialisation.
- Revised target-window capture after the countdown.

## 1.6.5

- Reworked target capture sequencing around authentication.
- Preserved the three-second typing delay.

## 1.6.4

- Added automatic handling of Windows download-block metadata during double-click launch.
- Improved source-tree runtime-file isolation.

## 1.6.3

- Revised Windows Hello integration diagnostics.
- Added additional static validation around the authentication callback architecture.

## 1.6.2

- Added automatic removal of Windows download-block metadata for project files.

## 1.6.1

- Added source-tree metadata watcher.
- Revised Windows Hello asynchronous handling.

## 1.6.0

- Made Windows Hello mandatory.
- Added Windows 11 build validation.
- Added reserved Windows device-name validation for credential profiles.
- Fixed source-tree `.gitignore` coverage.
- Added security audit follow-up documentation and expanded tests.

## 1.5.3

- Introduced the previous Windows Hello integration and expanded repository documentation.

## 1.5.0

- Added interactive profile management, authentication status and improved keyboard-input diagnostics.

## 1.1.0

- Added three-second default typing delay and interactive credential selection.

## 1.0.4

- Fixed Win32 `INPUT` structure sizing and restored successful Unicode keyboard injection.
- Added required namespace references for Win32 exception handling.
