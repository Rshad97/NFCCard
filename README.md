# NFCCard

NFCCard is an open-source iPhone NFC research and interoperability toolkit. It identifies compatible cards, maps the capabilities iOS actually exposes, inspects standards-compliant public data, highlights privacy-relevant metadata, and explains legitimate Apple Wallet/contactless provisioning routes.

The project is protocol-first and vendor-neutral. It contains no dependency on a specific access-control deployment, issuer, reader vendor, or private infrastructure.

## Wallet development — 0.3.7

The Wallet screen now supports local display previews, unsigned pass-source export, and importing issuer-signed `.pkpass` files through Apple's confirmation sheet. An offline signing tool is included; a valid Apple Pass Type ID certificate is **not** supplied. See [Wallet setup](docs/APPLE_WALLET.md).

This is **not** NFC emulation or ACID access. Scanning a card only saves its public metadata, not its cryptographic credential. Nothing is uploaded automatically.

The reported 0.3.6 pre-activation failure stopped after the tester removed Aemulo. That is useful device evidence of a conflict, not proof that every error 202 has the same cause. The working NFC path, existing app icon, entitlements and shared Sileo repository are left unchanged in this Wallet update.

## Previous reader releases — through 0.3.6

NFCCard 0.3.4 addresses reader activation failures with consistent signing identity, a dedicated jailbreak signing profile, separate Core NFC callback/command queues, and confirmed cleanup before retries. Runtime diagnostics now include the installed process's NFC entitlement and the last completed startup stage. The approved icon and Sileo Restart SpringBoard action are unchanged.

NFCCard 0.3.5 adds the NDEF reader format and the jailbreak-only Core NFC framework compatibility entitlement. This targets iOS 17.5.1 sessions that were invalidated with error 202 before `didBecomeActive`; it does not alter normal Xcode signing or the approved icon.

NFCCard 0.3.6 releases a stale reader object in-app after a missing cleanup acknowledgment, so retrying does not require closing the app from the app switcher.

After updating, use Sileo's **Restart SpringBoard**, open NFCCard and scan once. If the NFC service never confirms closure, the app asks you to close it from the app switcher and reopen it; repeated taps cannot enqueue more stuck sessions. Share the new diagnostic report if activation still fails. Physical NFC reading on the target jailbreak still requires a device check; automated tests cannot prove that the system grants reader access.

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

## Recovery and diagnostics

A failed, canceled or timed-out scan releases the UI immediately, even if Core NFC never acknowledges invalidation. Backgrounding the app also ends its current scan. NFC framework calls run on a serial worker queue. Errors appear inline so an app alert cannot compete with the system NFC sheet. **Share Diagnostic Report** includes the app version, system version, NFC error domain/code and bounded session log.

Sileo installation terminates the old NFCCard process, refreshes its icon registration and requests **Restart SpringBoard** using Sileo's finish-action pipe. Tap that button once installation is complete. A respring does not prove NFC permissions or hardware are working.

## Tests

On macOS, `swift test` runs the production scan coordinator against injected reader failures, missing callbacks and a blocked worker. `python3 scripts/test-package-scripts.py` runs the actual maintainer scripts against mocked commands and a real pipe. CI also launches the iPhone simulator, retries the unavailable-NFC path and verifies navigation remains responsive before building/signing the device DEB. The simulator cannot read physical cards or validate a jailbroken device's NFC daemon permissions.

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

GitHub Actions builds the device app, validates NFC metadata and the app icon, signs with `packaging/NFCCard-jailbreak.entitlements` and the explicit `com.rashad.nfccard` identifier, and verifies the actual signature again inside the extracted rootless DEB before publishing Sileo metadata.

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
- `docs/AUDIT_0.3.3.md`
- `docs/AUDIT_0.3.4.md`
- `docs/ROADMAP.md`

## License

MIT. See `LICENSE`.
