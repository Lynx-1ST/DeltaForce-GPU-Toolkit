# DeltaForce GPU Toolkit

GPU utility for Windows with **English / Vietnamese** language selection. The console edition retains its ASCII text; the native desktop edition uses Vietnamese with diacritics.

## Installation
Download the ZIP from [GitHub Releases](https://github.com/Lynx-1ST/DeltaForce-GPU-Toolkit/releases/latest), extract all files together, and run `Start.bat`. Select a language before accepting Administrator access.

## GPU names
Menu [2] lists the actual display adapters first, then offers 8 GPU names and [9] to enter a custom name. The tool saves `gpu_backup.json` before editing Registry descriptions. Menu [3] restores values from the backup.

Keep `GpuTool.i18n.ps1`, `gpu_models.json`, `gpu_ui.json`, `Start.bat`, `Start-GpuTool.ps1`, and the `locales` folder together. Preserve `gpu_backup.json` when updating.

The current console source uses the supplied `GpuTool.zip` as its baseline. Its GPU selection, backup/restore and color logic are preserved. The original ACE module is restored: state inspection, EcoQoS/Idle self-test, optional application and a 14-second watchdog while the session remains open.

**Important:** Renaming display text does not change the installed GPU's actual model or supported hardware features. Consult [SAFETY.md](SAFETY.md).

## Native desktop interface

The `desktop` folder contains the C++ Win32 interface, with a tactical dark theme and Unicode Vietnamese. It uses the existing PowerShell functions for system operations; interactive operations open a console. See [desktop/README.md](desktop/README.md) for build and usage instructions. This is an unofficial utility, not an official Delta Force application.

The desktop build needs Visual Studio C++ build tools and the Windows SDK. Users of the packaged build do not need a compiler, Electron or a .NET runtime; Windows PowerShell 5.1 is required.

Verification uses syntax checks and mocked handlers. It does not apply GPU, gamma or ACE changes to the test machine.
