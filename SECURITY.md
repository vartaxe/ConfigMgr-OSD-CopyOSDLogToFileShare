# Security

## Reporting

Use [private GitHub security advisories](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/security/advisories/new) for vulnerabilities. Use GitHub Issues only for non-sensitive bugs and documentation issues. Do not publish unsanitized logs, ZIP archives, command lines, credentials, tokens, certificates, internal server names, or deployment policy data.

Private vulnerability reporting is enabled for this repository.
If the private reporting form is unavailable, contact [Claudio Mendes](mailto:vartaxe@outlook.com) at vartaxe@outlook.com rather than opening a public issue.
Start with a minimal description and arrange a private channel before sharing sensitive evidence.

## Security model

- Use dedicated least-privilege service accounts.
- Supply the upload identity through the custom `OSDLogUserName` and `OSDLogPassword` variables. The script reads only its documented Task Sequence inputs.
- Mark password variables as hidden in Configuration Manager.
- Do not pass passwords as script parameters.
- Disable PowerShell parameter logging for steps that depend on credentials.
- Clear credential variables immediately after the related script step, including its failure path.
- Treat generated logs and archives as internal diagnostic data.
- Script-generated failures use safe categories or exception types rather than raw exception text. Dedicated log messages redact the supplied credentials. Manifest error messages are sanitized, but source paths, computer names, copied logs, and archive contents are not scrubbed.
- Enforce SMB1 and guest restrictions externally. The script never enables them or changes authentication policy.
- Default SMB verification fails closed. Approve and test any [compatibility exceptions](docs/compatibility.md); authentication negotiation is not proven by `Get-SmbConnection`.
- Restrict access to local staging and remote archives, and apply an explicit retention policy. Successful upload removes only the current run's local work; previous retained runs and remote partials are not automatically deleted.
