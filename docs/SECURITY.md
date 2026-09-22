# Security Model

NFCCard is an interoperability and diagnostics toolkit, not a credential-bypass toolkit.

## Rules enforced by design

- Discovery begins read-only.
- Mutating operations require explicit UI confirmation.
- User-supplied secret keys are stored in Keychain and excluded from logs/exports.
- Card Genome is derived only from public scan metadata.
- Protocol logs should redact authentication cryptograms, session keys and protected payloads.
- No brute-force key search, default-key spraying, secret extraction or access-control bypass is included.

## Responsible testing

Use secure/authenticated modules only with cards, tags, readers and credentials you are authorized to test.
