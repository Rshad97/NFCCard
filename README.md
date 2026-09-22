# NFCCard

NFCCard is an open-source iPhone NFC research and interoperability toolkit. It is designed to identify cards, map the capabilities iOS can actually expose, inspect standards-compliant public data, preserve privacy, and determine legitimate Apple Wallet / contactless provisioning paths.

NFCCard is intentionally protocol-first rather than vendor-first: the public project contains no dependency on any specific access-control system, issuer, reader vendor, or deployment.

## What makes NFCCard different

### Card Genome

Every scan produces a deterministic SHA-256 fingerprint derived only from public technical metadata such as technology, subtype, identifier, historical bytes and NDEF capability. Secret keys and protected contents are never included.

### Capability Map

NFCCard separates **what a card is** from **what this iPhone can actually do with it**: NDEF, ISO 7816 APDU, MIFARE native commands, ISO 15693, FeliCa and visible identifier metadata.

### Protocol Lens

The app has a modular protocol engine with NDEF, APDU, MIFARE, ISO 15693 and FeliCa lenses.

### Privacy Radar

NFCCard highlights public metadata exposed by a card and keeps card snapshots local unless the user exports them.

### Wallet Route Advisor

NFCCard maps legitimate Apple contactless paths instead of pretending every physical card can be cloned into Apple Wallet.

## Current milestone: 0.2.0

Implemented:

- multi-family NFC discovery foundation
- Card Genome
- NDEF public-record inspection
- Capability Map
- Privacy Radar
- Protocol Lens registry
- local Card Library
- Session Flight Recorder
- Keychain-backed authorized Key Vault foundation
- Wallet Route Advisor

See the documentation folder for architecture, security model, supported technologies and roadmap.

## Build

```sh
brew install xcodegen
xcodegen generate
open NFCCard.xcodeproj
```

A physical iPhone and an Apple Developer provisioning profile with NFC Tag Reading capability are required.

## License

MIT.
