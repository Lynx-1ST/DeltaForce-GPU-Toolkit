# v1.2.4 — One-click GPU selection fix

Fixed an empty **CHON GPU CAN DOI TEN** screen in the GTX 1050 Ti and RTX 2050 quick-launch CMD commands.

**Cause:** Windows PowerShell 5.1 can unwrap a single-item array from an if/else expression into a scalar PSCustomObject, so `$options.Count` was not usable. The menu appeared but contained no numbered GPUs.

**Fix:** Keep the selected GPU collection explicitly typed as an object array. Expected behavior:
- Zero GPUs: show a clear error instead of a blank choice list.
- One GPU: select automatically, without a GPU-number prompt.
- Multiple GPUs: show **[1], [2], ...** with the GPU names.

The existing GPU detection, Registry backup, INF Revert, ICC and ACE functions were not changed.

A Windows PowerShell 5.1 mocked regression test covers zero, one and two GPUs. The tests do not write the Registry or restart a GPU.
