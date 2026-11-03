# DeltaForce GPU Toolkit

GPU utility for Windows PowerShell 5.1. Choose **English** or **Vietnamese (no diacritics)** when starting the tool.

## Installation
Download the ZIP from [GitHub Releases](https://github.com/Lynx-1ST/DeltaForce-GPU-Toolkit/releases/latest), extract all files together, and run `Start.bat`. Select a language before accepting Administrator access.

## GPU names
Menu [2] lists the actual display adapters first, then offers 8 GPU names and [9] to enter a custom name. The tool saves `gpu_backup.json` before editing Registry descriptions. Menu [3] restores values from the backup.

Keep `GpuTool.i18n.ps1`, `gpu_models.json`, `gpu_ui.json`, `Start.bat`, `Start-GpuTool.ps1`, and the `locales` folder together. Preserve `gpu_backup.json` when updating.

Existing non-GPU functions are unchanged.

**Important:** Renaming display text does not change the installed GPU's actual model or supported hardware features. Consult [SAFETY.md](SAFETY.md).

## GPU detection fix (v1.1.1)

If you previously saw `No active PCI GPU with a unique Enum path`, use the latest release. The tool now reads the PCI device's driver key from Registry and uses PnP/CIM discovery as fallback. If Windows still does not expose a unique matching adapter, the tool prints diagnostic counts and stops before changing Registry. Copy those counts when reporting an issue. A successful name write does not guarantee the same name appears in games or Task Manager.
