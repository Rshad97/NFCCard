#!/bin/bash
# Exercise the SecTask bridge using an unrestricted test key. macOS does not
# permit unprovisioned helpers to launch with the iPhone NFC entitlement itself.
set -euo pipefail
nfccard_test_dir="$(mktemp -d)"
trap 'rm -rf "$nfccard_test_dir"' EXIT
cat > "$nfccard_test_dir/main.swift" <<'SWIFT'
import Foundation
let result = NFCSigningDiagnostics.inspect(formatsEntitlement: CommandLine.arguments[2])
print(result.report)
let missing = CommandLine.arguments[1] == "missing"
precondition(result.missingTagEntitlement == missing, "Wrong runtime entitlement result")
precondition(result.report.contains(missing ? "formats=missing" : "formats=TAG"), "Entitlement was not inspected")
SWIFT
swiftc NFCCard/NFC/NFCSigningDiagnostics.swift "$nfccard_test_dir/main.swift" -o "$nfccard_test_dir/unsigned-check"
cp "$nfccard_test_dir/unsigned-check" "$nfccard_test_dir/with-tag"
cp "$nfccard_test_dir/unsigned-check" "$nfccard_test_dir/without-tag"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > "$nfccard_test_dir/empty.plist"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>com.rashad.nfccard.test.reader-formats</key><array><string>TAG</string></array></dict></plist>' > "$nfccard_test_dir/test-format.plist"
codesign --force --sign - --entitlements "$nfccard_test_dir/test-format.plist" "$nfccard_test_dir/with-tag"
codesign --force --sign - --entitlements "$nfccard_test_dir/empty.plist" "$nfccard_test_dir/without-tag"
"$nfccard_test_dir/with-tag" present com.rashad.nfccard.test.reader-formats
"$nfccard_test_dir/without-tag" missing com.apple.developer.nfc.readersession.formats
