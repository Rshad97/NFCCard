import SwiftUI
import CoreNFC

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
                LabeledContent("Core NFC available", value: NFCReaderSession.readingAvailable ? "Yes" : "No")
            }

            Section("Bundle Configuration") {
                LabeledContent("Usage description", value: usageDescription?.isEmpty == false ? "Present" : "Missing")
                LabeledContent("ISO 7816 AIDs", value: "\(iso7816AIDs.count)")
                LabeledContent("FeliCa system codes", value: "\(felicaSystemCodes.count)")

                if !iso7816AIDs.isEmpty {
                    ForEach(iso7816AIDs, id: \.self) { aid in
                        Text(aid).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }

                if !felicaSystemCodes.isEmpty {
                    ForEach(felicaSystemCodes, id: \.self) { code in
                        Text("FeliCa \(code)").font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }

            Section("Session") {
                LabeledContent("Scanning", value: scanner.isScanning ? "Yes" : "No")
                Text(scanner.statusMessage).foregroundStyle(.secondary)
                if let error = scanner.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("Local Storage") {
                LabeledContent("Saved cards", value: "\(library.cards.count)")
                if let error = library.storageError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("Card library storage is available.").foregroundStyle(.secondary)
                }
            }

            Section {
                Text("The GitHub build also validates that the packaged executable contains the Core NFC TAG entitlement before publishing the DEB.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Runtime Diagnostics")
    }
}
