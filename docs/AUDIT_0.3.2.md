# NFCCard 0.3.2 review

The previous `design/AppIconSource.png` had a PNG header but its image data could not be decoded by a standard image reader. It has been replaced with a valid RGB PNG and an editable vector source. CI now decodes the PNG before packaging.

The tag reader previously accepted late activation, connection, NDEF, or invalidation callbacks after a session had been canceled or superseded. The scanner now checks session identity and active state before changing UI or saving a card. A tag connection in progress blocks duplicate connection requests, and cancellation blocks late completion. The session log is capped at 300 messages.

Validation requires the macOS GitHub Actions device build, entitlement and asset checks, DEB packaging, then a test on a physical NFC-capable iPhone. GitHub Actions cannot reproduce every runtime crash or verify a physical card read. For a remaining crash, collect the iOS crash report and the Session Flight Recorder log with the installed version.
