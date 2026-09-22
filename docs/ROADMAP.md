# NFCCard Roadmap

## 0.3 — Protocol Atlas / reliability

- [x] scanner lifecycle watchdogs
- [x] user-visible NFC errors
- [x] NDEF operation timeout
- [x] Runtime Diagnostics
- [x] stable Protocol Atlas UI
- [x] evidence/confidence model
- [x] MIFARE family classification foundation
- [x] ISO 7816 classification foundation
- [x] ISO 15693 classification foundation
- [x] FeliCa classification foundation
- [x] black/blue app icon
- [x] rootless/Sileo package verification

Next:
- [ ] NTAG / Ultralight GET_VERSION inspector
- [ ] ISO 15693 Get System Information inspector
- [ ] FeliCa request-system-code inspector for declared systems
- [ ] Type 2 / Type 4 / Type 5 NDEF structure visualization
- [ ] read-only DESFire version/application metadata discovery where access conditions permit
- [ ] richer product-revision knowledge base from published standards/vendor metadata

## 0.4 — Snapshot Diff

- [ ] compare two snapshots
- [ ] highlight NDEF/configuration changes
- [ ] timeline per Card Genome
- [ ] redaction controls
- [ ] JSON diagnostic export
- [ ] export/import schema versioning

## 0.5 — NDEF Studio

- [ ] compose URI, Text, MIME, and External Type records
- [ ] exact-byte preview
- [ ] explicit write confirmation
- [ ] lock-state and irreversible-operation warnings
- [ ] post-write verification

## 0.6 — Authorized Secure Sessions

- [ ] Key Vault UI
- [ ] AES-128 / DES / 2K3DES / 3K3DES provider abstraction
- [ ] user-authorized DESFire authentication adapters
- [ ] secure-session transcript redaction
- [ ] no default-key spraying
- [ ] no brute force
- [ ] no credential extraction

## 0.7 — Wallet Studio

- [ ] Wallet pass design model
- [ ] QR / Aztec / PDF417 / Code 128 route
- [ ] PassKit signing integration point
- [ ] VAS eligibility checklist
- [ ] NFC & Secure Element Platform checklist
- [ ] CardSession eligibility diagnostics

## 0.8 — Protocol Packs

- [ ] public standards AID pack
- [ ] user-defined AID configuration
- [ ] user-defined FeliCa system-code configuration
- [ ] validated generated Info.plist configuration
- [ ] duplicate/conflict detection

## 1.0 — NFCCard Platform

- [ ] stable plugin SDK
- [ ] offline card-family knowledge base
- [ ] evidence-based identification engine
- [ ] local Card Genome comparison database
- [ ] signed diagnostic exports
- [ ] public test-card matrix
