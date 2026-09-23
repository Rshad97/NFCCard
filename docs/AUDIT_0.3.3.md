# NFCCard 0.3.3 recovery review

## Reproducible defects in 0.3.2

- Activation/session deadlines and user cancellation called `invalidate` but left `isScanning` set until the delegate replied. Missing invalidation callbacks could permanently disable scanning in that process.
- NFC construction, begin, invalidation, connection and some NDEF calls ran on the MainActor. A blocked framework/XPC call could block the interface and its watchdog tasks.
- The SwiftUI error alert could overlap with Core NFC's system sheet.
- Installation refreshed icons but did not request a Sileo finish action. Removal unregistered a bundle identifier where uicache expects a bundle path, and update/removal did not stop the existing NFCCard process.

## Changes

`NFCScanner` is a testable MainActor coordinator. It drops the active session token and cancels deadlines before asking the driver to stop. Every late callback is checked against its session token. `CoreNFCReader` owns the framework objects and all their calls on a serial worker queue. NDEF query/read/timeout/cancel operations share that queue and reject late responses.

Errors appear inline. The diagnostic share action includes the app/OS version, original error domain/code/message and a bounded log. No automatic retry loop or service restart is performed by the app.

The package requests `finish:restart` through Sileo's supplied file descriptor. Sileo displays Restart SpringBoard after installation and runs sbreload when the user taps it. The maintainer script does not kill SpringBoard during dpkg installation.

Reference implementation reviewed: Sileo/Sileo commit `c9f70158a037dc76b91c450e72af2de0514dd3ee`, `Sileo/Backend/APT Wrapper/APTWrapper.swift` and `Sileo/UI/DownloadsViewController/DownloadsTableViewController.swift`.

## Validation gates

- 12 Swift tests of the production coordinator, including absent invalidation callbacks, activation/session deadlines, stale callbacks, permission failures, retries, background cancellation and a blocked reader worker.
- 7 Python tests executing the actual maintainer scripts with mock commands and a real Sileo-style finish pipe.
- An iPhone simulator UI test: fail the NFC availability check, dismiss the inline error, retry three times, and navigate to Library and back.
- Release device compile, decoded icon, bundle metadata, extracted signed TAG entitlement, and equality of the packaged maintainer scripts to the tested sources.

The approved PNG/SVG icon and asset-catalog configuration are unchanged.

## Remaining device-specific check

There is no physical NFC-capable jailbroken iPhone attached to CI. These tests establish application recovery and package correctness; they cannot establish the cause of an unprovided on-device error or prove that the NFC daemon grants access. If the reader still refuses to start, the exact error from Share Diagnostic Report is needed. A respring need not restart the NFC daemon and cannot fix a missing entitlement by itself.
