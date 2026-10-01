#requires -Version 5.1
<##
.SYNOPSIS
    Performs Windows Hello verification for TypeVault.

.DESCRIPTION
    This helper intentionally runs under Windows PowerShell 5.1 because that
    runtime contains the classic Windows Runtime projection required to call
    the desktop UserConsentVerifier interop API without custom WinRT ABI code.

    It returns a numeric UserConsentVerifierAvailability or
    UserConsentVerificationResult value on stdout.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Verify', 'Availability')]
    [string]$Mode,

    [Int64]$OwnerWindow = 0,

    [AllowEmptyString()]
    [string]$Message = 'TypeVault requires Windows Hello verification before using a stored credential.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not ('TypeVault.WindowsHelloBridge' -as [type])) {
        $windowsWinmd = Join-Path $env:WINDIR 'System32WinMetadataWindows.winmd'
        if (-not (Test-Path -LiteralPath $windowsWinmd -PathType Leaf)) {
            throw 'The Windows Runtime metadata file could not be found.'
        }

        $winRtAssembly = $null
        try {
            $winRtAssembly = [System.Runtime.InteropServices.WindowsRuntime.WindowsRuntimeMarshal].Assembly.Location
        }
        catch {
            $winRtAssembly = $null
        }

        $references = @($windowsWinmd)
        if (-not [string]::IsNullOrWhiteSpace($winRtAssembly) -and (Test-Path -LiteralPath $winRtAssembly -PathType Leaf)) {
            $references += $winRtAssembly
        }

        Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Security.Credentials.UI;

namespace TypeVault
{
    [Guid("39E050C3-4E74-441A-8DC0-B81104DF949C")]
    [InterfaceType(ComInterfaceType.InterfaceIsIInspectable)]
    public interface IUserConsentVerifierInterop
    {
        IAsyncOperation<UserConsentVerificationResult> RequestVerificationForWindowAsync(
            IntPtr appWindow,
            [MarshalAs(UnmanagedType.HString)] string message,
            [In] ref Guid riid);
    }

    public static class WindowsHelloBridge
    {
        public static int Verify(IntPtr ownerWindow, string message)
        {
            if (ownerWindow == IntPtr.Zero)
                throw new ArgumentException("The owner window handle is invalid.", nameof(ownerWindow));

            IUserConsentVerifierInterop interop =
                (IUserConsentVerifierInterop)WindowsRuntimeMarshal.GetActivationFactory(typeof(UserConsentVerifier));

            Guid operationIid = typeof(IAsyncOperation<UserConsentVerificationResult>).GUID;
            IAsyncOperation<UserConsentVerificationResult> operation =
                interop.RequestVerificationForWindowAsync(ownerWindow, message, ref operationIid);

            if (operation == null)
                throw new InvalidOperationException("Windows Hello returned an empty asynchronous operation.");

            return (int)WindowsRuntimeSystemExtensions.AsTask(operation).GetAwaiter().GetResult();
        }

        public static int GetAvailability()
        {
            IAsyncOperation<UserConsentVerifierAvailability> operation =
                UserConsentVerifier.CheckAvailabilityAsync();

            if (operation == null)
                throw new InvalidOperationException("Windows Hello returned an empty availability operation.");

            return (int)WindowsRuntimeSystemExtensions.AsTask(operation).GetAwaiter().GetResult();
        }
    }
}
'@
    }

    if ($Mode -eq 'Availability') {
        [Console]::Out.WriteLine([TypeVault.WindowsHelloBridge]::GetAvailability())
        exit 0
    }

    if ($OwnerWindow -eq 0) {
        throw 'A valid owner window handle is required for Windows Hello verification.'
    }

    [Console]::Out.WriteLine([TypeVault.WindowsHelloBridge]::Verify([IntPtr]$OwnerWindow, $Message))
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 1
}
