# Apple Wallet and Contactless Paths

NFCCard uses a route model because "add this physical NFC card to Wallet" is not one universal Apple API.

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
