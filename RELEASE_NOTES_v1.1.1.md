# GPU Toolkit v1.1.1 — GPU detection hotfix

- Fixed the **"No active PCI GPU with a unique Enum path"** error on systems where the previous PnP-to-Registry mapping could not find a match.
- Finds display-driver keys by enumerating Windows Registry `Enum\PCI` and cross-checking active adapters through PnP, CIM, or `Win32_VideoController`.
- Provides useful diagnostic counts when no unique GPU path can be selected.
- Does not modify Registry if the path is unavailable or ambiguous.
- Retains the English/Vietnamese selector, eight GPU presets, custom name, backup/revert, ICC and all other existing functions without changes.

**Testing:** Source syntax and static checks will run on Windows in GitHub Actions. No physical-GPU compatibility result is claimed. A display-name change does not modify physical GPU capabilities.
