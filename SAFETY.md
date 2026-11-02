# Safety and limitations (v1.1.0)

This tool requests Administrator permission and can change GPU Registry display strings, restart a display device, and adjust ICC/gamma settings. Review all changes before applying them.

- A Registry description change does not upgrade or replace the physical GPU.
- Keep `gpu_backup.json` before installing updates. Revert can be limited if a driver or hardware identifier changes.
- Display restarts can produce a temporary black screen or fail.
- Other tool features remain as in the previous repository version; they have not been independently validated by this release.
- No real Windows hardware testing is claimed for v1.1.0.
