import SwiftUI

struct CardDetailView: View {
    @EnvironmentObject private var scanner: NFCScanner
    let card: NFCCardProfile

    private var displayedCard: NFCCardProfile {
        guard
            let latest = scanner.lastCard,
            let originalUID = card.uidHex,
            let latestUID = latest.uidHex,
            originalUID.caseInsensitiveCompare(latestUID) == .orderedSame
        else {
            return card
        }
        return latest
    }

    private var visibleProbe: NFCReadOnlyProbeResult? {
        guard
            let probe = scanner.lastProbe,
            let cardUID = displayedCard.uidHex,
            let probeUID = probe.observedUIDHex,
            cardUID.caseInsensitiveCompare(probeUID) == .orderedSame
        else {
            return nil
        }
        return probe
    }

    private var visibleSubtype: String? {
        guard let subtype = displayedCard.subtype, !subtype.isEmpty else { return nil }
        if let aid = displayedCard.details["Initial AID"],
           subtype.caseInsensitiveCompare(aid) == .orderedSame {
            return nil
        }
        return subtype
    }

    var body: some View {
        List {
            Section("Apple Wallet") {
                NavigationLink {
                    WalletCardView(card: displayedCard)
                } label: {
                    Label("Prepare Wallet Card", systemImage: "wallet.pass")
                }
                .accessibilityIdentifier("card.wallet")
            }

            Section("Identity") {
                LabeledContent("Technology", value: displayedCard.technology)
                if let subtype = visibleSubtype {
                    LabeledContent("Subtype", value: subtype)
                }
                if let uid = displayedCard.uidHex {
                    LabeledContent("UID") {
                        Text(uid).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if let genome = displayedCard.genome {
                    LabeledContent("Card Genome") {
                        Text(String(genome.prefix(16)).uppercased())
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            if displayedCard.technology.localizedCaseInsensitiveContains("ISO 7816") {
                Section("Chip Identification") {
                    Button {
                        scanner.startDESFireProbe(for: displayedCard)
                    } label: {
                        Label(
                            scanner.isProbeOperation ? "Running Read-Only Probe…" : "Run DESFire GetVersion Probe",
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                    .disabled(!scanner.canStartScan)
                    .accessibilityIdentifier("card.probe.desfire")

                    Text("Read-only identification only. This sends DESFire GetVersion and continuation commands; it does not authenticate, change keys, write memory, format the card, or alter access data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let probe = visibleProbe {
                        LabeledContent("Result", value: probe.summary)
                        LabeledContent("DESFire confirmed", value: probe.recognized ? "Yes" : "No")
                        LabeledContent("Status words", value: probe.statusText)

                        ForEach(probe.details.keys.sorted(), id: \.self) { key in
                            LabeledContent(key) {
                                Text(probe.details[key] ?? "—")
                                    .font(.caption.monospaced())
                                    .multilineTextAlignment(.trailing)
                                    .textSelection(.enabled)
                            }
                        }

                        if !probe.rawResponseHex.isEmpty {
                            DisclosureGroup("Raw GetVersion response") {
                                Text(probe.rawResponseHex)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    } else if scanner.isProbeOperation {
                        Text(scanner.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !displayedCard.matchedModules.isEmpty {
                Section("Protocol Lens") {
                    ForEach(displayedCard.matchedModules, id: \.self) { module in
                        Label(module, systemImage: "puzzlepiece.extension")
                    }
                }
            }

            Section("Write") {
                NavigationLink {
                    NDEFReadWriteView()
                } label: {
                    Label("Open NDEF Writer", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier("card.ndef-writer")

                if let ndef = displayedCard.ndef {
                    LabeledContent("NDEF write", value: ndef.access == .readWrite ? "Available after fresh read" : (ndef.access == .readOnly ? "Read-only" : (ndef.access == .unsupported ? "Unsupported" : "Unknown")))
                    if ndef.access == .readWrite {
                        Text("A fresh NDEF read is required immediately before every write. NFCCard verifies the result by reading the tag back.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if ndef.access == .unsupported {
                        Text("This card does not expose a generic NDEF write path. Application-specific protected memory is not modified.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Open the writer to inspect NDEF write capability on the physical tag.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let ndef = displayedCard.ndef {
                Section("NDEF") {
                    LabeledContent("Access", value: ndef.access.rawValue)
                    LabeledContent("NDEF capacity", value: ndef.access == .unsupported ? "Not available" : "\(ndef.capacity) bytes")
                    LabeledContent("Records", value: "\(ndef.records.count)")
                    ForEach(ndef.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.type.isEmpty ? record.typeNameFormat : record.type).font(.headline)
                            Text(record.payloadPreview).font(.caption.monospaced()).lineLimit(3)
                            Text("\(record.payloadLength) bytes").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !displayedCard.details.isEmpty {
                Section("Technical Data") {
                    ForEach(displayedCard.details.keys.sorted(), id: \.self) { key in
                        LabeledContent(key) {
                            Text(displayedCard.details[key] ?? "—")
                                .font(.caption.monospaced())
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .navigationTitle("Card Snapshot")
    }
}
