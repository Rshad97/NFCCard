# Supported Technologies

NFCCard distinguishes three concepts:

1. **RF/card family** — what technology the physical card uses.
2. **iPhone transport** — what Core NFC exposes for that family.
3. **authorized protocol access** — what the card itself permits without or with legitimate authentication material.

| Technology | Detect / identify | Public metadata | NDEF | Native protocol | Protected operations |
|---|---|---|---|---|---|
| MIFARE Ultralight / NTAG | Yes, where Core NFC exposes it | Yes | Yes where supported | MIFARE native | Only where protocol permits |
| MIFARE DESFire EV1/EV2/EV3 | Yes | Yes | Yes where configured | Native + ISO7816 APDU | Requires authorized keys/access conditions |
| MIFARE Plus | Partial / API-dependent | Partial | Tag-dependent | MIFARE transport where exposed | Credential-dependent |
| MIFARE Classic | Identification only where visible | Limited | Not a Crypto1 implementation | Crypto1 unavailable through Core NFC | Not supported |
| ISO 7816 smart cards | Requires explicit AIDs | Yes | Application-dependent | APDU | Application/credential-dependent |
| ISO 15693 / NFC-V | Yes | Yes | Type 5 where supported | Block/custom commands | Tag/security-dependent |
| FeliCa | Requires explicit system codes | Yes | Type 3 where supported | FeliCa commands | Service/security-dependent |
| NFC Forum NDEF tags | Yes | Yes | Read/write according to status | Type-specific | Not applicable unless underlying tag adds security |

## iOS discovery constraints

ISO 7816 AIDs and FeliCa system codes must be declared by the app. Apple does not provide a universal wildcard for every application/system code. NFCCard will make these configuration boundaries visible to users.

## Crypto model

NFCCard's secure-session architecture is intended to support standard algorithms needed by legitimate card protocols, including AES-128, DES, 2K3DES and 3K3DES. The existence of a crypto implementation never implies possession of the card's secret keys.

No brute force, default-key spraying, secret extraction, or access-control bypass is part of the project.
