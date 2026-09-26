// swift-tools-version: 5.9
import PackageDescription

// Runs the production scan coordinator on macOS without NFC hardware.
let package = Package(
    name: "NFCCardCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "NFCCardCore", targets: ["NFCCardCore"])],
    targets: [
        .target(name: "NFCCardCore", path: "NFCCard", exclude: [
            "App", "Views", "Assets.xcassets", "Security", "Info.plist", "NFCCard.entitlements",
            "NFC/CoreNFCReader.swift", "NFC/CoreNDEFTag.swift", "NFC/NDEFInspector.swift", "NFC/NFCSigningDiagnostics.swift"
        ], sources: ["Models", "Modules", "Services", "NFC/NFCScanner.swift", "NFC/NFCReaderDriver.swift", "NFC/NFCErrorDiagnostics.swift", "NFC/Data+Hex.swift"]),
        .testTarget(name: "NFCCardCoreTests", dependencies: ["NFCCardCore"], path: "Tests/NFCCardCoreTests")
    ]
)
