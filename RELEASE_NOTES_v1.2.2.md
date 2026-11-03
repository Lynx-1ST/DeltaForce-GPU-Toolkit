# DeltaForce GPU Toolkit v1.2.2 — One-click GPU names and Revert

Three Windows CMD launchers are included in the release ZIP:

- **OneClick_GTX_1050_Ti.cmd** — set displayed name to NVIDIA GeForce GTX 1050 Ti.
- **OneClick_RTX_2050.cmd** — set displayed name to NVIDIA GeForce RTX 2050 Laptop GPU.
- **OneClick_Revert.cmd** — restore original Registry descriptions from `gpu_backup.json`.

Double-click a CMD file. The existing PowerShell tool requests Administrator access through Windows UAC when required. If multiple discrete GPUs are detected, the tool lists them with **[1], [2], ...** and asks which to modify; a single discrete GPU is selected automatically. The target driver is not silently guessed when multiple eligible adapters exist.

The existing GPU detection logic, ICC, ACE and the normal menu are unchanged. The one-click path backs up Registry values before an edit and keeps the backup for recovery.

**Important:** Revert needs the original `gpu_backup.json` file in the extracted folder. Do not delete it when upgrading. Changing display-description strings does not change GPU hardware, and games or Task Manager may still report the original device. These features have not been verified on physical Windows GPUs.
