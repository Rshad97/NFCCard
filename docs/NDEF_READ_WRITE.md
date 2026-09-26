# Read / Write NDEF (0.3.8)

Open **Scan → Read / Write NDEF**, or the same item in Lab. This is a physical-tag operation, not card emulation or Wallet activation.

1. Tap **Read NDEF** and present one tag. Standard mode polls ISO 14443 and ISO 15693; enable the FeliCa switch for NFC-F. No write is issued by this action.
2. Inspect access, capacity and records. Unsupported or read-only tags cannot be written. A transport/authentication error is never treated as an empty tag; only Core NFC's explicit zero-length-message condition is interpreted as an empty NDEF message.
3. Enter text or an absolute HTTP(S) URL (maximum 4096 input bytes). **Review Write** stays disabled until a writable tag has been successfully read.
4. Confirm replacement of **all** NDEF records, then present the same tag again within two minutes. The reader compares its identifier, technology, current access/capacity and the complete original message. If any guard fails, nothing is written.
5. Keep the tag stationary. The app calls `writeNDEF` once, then reads it back. Success requires record-by-record equality (TNF, type, record identifier and payload). A write error or failed verification is not success and is never retried automatically. An interrupted write can leave changed/partial content; read it again before deciding to retry.

Use a spare writable NDEF tag, not a production access card, for initial testing. This feature does not change UIDs, alter access keys, format tags, permanently lock memory, copy protected applications or emulate an ACID credential. The previously reported **NDEF unsupported / 0 bytes** card cannot be made writable by this feature.

Inspection/replacement content is held in memory, not placed in diagnostic logs or uploaded. Current content is compared before replacing it, but there is no automatic backup/rollback of overwritten data. Copy any data you need before confirming replacement. A tag identifier is a guard against accidental mix-ups, not cryptographic proof of identity.

The adapter executes Core NFC calls off the UI thread on the existing reader queue. All NFC tasks share one coordinator; callbacks from ended operations are discarded. Cancellation, backgrounding, navigation away and watchdog expiry stop the operation. Each attempted write consumes its inspection; retry needs another read and confirmation.

Verification: unit tests exercise the real transaction state machine with a fake tag (unsupported/read-only, errors, tag/content mismatch, size, expiry, cancellation, duplicate/late callbacks, write-once/read-back). Simulator UI tests cover disabled writes before inspection and retry after unavailable NFC. These tests do not replace a physical read/write test on the user's iPhone.
