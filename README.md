# NFCCard

NFCCard is an open-source iPhone NFC research and interoperability toolkit. It identifies compatible cards, maps the capabilities iOS actually exposes, inspects standards-compliant public data, highlights privacy-relevant metadata, and explains legitimate Apple Wallet/contactless provisioning routes.

The project is protocol-first and vendor-neutral. It contains no dependency on a specific access-control deployment, issuer, reader vendor, or private infrastructure.

## Current release — 0.3.2

NFCCard 0.3.2 fixes stale NFC session callbacks and replaces the invalid icon source with a decodable black/blue design.

Implemented:

- multi-family Core NFC discovery
- MIFARE / ISO 14443 identification
- ISO 7816 discovery for declared public AIDs
- ISO 15693 / NFC-V discovery
- FeliCa / NFC-F discovery for declared system codes
- NDEF status, capacity, and public-record inspection
- Card Genome SHA-256 fingerprint from public technical metadata
- Capability Map
- Privacy Radar
- Protocol Lens registry
- Protocol Atlas with evidence/confidence reporting
- local Card Library
- Session Flight Recorder
- Runtime Diagnostics
- Keychain-backed authorized Key Vault foundation
- Wallet Route Advisor
- black/blue NFCCard app icon
- rootless Dopamine/Sileo DEB packaging

## Scan reliability

The standard reader now polls ISO 14443 + ISO 15693, while FeliCa/NFC-F runs in a separate ISO 18092 session. This isolates NFC-F system-code/configuration failures from the main MIFARE/DESFire/NTAG/ISO15693 path. The reader lifecycle is also guarded by activation and session watchdogs, and NDEF inspection has its own timeout.

Runtime Diagnostics shows whether Core NFC is available and whether the bundle contains the required usage description and configured discovery identifiers.

## Card Genome

Each scan can produce a deterministic SHA-256 fingerprint from public technical metadata such as technology, subtype, identifier, historical bytes, and NDEF capability.

Secret keys, session keys, authentication cryptograms, and protected card content are never included.

## Protocol Atlas

Protocol Atlas turns raw discovery metadata into an evidence-based report:

- family
- variant
- confidence
- evidence trail
- suggested read-only probes
- platform/protocol limitations

The confidence score is deliberately evidence-based; NFCCard does not identify secure products from UID alone.

## Authorized Key Vault

The Key Vault is for **user-supplied, authorized keys only** and models AES-128, DES, 2K3DES, 3K3DES, and extensible future algorithms.

Secrets use iOS Keychain with ThisDeviceOnly protection and are excluded from Card Genome, logs, exports, and card snapshots.

NFCCard does not include credential extraction, brute force, default-key spraying, or access-control bypass.

## Apple Wallet routes

There is no universal Apple API that clones any physical NFC card into Wallet. NFCCard therefore separates legitimate routes:

- signed Apple Wallet passes / barcodes
- Wallet NFC / VAS when the issuer and reader infrastructure support it
- NFC & Secure Element Platform provisioning for eligible approved use cases
- ISO 7816 HCE / CardSession where Apple permits the use case, region, and entitlement

## iOS discovery configuration

The default public discovery pack includes:

- NFC Forum Type 4 / NDEF AID: `D2760000850101`
- NFC Forum Type 3 / NDEF FeliCa system code: `12FC`

Additional standards-oriented protocol packs are planned.

## Build

NFCCard uses SwiftUI + Core NFC and XcodeGen.

On macOS:

```sh
brew install xcodegen
sh ./scripts/prepare-app-icon.sh
xcodegen generate
open NFCCard.xcodeproj
```

The icon preparation step validates and copies the committed 1024×1024 black/blue PNG into the asset catalog. Its editable vector design is `design/AppIconSource.svg`.

A physical NFC-capable iPhone is required for real tag scanning.

GitHub Actions builds the device app, validates NFC metadata and the app icon, applies and verifies the jailbreak TAG entitlement, packages a rootless DEB, and publishes the standalone Sileo metadata.

## Installation

NFCCard is packaged for rootless jailbreaks at:

```text
/var/jb/Applications/NFCCard.app
```

Package ID: `com.rashad.nfccard`.

## Documentation

- `docs/ARCHITECTURE.md`
- `docs/SUPPORTED_TECH.md`
- `docs/APPLE_WALLET.md`
- `docs/SECURITY.md`
- `docs/AUDIT_0.3.0.md`
- `docs/AUDIT_0.3.2.md`
- `docs/ROADMAP.md`

## License

MIT. See `LICENSE`.
