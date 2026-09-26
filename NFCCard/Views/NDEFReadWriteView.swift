import SwiftUI

struct NDEFReadWriteView: View {
    @EnvironmentObject private var scanner: NFCScanner
    @State private var felica = false
    @State private var kind: NDEFWritePolicy.DraftKind = .text
    @State private var content = ""
    @State private var pending: NDEFWritePlan?
    @State private var confirming = false
    @State private var preparationError: String?
    @State private var savedInspection: Date?
    @FocusState private var editing: Bool

    private var profile: NFCScanProfile { felica ? .felica : .standard }
    private var draft: [NDEFRecordData]? { try? NDEFWritePolicy.draft(content, kind: kind) }

    var body: some View {
        List {
            Section("1. Read and inspect") {
                Toggle("FeliCa / NFC-F", isOn: $felica).disabled(!scanner.canStartScan)
                Button {
                    pending = nil
                    preparationError = nil
                    scanner.readNDEF(profile: profile)
                } label: { Label("Read NDEF", systemImage: "wave.3.right") }
                .disabled(!scanner.canStartScan)
                .accessibilityIdentifier("ndef.read")
                Text("Read the physical tag first. No write is performed by this button. Keep only one tag near the top of the iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(scanner.statusMessage).accessibilityIdentifier("ndef.status")
                if scanner.isScanning {
                    Button("Cancel NFC Operation", role: .destructive) { scanner.cancelScan() }
                }
                if scanner.isRecovering { Text("Closing NFC session…").font(.footnote) }
                if let error = scanner.errorMessage {
                    Text(error).foregroundStyle(.red).accessibilityIdentifier("ndef.error")
                }
            }

            if let result = scanner.lastNDEFRead {
                Section("Add this card") {
                    Button("Save Card to Library") {
                        if scanner.saveNDEFSnapshot() { savedInspection = result.inspectedAt }
                    }
                    .disabled(!scanner.canStartScan || savedInspection == result.inspectedAt)
                    .accessibilityIdentifier("ndef.save-card")
                    NavigationLink { WalletCardView(card: result.cardSnapshot) } label: {
                        Label("Prepare Wallet Card", systemImage: "wallet.pass")
                    }
                    .disabled(!scanner.canStartScan)
                    .accessibilityIdentifier("ndef.wallet")
                    if savedInspection == result.inspectedAt {
                        Text("Card snapshot saved to Library.").accessibilityIdentifier("ndef.saved")
                    }
                    Text("Adding a snapshot or preparing a Wallet display pass does not require NDEF support. It does not copy protected card data or make the phone an access credential.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Inspected tag") {
                    LabeledContent("Technology", value: result.technology)
                    LabeledContent("NDEF access", value: result.access.rawValue)
                    LabeledContent("NDEF capacity", value: result.access == .unsupported ? "Not available" : "\(result.capacity) bytes")
                    Text("Tag identifier: \(result.identity.isEmpty ? "Unavailable" : result.identity)")
                        .font(.caption.monospaced()).textSelection(.enabled)
                    if let records = result.records {
                        Text("\(records.count) NDEF record(s)")
                        ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                            DisclosureGroup("Record \(index + 1) — \(record.payload.count) payload bytes") {
                                Text(record.displayValue).textSelection(.enabled)
                                Text("TNF: \(record.format) · Type: \(record.type.hexString)").font(.caption.monospaced())
                                Text("Record identifier: \(record.identifier.hexString)").font(.caption.monospaced())
                                DisclosureGroup("Raw payload (hex)") {
                                    Text(record.payload.hexString).font(.caption.monospaced()).textSelection(.enabled)
                                }
                            }
                        }
                    } else {
                        Text("Core NFC did not report NDEF support in this scan. This does not identify the exact chip, prove encryption, or measure total card memory. You can still save its public snapshot and prepare a Wallet display pass.")
                            .foregroundStyle(.orange)
                    }
                    if result.access == .readOnly { Text("Read-only tag. Writing is disabled.").foregroundStyle(.orange) }
                }
            }

            Section("2. Prepare replacement") {
                Picker("Record type", selection: $kind) {
                    ForEach(NDEFWritePolicy.DraftKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                TextField(kind == .text ? "Text to write" : "https://example.com", text: $content, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3...6)
                    .focused($editing)
                    .accessibilityIdentifier("ndef.content")
                if let draft {
                    Text("Encoded message: \(NDEFWritePolicy.byteCount(draft)) bytes")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Review Write…", role: .destructive) { prepare() }
                    .disabled(!scanner.canStartScan || scanner.lastNDEFRead?.canPrepareWrite != true || draft == nil)
                    .accessibilityIdentifier("ndef.review")
                if let preparationError { Text(preparationError).foregroundStyle(.red) }
                Text("Writing replaces ALL existing NDEF records with this one record. The inspected tag and its old content must match on the second scan. Confirmation expires after two minutes. Never use a production access card as a test tag.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .disabled(scanner.isScanning || scanner.isRecovering)

            Section("Scope") {
                Text("Writing outside NDEF requires a driver for the card's actual application: documented commands, file layout and any required authentication. ISO 7816 alone is not enough to select a write command. No such driver has been configured for this card.")
                    .font(.footnote)
                Text("NDEF text and web URLs only. This does not copy a complete card, change its UID, unlock protected memory, emulate a card, or activate access on an ACID reader. No formatting, permanent locking or access-key changes are performed.")
                    .font(.footnote).accessibilityIdentifier("ndef.scope")
                Text("A successful write is reported only after reading the same message back. If interrupted, read the tag again before deciding whether to retry.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Read / Write NDEF")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }.accessibilityIdentifier("ndef.done")
            }
        }
        .alert("Replace NDEF content?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { pending = nil }
            Button("Replace on This Tag", role: .destructive) {
                if let pending { scanner.writeNDEF(confirmed: pending, profile: profile) }
                pending = nil
            }
        } message: {
            Text("Tag: \(pending?.before.identity ?? "")\nThis replaces all existing NDEF records. Hold this same tag near the iPhone again and keep it still until verification completes.")
        }
        .onDisappear {
            pending = nil
            if scanner.isNDEFOperation { scanner.cancelScan() }
        }
    }

    private func prepare() {
        do {
            guard let before = scanner.lastNDEFRead else { return }
            let plan = NDEFWritePlan(before: before, replacement: try NDEFWritePolicy.draft(content, kind: kind))
            try NDEFWritePolicy.validate(plan)
            pending = plan
            preparationError = nil
            confirming = true
        } catch { preparationError = error.localizedDescription }
    }
}
