# Changelog

## 0.3.2

- Ignore callbacks from expired NFC sessions and prevent duplicate tag connections or completion after cancellation.
- Limit the diagnostic log to 300 entries to avoid unbounded memory growth.
- Replace the damaged app icon with a valid black/blue 1024×1024 PNG and editable SVG source.
- Decode and validate the icon during CI; build pull requests without publishing packages.

## 0.3.1

### Reader-session compatibility
- Split the default reader into a standard ISO 14443 + ISO 15693 session.
- Moved FeliCa / NFC-F discovery into a dedicated ISO 18092 session.
- This prevents an NFC-F system-code/configuration problem from invalidating the normal MIFARE/DESFire/NTAG/ISO15693 reader path.
- Increased the activation watchdog from 5 to 8 seconds to avoid false activation failures on slower SpringBoard/Core NFC launches.
- Added the active scan profile to Runtime Diagnostics and the Flight Recorder.

### UI
- Added a dedicated **Analyze FeliCa / NFC-F** action.
- Kept the black/blue NFCCard AppIcon in the application bundle and Sileo metadata.

### Audit
- Re-checked scanner lifecycle, NDEF one-shot completion, Card Library persistence, Key Vault update semantics, Protocol Atlas parsing, Info.plist discovery identifiers, rootless package paths, and CI entitlement validation.

## 0.3.0

### Scanner reliability
- Added a dedicated Core NFC reader queue.
- Added protection against duplicate scan sessions.
- Added a 5-second activation watchdog.
- Added a 55-second session watchdog.
- Added an explicit Cancel Scan action.
- Surface reader invalidation errors to the UI.
- Preserve successful "Card analyzed" state after intentional session invalidation.

### NDEF reliability
- Added a one-shot completion guard.
- Added a 4-second operation timeout.
- Preserve useful NDEF capability metadata when reading the message itself fails.

### Diagnostics
- Added Runtime Diagnostics for Core NFC availability, bundle discovery configuration, current session state, and local storage state.
- Added build-time validation of NFC usage strings, AID/system-code configuration, asset catalog, and signed TAG entitlement.

### Protocol Atlas
- Promoted Protocol Atlas into the stable release.
- Added evidence-based card-family classification.
- Added confidence scoring, evidence trail, suggested read-only probes, and limitations.
- Fixed ISO 15693 manufacturer-code parsing.

### Packaging and UI
- Added the black/blue NFCCard app icon.
- Added `UIRequiredDeviceCapabilities` for NFC.
- Added the NFC Forum Type 4 / NDEF AID `D2760000850101`.
- Retained the NFC Forum Type 3 / NDEF FeliCa system code `12FC`.
- Sileo metadata now publishes an icon URL.

### Data safety
- Key Vault now updates existing secrets atomically instead of deleting first.
- Card Library now reports storage errors instead of silently ignoring them.
- Removed a force unwrap from the Application Support path.

## 0.2.2

- Fixed XcodeGen Info.plist handling.
- Added package metadata validation.
- Built and published the first installable rootless NFCCard application package.

## 0.2.0

- Added Card Genome, Capability Map, Privacy Radar, Protocol Lens, Card Library, Flight Recorder, Key Vault foundation, and Wallet Route Advisor.
