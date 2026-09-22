# Architecture

NFCCard is split into layers so card-family knowledge can grow without coupling everything to Core NFC sessions.

## Transport

`NFCScanner` owns Core NFC session lifecycle and captures only data returned by Apple's APIs.

## Discovery

`NDEFInspector` performs a non-mutating capability/read pass for public NDEF data.

## Intelligence

- `CardGenomeService` — deterministic public-metadata fingerprint.
- `CapabilityMapService` — maps card/transport capabilities exposed by iOS.
- `CardPrivacyAnalyzer` — explains public identifiers and metadata exposure.
- `CardModuleRegistry` — selects protocol-specific lenses.

## Persistence

`CardLibraryStore` stores local card snapshots as JSON in Application Support.

## Secrets

`KeyVault` stores user-authorized secret bytes in the iOS Keychain using ThisDeviceOnly accessibility. Card snapshots store only references/metadata, never secret key bytes.

## Presentation

SwiftUI views present Scan, Library, Lab and Wallet route surfaces.

## Future plugin boundary

Protocol modules should receive a transport abstraction rather than own `NFCTagReaderSession`. This allows deterministic testing with captured non-secret fixtures and prevents every card module from reimplementing session lifecycle.
