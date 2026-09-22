# Architecture

NFCCard is split into layers so card-family knowledge can grow without coupling every feature directly to a Core NFC session.

## Transport

`NFCScanner` owns the `NFCTagReaderSession` lifecycle.

The transport layer now has:

- a dedicated reader queue
- duplicate-session protection
- activation watchdog
- overall session watchdog
- explicit cancellation
- user-visible failure reporting
- clean success/invalidation state handling

## Discovery

`NDEFInspector` performs a non-mutating NDEF capability/read pass. A one-shot completion guard and timeout keep incompatible tags from stalling the analysis pipeline.

## Intelligence

- `CardGenomeService` — deterministic public-metadata fingerprint
- `CapabilityMapService` — maps transports/capabilities exposed by iOS
- `CardPrivacyAnalyzer` — explains public metadata exposure
- `CardModuleRegistry` — chooses applicable protocol lenses
- `ProtocolAtlasService` — evidence-based family/variant analysis with confidence and limitations

## Diagnostics

`RuntimeDiagnosticsView` exposes:

- Core NFC availability
- NFC usage description presence
- configured ISO 7816 AIDs
- configured FeliCa system codes
- reader/session status
- local Card Library storage health

GitHub Actions also validates the final packaged metadata, app icon, and TAG entitlement.

## Persistence

`CardLibraryStore` stores local snapshots as JSON in Application Support.

The store reports errors instead of silently discarding them and uses atomic writes with file protection.

## Secrets

`KeyVault` stores only user-authorized secret bytes in iOS Keychain using ThisDeviceOnly accessibility.

Secret bytes are not part of snapshots, Card Genome, logs, exports, or Protocol Atlas evidence.

## Presentation

SwiftUI surfaces:

- Scan
- Card Snapshot
- Protocol Atlas
- Capability Map
- Privacy Radar
- Library
- Lab
- Runtime Diagnostics
- Flight Recorder
- Wallet Route Advisor

## Module boundary

Future protocol modules should consume a transport abstraction instead of owning `NFCTagReaderSession`. This enables deterministic testing with non-secret fixtures and keeps session lifecycle centralized.
