---
title: Compatibility
---

# Compatibility

[Documentation home](../index.md) | [Development](development.md) | [Deployment](deployment.md) | [Compatibility](compatibility.md) | [Validation](validation.md)

## Runtime targets

| Status | Platform |
|---|---|
| Target | Windows PowerShell 5.1 and current supported ConfigMgr releases |
| Target, unverified | Full Windows and current WinPE with PowerShell components |
| Conditional, unverified | Older clients with WMF 5.1 and explicitly approved compatibility settings |
| Unsupported | PowerShell 7 task-sequence runtime, SMB1, NTLMv1, guest or unauthenticated SMB |

These are targets, not recorded live test passes. Windows PowerShell 5.1 alone does not guarantee that required SMB cmdlets, parameter sets, or connection properties exist. Validate the exact Windows/WinPE image and server you deploy.

## Default connection requirements

The default requires SMB3, integrity protection, and encryption, and fails closed when connection properties cannot be inspected.
Encryption is accepted as integrity protection. A connection **observed** as SMB1, or as neither signed nor encrypted, is rejected even when compatibility switches are enabled.
The script also requires per-connection NTLM blocking by default; an older cmdlet without `BlockNTLM` cannot enforce that default.

## Compatibility controls

Every switch is explicit, disabled by default, and logged:

- `-MinimumSmbDialect SMB2` permits SMB2 or newer.
- `-AllowUnencryptedSmb` permits a connection reported as unencrypted.
- `-AllowUnverifiedSmb` permits missing inspection, unknown connection properties, or unavailable per-connection controls. It never overrides an observed unacceptable dialect or known lack of integrity. An observed unencrypted connection additionally needs `-AllowUnencryptedSmb`. Unknown properties are not evidence of a secure connection.
- `-AllowNtlmV2` permits NTLM compatibility rather than requesting that a server use NTLM. Actual authentication cannot be proven from `Get-SmbConnection`.

### Clients with SMB mapping cmdlets

Where `New-SmbMapping` is available, the script requests `RequireIntegrity`, requests `RequirePrivacy` unless encryption is explicitly waived, and requests `BlockNTLM` unless NTLM compatibility is explicitly allowed.
Because `BlockNTLM` and `Credential` use different inbox parameter sets, enforcing the default uses username/password strings in-process, never a command-line password or saved credential.
`-AllowNtlmV2` omits `BlockNTLM` rather than disabling stricter existing policy, and uses `Credential` where supported.
Required per-connection controls must be available; there is no automatic downgrade after authentication or mapping failure.
On older clients without `BlockNTLM`, `-AllowNtlmV2` is required and the existing `LmCompatibilityLevel` must be explicitly set to 3, 4, or 5.
The policy is read, never changed. A missing or unreadable value is not assumed to permit NTLMv2.

### Images without SMB mapping cmdlets

Where `New-SmbMapping` is absent (as in some WinPE images), `New-PSDrive` is allowed only with both `-AllowUnverifiedSmb` and `-AllowNtlmV2`, plus the same existing policy value of 3 through 5.
Default WinPE operation may therefore refuse upload until an approved compatibility configuration is supplied. The local archive is retained on upload failure. No fallback is attempted after an available mapping cmdlet fails.

## Identity and environment boundaries

`Get-SmbConnection` reports connections per share, user logon, and credential. The script requires one result matching the configured server, share, and supplied credential name; alternate identity spellings, aliases, or multiple sessions can prevent an unambiguous match. It does not infer Kerberos/NTLM negotiation from that output.

An existing mapping for the requested share root is refused rather than reused or removed. Other activity under Local System can still cause server-session credential conflicts. Do not blindly disconnect unrelated mappings to make the script work.

Use an appropriate DNS server name and identity for your authentication policy. Windows/server policy must separately disable SMB1 and guest access, especially when inspection is explicitly waived. The script never enables these features, changes policy, or loosens the defaults in response to a failure.

## Microsoft references

- [New-SmbMapping controls and parameter sets](https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbmapping?view=windowsserver2025-ps)
- [Get-SmbConnection identity and connection properties](https://learn.microsoft.com/en-us/powershell/module/smbshare/get-smbconnection?view=windowsserver2025-ps)
- [SMB encryption and integrity protection](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-security)
- [New-PSDrive credentialed UNC drives](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-psdrive?view=powershell-5.1)
- [LAN Manager authentication policy values](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/network-security-lan-manager-authentication-level)
