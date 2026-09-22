# Supported Technologies

NFCCard distinguishes three things:

1. **RF/card family** — what technology the physical card uses.
2. **iPhone transport** — what Core NFC exposes for that family.
3. **Authorized protocol access** — what the card permits publicly or after legitimate authentication.

| Technology | Detect / identify | Public metadata | NDEF | Native protocol | Protected operations |
|---|---|---|---|---|---|
| MIFARE Ultralight / NTAG | Yes where Core NFC exposes it | Yes | Yes where supported | MIFARE native | Only where protocol permits |
| MIFARE DESFire EV1/EV2/EV3 | Family-level discovery | Yes | Yes where configured | Native + ISO 7816 APDU | Requires authorized keys/access conditions |
| MIFARE Plus | Partial / API-dependent | Partial | Tag-dependent | MIFARE transport where exposed | Credential-dependent |
| MIFARE Classic | Limited identification where visible | Limited | No Crypto1 implementation | Crypto1 unavailable through Core NFC | Not supported |
| ISO 7816 smart cards | For declared AIDs | Yes | Application-dependent | APDU | Application/credential-dependent |
| ISO 15693 / NFC-V | Yes | Yes | Type 5 where supported | Block/custom commands | Tag/security-dependent |
| FeliCa / NFC-F | For declared system codes | Yes | Type 3 where supported | FeliCa commands | Service/security-dependent |
| NFC Forum NDEF tags | Yes | Yes | Read/write according to status | Type-specific | Underlying-tag dependent |

## Default discovery pack

The 0.3.0 application bundle declares:

- ISO 7816 AID `D2760000850101` — NFC Forum Type 4 / NDEF application.
- FeliCa system code `12FC` — NFC Forum Type 3 / NDEF system.

These declarations improve discovery for public NFC Forum mappings without pretending iOS supports a wildcard for every smart-card application.

## MIFARE Classic

NFCCard does not implement Crypto1. iPhone/Core NFC does not expose a generic Crypto1 transport suitable for a universal MIFARE Classic tool.

## DESFire

NFCCard can grow read-only public metadata inspection and authorized secure-session support. Protected files/applications remain governed by the card's access conditions and legitimate keys.

Secure-session architecture is intended for standards-based algorithms such as AES-128, DES, 2K3DES, and 3K3DES using user-supplied authorized keys only.

## Reliability

A card can be standards-compatible and still fail a particular probe due to configuration, access conditions, RF timing, or platform limitations. NFCCard therefore records evidence, errors, and limitations instead of presenting an unsupported guess as certainty.
