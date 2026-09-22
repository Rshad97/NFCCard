# NFCCard Roadmap

## 0.2 — Genome

- [x] Card Genome public-metadata fingerprint
- [x] Capability Map
- [x] Privacy Radar
- [x] NDEF public-record inspection
- [x] Protocol Lens registry
- [x] Local Card Library
- [x] Session Flight Recorder
- [x] Keychain-backed authorized key foundation
- [x] Wallet Route Advisor

## 0.3 — Protocol Atlas

- [ ] Stronger MIFARE family classification
- [ ] NTAG / Ultralight version and memory-layout inspector
- [ ] ISO 15693 system-information inspector
- [ ] FeliCa specification/system-code inspector for explicitly configured system codes
- [ ] Type 2 / Type 4 / Type 5 NDEF structure visualization
- [ ] Read-only DESFire application/file metadata discovery when access conditions permit
- [ ] Protocol confidence score with evidence trail

## 0.4 — Snapshot Diff

- [ ] Compare two scans by Card Genome
- [ ] Highlight changes in NDEF, memory metadata and configuration
- [ ] Timeline per locally saved card profile
- [ ] Redaction controls before export
- [ ] JSON diagnostic bundle export

## 0.5 — NDEF Studio

- [ ] Compose URI, Text, MIME and External Type records
- [ ] Preview exact bytes before writing
- [ ] Explicit write confirmation
- [ ] Lock-state warning and irreversible-operation protection
- [ ] Write verification pass

## 0.6 — Authorized Secure Sessions

- [ ] Key Vault UI
- [ ] AES-128 / DES / 2K3DES / 3K3DES crypto provider abstraction
- [ ] User-authorized DESFire authentication adapters
- [ ] Secure-session transcript redaction
- [ ] No default keys, no brute force, no credential extraction

## 0.7 — Wallet Studio

- [ ] Wallet pass design model
- [ ] Barcode/QR/Aztec/PDF417 route
- [ ] PassKit signing workflow integration point
- [ ] VAS eligibility checklist
- [ ] NFC & SE Platform eligibility checklist
- [ ] CardSession eligibility diagnostics where API/entitlement is available

## 0.8 — Protocol Packs

Apple requires explicit ISO 7816 AIDs and FeliCa system codes. NFCCard will expose transparent build-time protocol packs instead of pretending wildcard discovery is possible.

- [ ] Public standards pack
- [ ] User-defined AID pack
- [ ] User-defined FeliCa system-code pack
- [ ] Generated Info.plist configuration
- [ ] Pack validation and duplicate detection

## 1.0 — NFCCard Platform

- [ ] Stable plugin SDK
- [ ] Offline card-family knowledge base
- [ ] Evidence-based identification engine
- [ ] Card Genome comparison database stored locally
- [ ] Signed diagnostic exports
- [ ] Public documentation and test-card matrix
