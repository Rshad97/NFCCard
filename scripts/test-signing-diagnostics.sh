#!/bin/bash
# macOS prohibits unprovisioned NFC/custom entitlements. Exercise the real
# SecTask bridge with an empty signature and test positive classification in-process.
set -euo pipefail
nfccard_test_dir="$(mktemp -d)"
trap 'rm -rf "$nfccard_test_dir"' EXIT
cat > "$nfccard_test_dir/main.swift" <<'SWIFT'
import Foundation
let result = NFCSigningDiagnostics.inspect()
print(result.report)
precondition(result.missingTagEntitlement, "Empty signature must report a missing TAG entitlement")
precondition(result.report.contains("formats=missing"), "Runtime entitlement was not inspected")
precondition(!NFCSigningDiagnostics.isMissingTag(formats: ["TAG"], readSucceeded: true))
precondition(NFCSigningDiagnostics.isMissingTag(formats: ["NDEF"], readSucceeded: true))
precondition(!NFCSigningDiagnostics.isMissingTag(formats: nil, readSucceeded: false))
print("Runtime entitlement smoke test and three format classification cases passed")
SWIFT
swiftc -Xlinker -no_adhoc_codesign NFCCard/NFC/NFCSigningDiagnostics.swift "$nfccard_test_dir/main.swift" -o "$nfccard_test_dir/unsigned-check"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > "$nfccard_test_dir/empty.plist"
codesign --force --sign - --generate-entitlement-der --entitlements "$nfccard_test_dir/empty.plist" "$nfccard_test_dir/unsigned-check"
cat "$nfccard_test_dir/unsigned-check" > "$nfccard_test_dir/run-check"
chmod 0755 "$nfccard_test_dir/run-check"
codesign --verify --strict --verbose=4 "$nfccard_test_dir/run-check"
"$nfccard_test_dir/run-check"
