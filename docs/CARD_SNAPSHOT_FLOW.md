# Card addition and non-NDEF cards (0.3.9)

0.3.8 retained Add/Analyze and Wallet but placed NDEF inspection first on Scan. That separate path did not save snapshots or link to Wallet, making an unsupported NDEF result appear to block adding a card entirely.

0.3.9 restores the prominent Add / Analyze entry point, and offers explicit Save Card to Library and Prepare Wallet Card from a completed NDEF inspection. These actions also work for NDEF-unsupported cards. The physical scan's public metadata, including the initial AID when supplied by Core NFC, is retained. Saving is local, explicitly requested, and reports disk errors instead of claiming success. Existing saved snapshots are not migrated or removed.

NDEF unsupported means Core NFC did not expose an NDEF message in this scan. It does not establish the exact chip model, encryption, absence of card memory, or inability to use a different card-specific protocol. The displayed capacity is NDEF capacity, not total memory; it is now shown as unavailable for unsupported NDEF.

Non-NDEF writes are **not implemented** by this update. ISO 7816 identifies a communication interface, not a universal memory layout or write command. A real implementation needs the card application's documented selection, addressing, write/commit and verification commands plus any authentication/secure messaging requirements. A UID or an AID alone is insufficient. Do not test speculative writes, formatting or key changes on a working access card.

A library snapshot or Wallet display pass does not reproduce an access credential or provide card emulation. Existing guarded NDEF writing is unchanged.

Regression tests cover unsupported-card persistence/reload/deduplication, metadata retention, disk failures, stale snapshots, absence of write capability, and simulator navigation from unsupported NDEF to Library and Wallet. The simulator fixture is DEBUG-only and excluded from Release. Physical-card validation is still required.
