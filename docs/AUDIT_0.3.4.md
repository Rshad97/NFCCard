# NFCCard 0.3.4 activation review

## Evidence and limits

The supplied iOS 17.5.1 report shows one immediate `NFCError (202)` followed by two activation deadlines. It contains no active or tag-detected callback. It therefore does not establish a problem with the card, nor does error 202 identify a unique signing or daemon cause.

The published 0.3.3 DEB was extracted and its actual Mach-O signature decoded. Both CodeDirectories identify the executable as `NFCCard`, while Info.plist identifies the app as `com.rashad.nfccard`. Its only signed entitlement is `com.apple.developer.nfc.readersession.formats = [TAG]`. The former CI merely searched entitlement text for TAG and did not check identity consistency.

The coordinator released its busy flag before receiving an invalidation callback. Every subsequent start entered the same worker queue, even if the preceding framework call had never returned. Passing that worker as the framework delegate queue also unnecessarily coupled commands and callbacks. These are code-level defects; a deadlock inside Core NFC has not been reproduced on physical hardware here.

## Implementation

- Explicit ldid identifier `com.rashad.nfccard` and a separate jailbreak entitlement file containing TAG and `platform-application`. This is an on-device compatibility change, not a claim that error 202 always needs platform status. The standard Xcode entitlement file is unchanged. No fabricated team ID, NFC-daemon hook, sandbox-disable entitlement, root helper or daemon restart is introduced.
- Reference for jailbreak Core NFC packaging: [CattleGrid jailbreakEntitlement.plist](https://github.com/arslan2012/CattleGrid/blob/4142bff837ba3aad855a130ed9d63bdebf510dee/jailbreakEntitlement.plist). Only the relevant platform entitlement is used; unrelated skip-library-validation is omitted. The reference is not evidence of iOS 17.5.1 compatibility.
- Core NFC uses its default delegate queue; command work stays off the MainActor. The worker retains session ownership until invalidation is acknowledged. UI/navigation is released immediately, but another scan is gated on confirmed cleanup plus a 750 ms settling interval. A four-second cleanup deadline requests relaunch without creating more sessions. A genuine late acknowledgment can unlock scanning again.
- Before creating a session, runtime SecTask diagnostics read the executing process's actual TAG entitlement, when the OS exposes that API. A confirmed missing entitlement fails with an explicit installation error. Unavailable diagnostics do not masquerade as a permission rejection.
- Startup checkpoints distinguish availability, signing checks, construction, prompt configuration, begin, activation and invalidation. Nested errors are retained without exporting arbitrary userInfo values or card contents.
- Package scripts and approved icon assets are unchanged. Restart SpringBoard refreshes registration but is not claimed to restart nfcd.

## Validation gates

17 Swift coordinator/diagnostic tests include the reported 202 → silent activation sequence, absent/delayed cleanup, rejected retries, stale callbacks, success, backgrounding, a blocked worker and nested XPC errors. Seven tests run the real maintainer scripts. The iPhone simulator UI test verifies error recovery and navigation. Release-device compilation, cryptographic executable signature verification and structured validation of both CodeDirectory identities and entitlements in the extracted DEB gate publication.

The validator rejects the actual published 0.3.3 payload for its identity mismatch. This is useful regression evidence, not proof that identity mismatch alone caused the reported NFC failure.

The new dynamic SecTask bridge is also executed on macOS against a real helper with an empty signed entitlement dictionary. It must report the absent production NFC entitlement. Three in-process classification cases cover TAG present, NDEF-only and an unreadable signature. macOS AMFI rejected positive launch fixtures with NFC and custom entitlements (`Restricted entitlements not validated`), so positive runtime entitlement acceptance cannot be tested on this unprovisioned host. The fixture respects that restriction; it does not disable signature enforcement. The actual iPhone TAG/platform signature is checked structurally and cryptographically in the packaged binary, and actual iPhone reader permission still requires device testing.

## Device acceptance still required

After the Sileo update and Restart SpringBoard, open NFCCard, start one scan and check that the system sheet appears and the log contains `Reader session active`. Then test a known compatible tag and the user's card separately. Cancel and rescan after cleanup. If activation fails again, share the 0.3.4 report: its runtime entitlement values, last startup checkpoint and underlying errors are necessary to distinguish signature rejection from a device NFC service problem. No physical jailbroken iPhone is attached to CI, so successful card reading is not claimed by this audit.
