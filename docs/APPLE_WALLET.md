# Apple Wallet and Contactless Paths

NFCCard uses a route model because "add this physical NFC card to Wallet" is not one universal Apple API.

## Implemented in 0.3.7

- From **Library → Card Snapshot → Prepare Wallet Card**, or the **Wallet** tab, preview a display pass, change its name and optionally include the public identifier.
- **Export Pass Source (.json)** saves unsigned source only. It is not a `.pkpass` and cannot be installed in Wallet as-is.
- **Import Signed Wallet Pass** opens Files, reads at most 10 MB off the UI thread, and uses `PKPass` to validate the package. Only after a pass has loaded does the native **Add to Apple Wallet** button appear. Apple's sheet lets the user add or cancel; closing it never triggers a false "added" result.
- Import also works without a new scan. Imported passes are independent issuer documents, not a conversion or verified association with a scanned credential.
- The preview and generated display pass explicitly say they cannot unlock an ACID reader. No NFC payload, barcode of the UID, remote service URL or authentication token is inserted.

No signing certificate, external signing endpoint or private key is configured or distributed. A local preview and successful unit tests do not demonstrate Wallet acceptance or reader compatibility.

### Offline signing

On a computer you control, use a valid **Apple Pass Type ID certificate** and its matching private key in PEM format, plus the corresponding Apple WWDR intermediate. They stay outside the app and repository. A self-signed certificate or the app's ad-hoc jailbreak signature does not replace Apple's pass certificate.

```sh
python3 scripts/sign-wallet-pass.py \
  --source /path/to/NFCCard-wallet-source.json \
  --certificate /secure/path/pass-certificate.pem \
  --private-key /secure/path/pass-private-key.pem \
  --wwdr /secure/path/AppleWWDR.pem \
  --pass-type-id pass.your.registered.identifier \
  --team-id YOURTEAMID \
  --output /path/to/NFCCard-display.pkpass
```

Use your actual registered identifier and 10-character Team ID, not these examples. For an encrypted key, supply `NFCCARD_WALLET_KEY_PASSWORD` through your local secret environment; do not put passwords in shell history, GitHub, diagnostic reports or chat. macOS uses its built-in `sips` to resize the existing app artwork into pass icons; other systems need Pillow. OpenSSL must support CMS and `verify -partial_chain`.

The tool validates the source allowlist and display-only labels, checks the certificate's UID/OU, expiry, intermediate chain and matching public key, hashes the bundle files, and signs a detached CMS manifest. It refuses to overwrite an existing output. Wallet itself remains the authority on Apple certificate trust and acceptance; the signer does not self-grant it.

Transfer the resulting `.pkpass` to Files and import it in NFCCard. There is no automatic network upload and no signing key is copied into the pass. Until real Apple signing credentials are configured, **preview and export are usable but creating an installable display pass is blocked**.

### Verification scope

`swift test` covers source encoding, stable pass identity, identifier privacy and bounded file import. `python3 scripts/test-wallet-pass.py` checks rejection of NFC/remote-service fields, manifest contents, signature verification and tampering. Its temporary self-signed certificates test the package format only and are never shipped. Simulator UI tests exercise the no-scan import entry and saved-card preview. End-to-end addition with a real Apple-signed pass and any physical reader still require device tests.

### ACID is separate and not implemented

An ISO 7816 identifier or NDEF discovery AID does not describe an access system's authentication requirements. A DESFire credential can require application-specific cryptographic authentication. Neither displaying its public UID nor passing it through Wallet recreates that credential. NFCCard has no low-level emulation backend and does not claim that this release opens any door. There are no key-extraction, authentication-bypass or `nfcd` takeover changes.

Apple references: [pass design and signing](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Creating.html), [adding passes through the system sheet](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/DistributingPasses.html).

## Route A — Apple Wallet pass

Useful for tickets, memberships, loyalty cards and identifiers that can legitimately be represented as a signed `.pkpass`, often with QR, Aztec, PDF417 or Code 128.

This does not emulate the original RF protocol.

## Route B — Wallet NFC / VAS

Contactless Wallet passes depend on Apple-approved capabilities and compatible certified reader infrastructure. This is an issuer/provider integration path, not a generic physical-card cloning API.

## Route C — NFC & Secure Element Platform

Apple's NFC & SE Platform supports approved secure credential use cases such as payments, car keys, transit, corporate badges, home keys, hotel keys, loyalty/rewards and event tickets. Availability depends on territory, use case, partner status, Apple agreements, entitlements, applet review and backend provisioning.

NFCCard can provide an eligibility/checklist layer, but it cannot self-grant these entitlements or convert an arbitrary existing card into a Secure Element credential.

## Route D — CardSession HCE

`CardSession` is Apple's ISO 7816 host-card-emulation API. It requires Apple-managed entitlements and is restricted by use case and territory. It is not a universal emulation mechanism for MIFARE/DESFire or proprietary cards.

## NFCCard Wallet Route Advisor

The advisor will answer four separate questions:

1. Is there a legitimate visual/barcode Wallet representation?
2. Is VAS a plausible reader/infrastructure route?
3. Is NFC & SE Platform provisioning applicable to the use case?
4. Is HCE/CardSession applicable to the protocol, region and entitlement?

The result is intentionally evidence-based rather than a misleading "compatible / incompatible" badge.
