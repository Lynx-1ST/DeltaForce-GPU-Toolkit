# Delta Ops - native desktop

Native C++/Win32 desktop interface for the English/Vietnamese GPU utility.

Run `DeltaOps.exe` from the complete application folder. Keep the `backend` folder alongside the executable. The interface opens without Administrator privileges; system-changing actions request elevation individually.

The UI is inspired by tactical game interfaces. This is an unofficial utility and is not affiliated with Delta Force.

The executable uses Windows native controls and drawing, without Electron, a browser engine or a bundled .NET runtime. System operations currently use the inspected PowerShell backend. Operation results appear in a console; the ACE self-test remains interactive there.

Changing GPU names modifies Registry metadata and can restart the display. The supplied GPU logic creates `backend/gpu_backup.json`; preserve it when updating. Restore uses this backup, with an explicitly confirmed INF fallback if no backup exists. ACE EcoQoS changes process priority and can affect gameplay. ICC restore does not restore a previous custom gamma calibration.

Use **English / Vietnamese** to switch the interface. Vietnamese uses Unicode with diacritics. **View GPU** and **View ACE status** are read-only actions. Other actions request Administrator access. Read the result in the operation console, then press Enter to close it; a closed console does not by itself mean all requested system changes succeeded.

## Build

Use `build.ps1` on Windows with Visual Studio C++ build tools and the Windows SDK installed, or provide the path to an official Zig compiler:

```powershell
.\build.ps1 -ZigPath C:\Tools\zig\zig.exe
```

The tested build uses Zig 0.17.0 and Windows PowerShell 5.1. The build copies runtime files into `bin/backend` without removing existing backups. The app does not require the compiler on the user's machine. No game assets or proprietary logos are bundled.

The UI is C++/Win32; system actions still use PowerShell. This package is not a single self-contained executable. Keep the accompanying backend files together.
