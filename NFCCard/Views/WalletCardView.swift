import SwiftUI
import UniformTypeIdentifiers

struct WalletCardView: View {
    let card: NFCCardProfile
    @State private var title: String
    @State private var includeIdentifier = false
    @State private var exporting = false
    @State private var document: WalletSourceDocument?
    @State private var message: String?

    init(card: NFCCardProfile) {
        self.card = card
        _title = State(initialValue: WalletPassSource.displayTitle(card.name))
    }

    private var source: WalletPassSource {
        WalletPassSource(card: card, title: title, includeIdentifier: includeIdentifier)
    }

    var body: some View {
        List {
            Section("Local preview — not yet in Wallet") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("NFCCard", systemImage: "wave.3.right").foregroundStyle(.blue)
                        Spacer()
                        Text("DISPLAY ONLY").font(.caption.bold()).foregroundStyle(.white)
                    }
                    Text(WalletPassSource.displayTitle(title)).font(.title2.bold()).foregroundStyle(.white)
                    Text(card.technology).foregroundStyle(.white.opacity(0.8))
                    if includeIdentifier, let uid = card.uidHex {
                        Text(uid).font(.caption.monospaced()).foregroundStyle(.white)
                    }
                    Text("Not an access credential").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(red: 0.04, green: 0.13, blue: 0.25), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("wallet.preview")
            }
            Section("Display details") {
                TextField("Card name", text: $title).accessibilityIdentifier("wallet.title")
                if card.uidHex != nil {
                    Toggle("Include public card identifier", isOn: $includeIdentifier)
                        .accessibilityIdentifier("wallet.include-identifier")
                }
                Text("The identifier is excluded by default. If included, it is visible on the pass and in the exported file. No secret keys or protected card data are exported.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Prepare for signing") {
                Button {
                    do {
                        document = WalletSourceDocument(data: try source.jsonData())
                        message = nil
                        exporting = true
                    } catch { message = "Could not prepare the pass source." }
                } label: {
                    Label("Export Pass Source (.json)", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("wallet.export-source")
                Text("This exports unsigned source, not an installable pass. The project includes an offline signing tool. A valid Apple Pass Type ID certificate is still required; no certificate or private key belongs in the app.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let message { Text(message).font(.footnote) }
            }
            Section("Add a signed pass") { WalletPassImportView() }
            Section("ACID / NFC status") {
                Text(WalletPassSource.limitation)
                    .accessibilityIdentifier("wallet.access-limitation")
                Text("NFCCard currently reads public card metadata. A Wallet display pass does not reproduce a DESFire application, cryptographic authentication, or the card's radio identity.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Wallet Card")
        .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                      defaultFilename: "NFCCard-wallet-source") { result in
            switch result {
            case .success: message = "Pass source exported. It is unsigned and has not been added to Wallet."
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { message = "Could not export the source. Please try again." }
            }
        }
    }
}

private struct WalletSourceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
