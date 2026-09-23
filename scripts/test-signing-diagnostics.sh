#!/bin/bash
# Execute the production SecTask bridge against two real, locally signed binaries.
set -euo pipefail
nfccard_test_dir="$(mktemp -d)"
trap 'rm -rf "$nfccard_test_dir"' EXIT
cat > "$nfccard_test_dir/main.swift" <<'SWIFT'
import Foundation
let result = NFCSigningDiagnostics.inspect()
print(result.report)
let missing = CommandLine.arguments[1] == "missing"
precondition(result.missingTagEntitlement == missing, "Wrong runtime entitlement result")
precondition(result.report.contains(missing ? "formats=missing" : "formats=TAG"), "Entitlement was not inspected")
SWIFT
swiftc NFCCard/NFC/NFCSigningDiagnostics.swift "$nfccard_test_dir/main.swift" -o "$nfccard_test_dir/unsigned-check"
cp "$nfccard_test_dir/unsigned-check" "$nfccard_test_dir/with-tag"
cp "$nfccard_test_dir/unsigned-check" "$nfccard_test_dir/without-tag"
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict/></plist>' > "$nfccard_test_dir/empty.plist"
codesign --force --sign - --entitlements NFCCard/NFCCard.entitlements "$nfccard_test_dir/with-tag"
codesign --force --sign - --entitlements "$nfccard_test_dir/empty.plist" "$nfccard_test_dir/without-tag"
"$nfccard_test_dir/with-tag" present
"$nfccard_test_dir/without-tag" missing
