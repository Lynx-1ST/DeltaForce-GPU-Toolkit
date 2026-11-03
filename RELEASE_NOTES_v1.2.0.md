# v1.2.0

- Use the supplied edited ZIP as the GPU/color baseline; preserve its non-ACE functions.
- Restore the original full ACE module, including EcoQoS/Idle self-test, optional application and the 14-second watchdog.
- Add the native C++ desktop interface with English / Vietnamese, including Vietnamese diacritics. Interactive system operations retain their PowerShell console workflow.
- Keep the runtime packages minimal: no compiler, test files, local logs or user backups.

Download the desktop ZIP to run DeltaOps.exe, or the console ZIP to run Start.bat. Extract the complete archive before running. Keep any existing gpu_backup.json when updating.

Verification covers syntax, mocked dispatch and GUI rendering/interaction. It does not apply GPU, gamma or ACE changes to the machine.
