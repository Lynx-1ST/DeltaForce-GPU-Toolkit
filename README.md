# GPU Tool

Based on the user-edited GpuTool.zip, with the original full ACE module integrated. GPU and ICC functions are preserved from the supplied ZIP.

Download the runtime ZIP from [Releases](https://github.com/Lynx-1ST/DeltaForce-GPU-Toolkit/releases/latest), extract everything, then run Start.bat for Vietnamese. Run Start-GpuTool.ps1 through PowerShell for the English / Vietnamese selector. Some GPU messages retain the supplied Vietnamese text.

Keep the scripts, gpu_models.json and locales together. Windows PowerShell 5.1 is required. Preserve your generated gpu_backup.json when updating.

ACE includes status, EcoQoS/Idle self-test, optional application and a 14-second watchdog. System changes request Administrator access. Read [SAFETY.md](SAFETY.md).

Release ZIPs contain runtime files only. Source tests stay in tests/. Local analysis and the unfinished desktop EXE are excluded.

Verification: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-GpuTool.ps1. Checks parse the source and mock menu dispatch without applying GPU/ICC/ACE changes.