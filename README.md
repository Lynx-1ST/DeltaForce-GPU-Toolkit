# GPU Tool - English / Vietnamese

A Windows PowerShell utility with an English / Vietnamese language selector. Vietnamese messages use ASCII characters without diacritics.

The supplied utility was inspected and localized. Activation-code checks, machine-bound activation fingerprinting, expiry checks and expiry-triggered automatic reversion have been removed. This does not make the remaining system-changing features risk-free. Read [SAFETY.md](SAFETY.md) before use.

## Download and run

1. Download this repository using **Code > Download ZIP**, or clone it, then extract the whole folder.
2. Double-click `Start.bat`.
3. Choose **1 - English** or **2 - Vietnamese**. Choose **0** to exit before any Administrator prompt.
4. The utility requests Administrator access after language selection.

Keep `GpuTool.i18n.ps1`, `Start-GpuTool.ps1` and the `locales` folder together. No package installation is required. The utility targets Windows 10/11 with Windows PowerShell 5.1.

To select a language directly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-GpuTool.ps1 -Language en
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-GpuTool.ps1 -Language vi
```

`ExecutionPolicy Bypass` applies to the launched PowerShell process; the launcher does not persistently change the machine's execution policy.

## Features

| Menu | Action |
| --- | --- |
| 1 | Show current display adapters and GPU identifiers |
| 2 | Change the displayed GPU name to NVIDIA GeForce GTX 1050 Ti |
| 3 | Attempt to restore the GPU name using installed driver INF data |
| 4 | Apply one of 12 gamma/ICC presets, with configurable ordering |
| 5 | Restore a linear gamma ramp and attempt to restore the saved ICC profile |
| 6 | Test ACE/SGuard power-saving settings; optionally keep EcoQoS/Idle and a watchdog enabled |
| 0 | Exit |

Changing the displayed GPU name does not change the physical GPU or its capabilities. Option 6 modifies anti-cheat process scheduling; it is not a general performance boost. These operations retain the underlying utility's behavior and limitations.

## Tieng Viet (khong dau)

- Tai va giai nen toan bo repo, sau do mo `Start.bat`.
- Chon **1** de dung tieng Anh, **2** de dung tieng Viet khong dau; **0** de thoat truoc khi xin quyen quan tri.
- Ban nay khong can ma kich hoat, khong tao fingerprint cap phep va khong tu hoan tac khi het han.
- Cac muc [3] va [5] van cho phep khoi phuc thu cong. Viec thoat chuong trinh khong tu hoan tac cac thay doi da ap dung.
- Tool van co the sua Registry GPU, khoi dong lai thiet bi hien thi, doi mau man hinh va ha uu tien tien trinh ACE. Xem [SAFETY.md](SAFETY.md) truoc khi su dung.

## Verification and development

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-GpuTool.ps1
```

The tests parse the source and use mocked input and menu handlers. They do not change GPU registry values, ACE settings or ICC/gamma. Both languages use the same PowerShell implementation; UI strings are maintained in `locales/en.json` and `locales/vi.json`.

Generated ICC profiles, saved filter ordering and local logs are ignored by Git. The publication excludes the original obfuscated utility and local analysis artifacts.

## License status

No upstream license file was supplied with the source utility. This repository does not add a repository-wide license or grant additional rights to upstream code.
