# Logging

The script writes `CopyOSDLogs.log` in native CMTrace format to `_SMSTSLogPath` when it exists, or `%WINDIR%\Temp` otherwise.
The local archive is kept under `Windows\Temp\PendingOSDLogs` on the selected Windows volume; in WinPE, `OSDisk` is used when it identifies the target Windows volume.
Without a valid offline target, WinPE fallback storage may be on a volatile RAM disk. Retrieve retained archives before rebooting.

Script-generated errors are limited to known credential-free messages or an exception type; raw exception messages are not written to `CopyOSDLogs.log`, `smsts.log`, or `Manifest.json`. Explicit supplied credentials are also redacted from script log messages.
Collected source logs and ZIP contents are **not scrubbed** and may contain credentials or sensitive deployment data from other components.
Use hidden Task Sequence password variables, disable parameter logging, clear credentials even after failure, and verify the dedicated log and `smsts.log` in live testing.

Local archives are removed only after successful remote-size verification and retained after upload failure.
Restrict access and apply an environment-appropriate retention policy. Sanitize excerpts before sharing; never upload raw archives to public issues.
