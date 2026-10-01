#!/usr/bin/env python3
"""
TypeVault click-to-open launcher.

This small launcher keeps TypeVault's main implementation in PowerShell while
allowing Windows users with a normal Python .py file association to launch
the application by double-clicking this file.

Requirements:
    Windows
    Python 3.10+
    PowerShell 7.2+
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys

# Prevent execution from creating __pycache__ or .pyc files in the project.
sys.dont_write_bytecode = True


APP_NAME = "TypeVault"
POWERSHELL_SCRIPT = "TypeVault.ps1"


def unblock_project_files(pwsh: str, project_dir: Path) -> None:
    """Remove Zone.Identifier only from project files that still have it."""
    command = [
        pwsh,
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        (
            "$root = $env:TYPEVAULT_PROJECT_DIR; "
            "$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force; "
            "foreach ($file in $files) { "
            "$stream = Get-Item -LiteralPath $file.FullName -Stream Zone.Identifier "
            "-ErrorAction SilentlyContinue; "
            "if ($null -ne $stream) { "
            "Unblock-File -LiteralPath $file.FullName -ErrorAction SilentlyContinue "
            "} "
            "}"
        ),
    ]

    env = os.environ.copy()
    env["TYPEVAULT_PROJECT_DIR"] = str(project_dir)
    subprocess.run(
        command,
        cwd=project_dir,
        env=env,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def find_pwsh() -> str | None:
    """Return a usable PowerShell 7 executable path."""
    path = shutil.which("pwsh.exe") or shutil.which("pwsh")
    if path:
        return path

    candidates = []
    program_files = os.environ.get("ProgramFiles")
    program_files_x86 = os.environ.get("ProgramFiles(x86)")

    if program_files:
        candidates.append(Path(program_files) / "PowerShell" / "7" / "pwsh.exe")
    if program_files_x86:
        candidates.append(
            Path(program_files_x86) / "PowerShell" / "7" / "pwsh.exe"
        )

    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        candidates.append(
            Path(local_app_data) / "Microsoft" / "WindowsApps" / "pwsh.exe"
        )

    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)

    return None


def main() -> int:
    if os.name != "nt":
        print(f"{APP_NAME} can only run on Windows.")
        return 1

    project_dir = Path(__file__).resolve().parent
    script_path = project_dir / POWERSHELL_SCRIPT

    if not script_path.is_file():
        print(f"Error: {POWERSHELL_SCRIPT} was not found next to this launcher.")
        input("Press Enter to exit...")
        return 1

    pwsh = find_pwsh()
    if not pwsh:
        print("Error: PowerShell 7 (pwsh.exe) was not found.")
        print("Install PowerShell 7 and try again.")
        input("Press Enter to exit...")
        return 1

    # Files extracted from a downloaded archive can inherit Windows Zone.Identifier
    # metadata. Remove it only when the stream actually exists. Once removed,
    # subsequent launches do not modify the project files for this reason.
    try:
        unblock_project_files(pwsh, project_dir)
    except OSError as exc:
        print(f"Warning: could not remove the Windows download block: {exc}")

    command = [
        pwsh,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script_path),
        "-Action",
        "Menu",
    ]

    try:
        completed = subprocess.run(command, cwd=project_dir)
        return completed.returncode
    except OSError as exc:
        print(f"Error: could not start PowerShell 7: {exc}")
        input("Press Enter to exit...")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
