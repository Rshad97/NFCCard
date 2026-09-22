# NFCCard

NFCCard is an open-source iPhone NFC research and interoperability toolkit. It is designed to identify cards, map the capabilities iOS can actually expose, inspect standards-compliant public data, preserve privacy, and determine legitimate Apple Wallet / contactless provisioning paths.

NFCCard is intentionally protocol-first rather than vendor-first: the public project contains no dependency on any specific access-control system, issuer, reader vendor, or deployment.

## What makes NFCCard different

### Card Genome

Every scan produces a deterministic SHA-256 fingerprint derived only from public technical metadata such as technology, subtype, identifier, historical bytes and NDEF capability. Secret keys and protected contents are never included.

This makes it possible to compare card families and recognize recurring card profiles without pretending that a UID alone is the card's identity.

### Capability Map

NFCCard separates **what a card is** from **what this iPhone can actually do with it**. A scan maps available transports and standards such as:

- NDEF read / write state
- ISO 7816 APDU transport
- MIFARE native-command transport
- ISO 15693 commands
- FeliCa commands
- visible identifier metadata

### Protocol Lens

The app has a modular protocol engine. Built-in lenses currently include:

- NDEF Lens
- APDU Lens
- MIFARE Lens
- ISO 15693 / Vicinity Lens
- FeliCa Lens

The module registry is designed so new card families can be added without rewriting the scanner or UI.

### Privacy Radar

NFCCard highlights public metadata exposed by a card: visible identifiers, public NDEF records, and protocol metadata that may make a card family fingerprintable. Card snapshots remain local unless the user exports them.

### Session Flight Recorder

The app records its own discovery activity in a readable diagnostic timeline. Secret material is excluded by design.

### Wallet Route Advisor

Rather than claiming that every physical card can be "cloned" into Apple Wallet, NFCCard maps the legitimate Apple paths that may apply:

- signed Apple Wallet passes / barcodes
- Wallet NFC / VAS where approved
- NFC & Secure Element Platform provisioning where eligible
- ISO 7816 HCE / CardSession where Apple allows the use case and territory

## Supported transport families

Core NFC supports protocol-specific interaction with ISO 7816, ISO 15693, FeliCa, and MIFARE tags. Actual discovery can additionally depend on static AIDs or FeliCa system codes declared by the app, and some technologies remain impossible on iPhone hardware/APIs.

MIFARE Classic Crypto1 is not exposed by Core NFC. Protected DESFire operations require legitimate authentication material. NFCCard does not extract keys, brute-force credentials, or bypass access controls.

## Encryption architecture

The Key Vault is designed for **user-supplied authorized keys only** and currently models:

- AES-128
- DES
- 2K3DES
- 3K3DES
- extensible future algorithms

Secrets are stored with the iOS Keychain using ThisDeviceOnly protection and are excluded from logs, exports, snapshots and Card Genome fingerprints.

## Apple platform reality

Apple exposes several different contactless paths; none is a universal card emulator.

- Core NFC: reader/writer and protocol-specific tag interaction.
- Wallet / VAS: entitlement and compatible-reader dependent.
- NFC & Secure Element Platform: Apple-approved credential provisioning for eligible partners/use cases/territories.
- CardSession HCE: managed entitlement and use-case/region restricted.

NFCCard treats these as separate routes and reports the distinction to the user.

## Current milestone: 0.2.0

Implemented:

- multi-family NFC discovery foundation
- Card Genome
- NDEF capability and public-record inspection
- Capability Map
- Privacy Radar
- Protocol Lens registry
- local Card Library
- Session Flight Recorder
- Keychain-backed authorized Key Vault foundation
- Wallet Route Advisor

Next milestones are documented in `docs/ROADMAP.md`.

## Build

The repository uses SwiftUI + Core NFC and includes an XcodeGen project description.

```sh
brew install xcodegen
xcodegen generate
open NFCCard.xcodeproj
```

A physical iPhone and an Apple Developer provisioning profile with NFC Tag Reading capability are required.

## Platform configuration note

Apple requires ISO 7816 AIDs and FeliCa system codes to be declared by the application. There is no legitimate wildcard that makes every ISO 7816 / FeliCa application discoverable. NFCCard will therefore use explicit, user-selected protocol packs in future builds instead of silently claiming universal discovery.

## Project principles

- Read-only discovery before mutation.
- No hidden write operations.
- No credential extraction or brute force.
- User-supplied keys stay in Keychain and out of logs.
- Public technical metadata is separated from protected contents.
- Platform limitations are shown rather than hidden.

## References

- Apple Core NFC: https://developer.apple.com/documentation/corenfc
- Apple NFC & SE Platform: https://developer.apple.com/support/nfc-se-platform
- Apple CardSession: https://developer.apple.com/documentation/corenfc/cardsession
- NXP MIFARE family: https://www.nxp.com/products/rfid-nfc/mifare-hf:MC_53422

## License

MIT. See `LICENSE`.
