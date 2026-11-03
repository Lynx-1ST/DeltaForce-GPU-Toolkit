# GPU Tool

Based on the user-edited GpuTool.zip, with the original full ACE module integrated. GPU and ICC functions are preserved from the supplied ZIP.

Download the runtime ZIP from [Releases](https://github.com/Lynx-1ST/DeltaForce-GPU-Toolkit/releases/latest), extract everything, then run Start.bat for Vietnamese. Run Start-GpuTool.ps1 through PowerShell for the English / Vietnamese selector. Some GPU messages retain the supplied Vietnamese text.

Keep the scripts, gpu_models.json and locales together. Windows PowerShell 5.1 is required. Preserve your generated gpu_backup.json when updating.

ACE includes status, EcoQoS/Idle self-test, optional application and a 14-second watchdog. System changes request Administrator access. Read [SAFETY.md](SAFETY.md).

Release ZIPs contain runtime files only. Source tests stay in tests/. Local analysis and the unfinished desktop EXE are excluded.

Verification: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-GpuTool.ps1. Checks parse the source and mock menu dispatch without applying GPU/ICC/ACE changes.
## One-click shortcuts (v1.2.2)

After downloading and extracting the latest release, double-click one of:

| CMD file | Action |
| --- | --- |
| `OneClick_GTX_1050_Ti.cmd` | Display name: GTX 1050 Ti |
| `OneClick_RTX_2050.cmd` | Display name: RTX 2050 Laptop GPU |
| `OneClick_Revert.cmd` | Restore saved GPU Registry descriptions |

The CMD scripts use the existing tool and **request Administrator permission automatically via UAC**. If multiple discrete GPUs are found, choose **[1], [2], ...**; with exactly one discrete GPU, it is chosen automatically. You still need to keep `GpuTool.i18n.ps1`, `gpu_models.json`, `locales/` and the CMD launchers in the same extracted folder.

**Backups:** Keep `gpu_backup.json` in the same directory when updating. Revert will not guess an original name when a backup is missing. Editing GPU descriptions does not upgrade the physical hardware.

## OneClick_Revert.cmd - installed driver INF (v1.2.3)

`OneClick_Revert.cmd` no longer requires `gpu_backup.json`. It requests Administrator through the Windows UAC prompt, finds the selected PCI display device's installed INF, and asks Windows Plug and Play to re-enumerate that device from the installed driver store. If there are multiple GPUs, choose 1/2/etc.; if there is only one, it runs without a GPU-selection question. No extra yes/no confirmation is shown.

**Important:** Save your work first. The display can temporarily go black; re-enumeration may fail or require a restart. Windows may choose a different installed driver due to driver ranking, and success cannot be guaranteed on every configuration. No direct Registry name writes or driver package deletion are performed by the Revert shortcut. The other one-click CMD files are unchanged.
