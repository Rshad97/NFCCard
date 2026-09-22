# 0.3.0 Project Audit

This audit was performed before the 0.3.0 release.

## Scanner lifecycle

### Found
The previous scanner set `isScanning` immediately but did not have an activation watchdog. If the Core NFC sheet/session failed to become active, the application could appear stuck on "Scanning…".

Most invalidation errors were written only to the internal log, so the user received little explanation.

### Fixed
- dedicated Core NFC reader queue
- duplicate scan guard
- 5-second activation watchdog
- 55-second session watchdog
- explicit Cancel Scan
- user-visible invalidation errors
- correct success state after intentional invalidation

## NDEF inspection

### Found
The previous NDEF path depended entirely on Core NFC callbacks returning. An abnormal callback stall could hold the scan pipeline.

### Fixed
- one-shot callback guard
- 4-second operation timeout
- preserve NDEF status/capacity when message reading fails

## Bundle / entitlement validation

### Found
The build checked some Info.plist metadata but the version assertion was hard-coded. It also applied the jailbreak NFC entitlement without verifying the signed executable actually contained it.

### Fixed
The CI now verifies:
- source version matches packaged version
- bundle identifier
- NFC usage description
- declared ISO 7816 AIDs
- FeliCa system codes
- NFC required-device capability
- compiled asset catalog
- signed Core NFC TAG entitlement

## ISO 7816 discovery

### Found
No ISO 7816 select identifier was declared in the first release.

### Fixed
Added the public NFC Forum Type 4 / NDEF AID:

`D2760000850101`

## Protocol Atlas

### Found
The development branch had an ISO 15693 manufacturer parsing bug: a value formatted as `0x04` could normalize incorrectly.

### Fixed
Normalization now strips the `0x` prefix before hexadecimal parsing.

Protocol Atlas is promoted into the stable 0.3.0 release.

## Key Vault

### Found
Replacing a stored secret deleted the previous Keychain item before creating the new one. An add failure could therefore lose the previous value.

### Fixed
Existing items now use `SecItemUpdate`; a new item is created only when no previous item exists.

## Card Library

### Found
- Application Support used a force unwrap.
- directory creation/read/write failures were silently ignored.

### Fixed
- safe path fallback
- published storage error state
- explicit do/catch
- atomic protected writes

## App icon

### Found
No AppIcon asset catalog was shipped.

### Fixed
Added the NFCCard black/blue icon to `Assets.xcassets/AppIcon.appiconset` and made CI fail if the compiled asset catalog is missing.

## Static validation

All project Swift files were syntax-parsed before publishing. Info.plist, asset JSON, and workflow YAML were also validated locally. The macOS GitHub Actions device build remains the authoritative compile/package test.
