# Safety and limitations

This tool requests Administrator permission and can change GPU Registry display strings, restart a display device, and adjust ICC/gamma settings. Review all changes before applying them.

- A Registry description change does not upgrade or replace the physical GPU.
- Keep `gpu_backup.json` before installing updates. Revert can be limited if a driver or hardware identifier changes.
- Display restarts can produce a temporary black screen or fail.
- ACE operations change SGuard process EcoQoS and scheduling priority. The original self-test resets priority to Normal and disables EcoQoS before optionally applying Idle/EcoQoS; it does not capture arbitrary prior scheduling settings. The watchdog runs only while its console session is open.
- GPU/ICC behavior is retained from the user-supplied edited ZIP. ACE behavior is retained from the original module. The desktop interface does not make these operations risk-free.
- Verification uses parsing, mocked dispatch and UI checks. No real GPU/ICC/ACE mutation testing is claimed for this release.
