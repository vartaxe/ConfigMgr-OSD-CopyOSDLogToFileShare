# Compatibility

| Status | Platform |
|---|---|
| Target | Windows PowerShell 5.1 and current supported ConfigMgr releases |
| Target, unverified | Full Windows and current WinPE with PowerShell components |
| Conditional, unverified | Older clients with WMF 5.1 and explicitly approved compatibility settings |
| Unsupported | PowerShell 7 task-sequence runtime, SMB1, NTLMv1, guest or unauthenticated SMB |

No platform has a recorded live pass in this repository. Windows PowerShell 5.1 alone does not guarantee that required SMB cmdlets and parameters exist.

The default requires SMB3, integrity protection, and encryption, and fails closed when connection properties cannot be inspected.
Encryption is accepted as integrity protection. A known SMB1 connection is always rejected.
An unsigned, unencrypted connection is never accepted; waiving encryption does not waive integrity.

Compatibility switches are explicit, disabled by default, and logged:

- `-MinimumSmbDialect SMB2` permits SMB2 or newer.
- `-AllowUnencryptedSmb` permits a connection reported as unencrypted.
- `-AllowUnverifiedSmb` permits missing inspection or unknown connection properties. It does not override a known unacceptable dialect or known lack of integrity.
- `-AllowNtlmV2` permits NTLM compatibility rather than requesting that a server use NTLM. Actual authentication cannot be proven from `Get-SmbConnection`.

Where `New-SmbMapping` is available, the script requests `RequireIntegrity`, requests `RequirePrivacy` unless encryption is explicitly waived, and requests `BlockNTLM` unless NTLM compatibility is explicitly allowed.
Because `BlockNTLM` and `Credential` use different parameter sets, enforcing the default uses username/password strings in-process, never a command-line password or saved credential.
`-AllowNtlmV2` omits `BlockNTLM` rather than disabling stricter existing policy, and uses `Credential` where supported.
Required per-connection controls must be available; there is no automatic downgrade after authentication or mapping failure.
On older clients without `BlockNTLM`, `-AllowNtlmV2` is required and the existing `LmCompatibilityLevel` must be explicitly set to 3, 4, or 5.
The policy is read, never changed.

Where `New-SmbMapping` is absent (as in some WinPE images), `New-PSDrive` is allowed only with both `-AllowUnverifiedSmb` and `-AllowNtlmV2`, plus the same existing policy value of 3 through 5.
Default WinPE operation may therefore refuse upload until an approved compatibility configuration is supplied. The local archive is retained on upload failure.

Administrators must separately disable SMB1 and guest authentication through Windows/server policy. The script never enables these features or edits authentication policy.
