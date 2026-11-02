# Static safety review

Review date: 2026-11-03. Scope: the supplied PowerShell utility, its decoded strings, and this localized modification. The bilingual implementation has been checked with Windows PowerShell 5.1 and mocked menu tests. The system-changing features have not been run as part of verification.

## Findings

No network transmission, payload download, remote-code execution, credential harvesting, service installation, scheduled task or startup registration was found in the reviewed script. This is a bounded static-code observation, not a malware-free certification. The supplied script was unsigned, and no antivirus scan result is claimed.

| Risk | Behavior retained from the supplied utility |
| --- | --- |
| Elevated access | The runtime requests Administrator access. The launcher uses a process-scoped `ExecutionPolicy Bypass`. |
| Display interruption | GPU name changes write the display-class/Enum registry values and call `pnputil /restart-device`. The display may temporarily go black. |
| Incomplete recovery | There is no actual GPU registry backup implementation. The restore action reconstructs names from installed driver INF data or adapter strings, which can fail or restore only part of the state. Registry writes are not transactional. |
| Anti-cheat scheduling | The ACE test matches `SGuard*`, enables EcoQoS and sets priority to Idle. The optional watchdog checks every 14 seconds. This can reduce resources available to anti-cheat processes and affect a game. |
| Colour calibration | ICC/gamma actions modify display colour behavior. Restore uses a linear gamma ramp rather than a saved copy of the previous gamma calibration. The ICC-profile restoration result is not fully reflected in the original utility's success messages. |
| Legacy-file cleanup | Runtime startup removes `gputool.log` and `icc_original.txt` if these legacy files exist beside the script. |

The GPU name change does not alter hardware or PCI device identity. The supplied utility's statements about zero FPS loss have not been measured here.

## Removed functionality

- Activation-code entry and verification, machine binding, used/voided code lists and activation menus.
- Machine-fingerprint generation from motherboard, CPU, BIOS and disk serial numbers.
- License expiry and clock-rollback checks, including watchdog license checks.
- Automatic system reversion triggered by activation/expiry state.
- Author/contact advertising in the runtime interface.

The localized runtime does not read or write `license.dat`, `used.dat`, `Lic`, `Used` or `Voided`. Existing activation records on a machine are left alone. `HKCU:\Software\DeltaTool` is still used for `IccOrig`, the saved original ICC-profile path. GPU PnP/PCI IDs are still read when required to identify adapters. Optional log redaction hashes remain; logging defaults to disabled.

Manual GPU and ICC/gamma restoration remains available. Closing the application does not automatically undo changes already applied.

## Files written during ordinary use

- `ICCFilter/*.icc`: generated colour profiles beside the script.
- `filterorder.json`: the user's preset order beside the script.
- `HKCU:\Software\DeltaTool\IccOrig`: the saved ICC-profile path.
- `%LOCALAPPDATA%\DeltaTool\gputool.log`: only if logging is explicitly enabled in the source.
- Display adapter registry values and process/display state when the corresponding menu action is selected.

## Verification boundaries

The REA skill's investigation workflow was followed for the initial inspection. REA MCP was unavailable and its CLI diagnostic reported unsupported local Node prerequisites, so target analysis used direct source decoding and PowerShell AST inspection rather than a REA decompilation engine. No REA Evidence ID or runtime malware-analysis result is claimed.

Independent static review and mocked tests cover language selection, locale integrity, parameter forwarding on elevation, menu dispatch and removal of activation-related code. They do not establish compatibility with every driver, display or protected ACE process.
