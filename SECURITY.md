# Security

## Reporting

Use [private GitHub security advisories](https://github.com/vartaxe/ConfigMgr-OSD-CopyOSDLogToFileShare/security/advisories/new) for vulnerabilities. Use GitHub Issues only for non-sensitive bugs and documentation issues. Do not publish unsanitized logs, ZIP archives, command lines, credentials, tokens, certificates, internal server names, or deployment policy data.

Private vulnerability reporting is currently disabled; enabling it requires repository-owner action and remains pending.
If the private reporting form is unavailable, contact [Claudio Mendes](mailto:vartaxe@outlook.com) at vartaxe@outlook.com rather than opening a public issue.
Start with a minimal description and arrange a private channel before sharing sensitive evidence.

## Security model

- Use dedicated least-privilege service accounts.
- Mark password variables as hidden in Configuration Manager.
- Do not pass passwords as script parameters.
- Disable PowerShell parameter logging for steps that depend on credentials.
- Clear credential variables immediately after the related script step, including its failure path.
- Treat generated logs and archives as internal diagnostic data.
- The script redacts explicit supplied credentials in its own log; collected third-party logs and archives are not scrubbed.
- Enforce SMB1 and guest restrictions externally. The script never enables them or changes authentication policy.
- Default SMB verification fails closed. Approve and test any [compatibility exceptions](docs/compatibility.md); authentication negotiation is not proven by `Get-SmbConnection`.

## Not used by design

- Network Access Account retrieval
- `_SMSTSReserved*` credentials
- `net use`
- `cmdkey`
- LDAP 389 fallback
- Explicit NTLM LDAP mode
