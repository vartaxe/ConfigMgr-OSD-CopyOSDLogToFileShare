# Design

<p align="center"><img src="../assets/copylog-flow.svg" alt="Copy OSD Logs to File Share workflow: set hidden variables, validate environment and OSDisk, collect logs, create archive, upload via SMB, verify remote size, and clear variables" width="100%"></p>

This utility uses these principles:

- Keep the operational script focused on one task.
- Keep examples generalized.
- Avoid organization-specific values in public content.
- Use readable Windows PowerShell 5.1 code.
- Log to `_SMSTSLogPath` when available and `%WINDIR%\Temp` otherwise.
- Use native Task Sequence steps to create and clear credential variables.
- Treat generated logs and archives as internal diagnostic data.

The sequence is collection, `Manifest.json`, local ZIP creation, TCP 445 preflight, authenticated SMB upload, remote-size verification, then successful local cleanup.
Size verification detects incomplete copies; it is not a remote content hash.
Failed uploads retain the local archive. Archive names include a timestamp and GUID to avoid overwriting previous attempts.
In WinPE, a valid `OSDisk` identifies the offline Windows and ProgramData roots; it accepts a drive with or without a trailing backslash.
The standard collection profile remains focused; `-IncludeExtendedLogs` adds setup, servicing, update, and rollback locations.
When a source contains the staging directory, collection skips the direct child containing staging and logs a warning to prevent recursive self-collection.
