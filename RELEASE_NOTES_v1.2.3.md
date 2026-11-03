# v1.2.3 - One-click Restore using installed driver INF

**OneClick_Revert.cmd** no longer needs `gpu_backup.json`.

- Double-click to open; Windows automatically asks for Administrator approval through UAC.
- If only one PCI display adapter is present, it is selected automatically. If there are multiple adapters, select **1, 2, ...**.
- The tool identifies the currently installed INF using Windows device properties or `Win32_PnPSignedDriver`.
- After validating the INF, it asks Windows Plug and Play to remove **only the selected device instance** and scan again so Windows can bind a driver from its Driver Store.
- No extra `yes/no` confirmation, no manual GPU-name Registry writes, and no driver-package deletion.
- The GTX 1050 Ti and RTX 2050 one-click shortcuts, normal GPU detection, ACE, and ICC are unchanged.

**Caution:** The display may temporarily go black while the adapter is re-enumerated. An installed INF is required. Windows may choose a different ranked driver and some systems may need a reboot; this is not guaranteed to restore a vendor name on every GPU. Hardware testing has not been performed.
