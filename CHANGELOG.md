# Changelog

## 0.3.5

- Add the NDEF reader format and jailbreak Core NFC framework compatibility entitlement to the rootless device signature. The 0.3.4 report showed iOS 17.5.1 invalidating every tag session before `didBecomeActive` (`NFCError 202`), so no card was ever polled.
- Keep standard Xcode entitlements unchanged; the compatibility entitlement is only applied by the jailbreak packaging workflow.

## 0.3.4

- Match the jailbreak executable's CodeDirectory signing identifier to its bundle identifier; the published 0.3.3 binary used `NFCCard` instead of `com.rashad.nfccard`.
- Ad-hoc sign the complete application bundle with native codesign, including the Info.plist/resource seal and DER entitlements; validate the full seal before and after DEB extraction.
- Use a dedicated jailbreak signing profile with TAG and platform-application entitlements; retain the standard profile for ordinary Xcode builds.
- Give Core NFC its own delegate queue, separate from the app's serial command worker.
- Wait for confirmed session invalidation and a short settling interval before enabling another scan. If closure never arrives, keep navigation responsive and request an app relaunch instead of queuing more sessions.
- Diagnose error 202 explicitly; record runtime entitlements, startup stages and nested error causes.
- Verify the actual signed identity and entitlements again after extracting the final DEB.
- Add regressions for the reported 202 → silent activation sequence, absent/delayed cleanup, stale cleanup and nested errors. Preserve the existing icon and Sileo restart action.

## 0.3.3

- Release UI state on cancel, timeout, backgrounding and errors without waiting for a Core NFC invalidation callback.
- Run availability checks, session construction, begin/invalidate, tag connection and NDEF operations on a serial worker queue.
- Cancel NDEF operations and ignore late results before they can start another read.
- Present errors inline and add shareable diagnostics with exact error domain/code and version.
- Request Sileo's Restart SpringBoard finish action, terminate the old app on update/removal and unregister the bundle by path.
- Add coordinator regression tests, maintainer-script tests and an iPhone simulator UI test as release gates.
- Preserve the approved 0.3.2 icon byte-for-byte.

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
