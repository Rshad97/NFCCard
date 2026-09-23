import SwiftUI

struct RuntimeDiagnosticsView: View {
    @EnvironmentObject private var scanner: NFCScanner
    @EnvironmentObject private var library: CardLibraryStore

    private var usageDescription: String? {
        Bundle.main.object(forInfoDictionaryKey: "NFCReaderUsageDescription") as? String
    }

    private var iso7816AIDs: [String] {
        Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.nfc.readersession.iso7816.select-identifiers") as? [String] ?? []
    }

    private var felicaSystemCodes: [String] {
        Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.nfc.readersession.felica.systemcodes") as? [String] ?? []
    }

    var body: some View {
        List {
            Section("Device") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                LabeledContent("Core NFC available", value: scanner.readingAvailable.map { $0 ? "Yes" : "No" } ?? "Run a scan to check")
            }

            Section("Bundle Configuration") {
                LabeledContent("Usage description", value: usageDescription?.isEmpty == false ? "Present" : "Missing")
                LabeledContent("ISO 7816 AIDs", value: String(iso7816AIDs.count))
                LabeledContent("FeliCa system codes", value: String(felicaSystemCodes.count))

                if !iso7816AIDs.isEmpty {
                    ForEach(iso7816AIDs, id: \.self) { aid in
                        Text(aid).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }

                if !felicaSystemCodes.isEmpty {
                    ForEach(felicaSystemCodes, id: \.self) { code in
                        Text("FeliCa " + code).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }

            Section("Session") {
                LabeledContent("Scanning", value: scanner.isScanning ? "Yes" : "No")
                LabeledContent("Profile", value: scanner.currentScanProfile)
                LabeledContent("Reader cleanup", value: scanner.isRecovering ? "Waiting" : scanner.requiresRelaunch ? "Reopen app" : "Complete")
                Text(scanner.statusMessage).foregroundStyle(.secondary)
                if let error = scanner.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                if let details = scanner.errorDetails {
                    Text(details).font(.caption.monospaced()).textSelection(.enabled)
                }
                ShareLink(item: scanner.diagnosticReport) {
                    Label("Share Diagnostic Report", systemImage: "square.and.arrow.up")
                }
            }

            Section("Polling Strategy") {
                Text("Analyze NFC Card uses ISO 14443 + ISO 15693. This covers MIFARE/DESFire/NTAG/Ultralight, declared ISO 7816 applications and NFC-V.")
                Text("FeliCa/NFC-F uses a separate ISO 18092 session so an NFC-F entitlement/system-code problem cannot block the standard reader.")
                    .foregroundStyle(.secondary)
            }

            Section("Local Storage") {
                LabeledContent("Saved cards", value: String(library.cards.count))
                if let error = library.storageError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("Card library storage is available.").foregroundStyle(.secondary)
                }
            }

            Section {
                Text("The GitHub build validates that the final packaged executable contains the Core NFC TAG entitlement and that the app bundle contains the usage description, discovery identifiers, and compiled black/blue AppIcon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Runtime Diagnostics")
    }
}
