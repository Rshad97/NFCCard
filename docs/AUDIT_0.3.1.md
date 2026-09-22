# NFCCard 0.3.1 Audit

A full source audit was performed before the 0.3.1 package build.

## Files reviewed

- application entry point and SwiftUI navigation
- Core NFC session lifecycle
- NDEF inspector
- card profile and capability models
- Protocol Atlas classifier
- Card Genome generation
- Card Library persistence
- Key Vault update/read/delete flow
- runtime diagnostics
- Info.plist discovery identifiers
- rootless packaging workflow
- Sileo metadata generation
- AppIcon asset pipeline

## Compatibility issue found

The stable 0.3.0 reader requested ISO 14443, ISO 15693, and ISO 18092 in one mixed session.

FeliCa / NFC-F discovery has additional system-code configuration requirements. Isolating ISO 18092 from the standard reader makes the main scan path more robust and prevents an NFC-F discovery/configuration problem from taking down the MIFARE/DESFire/NTAG/ISO15693 session.

## Fix

0.3.1 uses two explicit profiles:

- **Analyze NFC Card** → ISO 14443 + ISO 15693
- **Analyze FeliCa / NFC-F** → ISO 18092

The standard path covers MIFARE, DESFire, NTAG/Ultralight, declared ISO 7816 applications, and ISO 15693/NFC-V.

The reader activation watchdog was relaxed from 5 to 8 seconds to reduce false failures while SpringBoard/Core NFC is presenting the system sheet.

## Image / packaging

The black/blue NFCCard icon is committed at:

`design/AppIconSource.png`

The macOS CI resizes it into the AppIcon asset catalog, then verifies the final app contains `Assets.car` before the DEB is published.

## Verification gate

The GitHub build remains the authoritative gate. It must pass:

- Xcode device compile
- Info.plist version and bundle-ID validation
- NFC usage-description validation
- ISO 7816 AID validation
- FeliCa system-code validation
- compiled asset-catalog validation
- signed TAG entitlement validation
- rootless DEB packaging
