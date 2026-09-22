import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var scanner: NFCScanner

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        scanner.startScan()
                    } label: {
                        Label(scanner.isScanning ? "Scanning…" : "Analyze NFC Card", systemImage: "wave.3.right.circle.fill")
                    }
                    .disabled(scanner.isScanning)

                    if scanner.isScanning {
                        Button("Cancel Scan", role: .destructive) {
                            scanner.cancelScan()
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Status")
                        Spacer()
                        Text(scanner.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("NFCCard performs a read-only discovery pass first: identity, public metadata, NDEF capability, protocol modules, Card Genome and privacy signals.")
                }

                if let card = scanner.lastCard {
                    Section("Last Scan") {
                        NavigationLink {
                            CardDetailView(card: card)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(card.technology).font(.headline)
                                if let subtype = card.subtype, !subtype.isEmpty {
                                    Text(subtype).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text(card.genome.map { "Genome " + String($0.prefix(16)).uppercased() } ?? "Genome pending")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Intelligence") {
                        NavigationLink("Protocol Atlas") {
                            ProtocolAtlasView(card: card)
                        }
                        NavigationLink("Capability Map") {
                            CapabilityMapView(card: card)
                        }
                        NavigationLink("Privacy Radar") {
                            PrivacyRadarView(card: card)
                        }
                        NavigationLink("Wallet Route Advisor") {
                            WalletCompatibilityView(card: card)
                        }
                    }
                }

                Section("Diagnostics") {
                    NavigationLink("Runtime Diagnostics") {
                        RuntimeDiagnosticsView()
                    }
                    NavigationLink("Session Flight Recorder") {
                        LogView()
                    }
                }
            }
            .navigationTitle("NFCCard")
            .alert("NFC Error", isPresented: Binding(
                get: { scanner.errorMessage != nil },
                set: { if !$0 { scanner.errorMessage = nil } }
            )) {
                Button("OK") { scanner.errorMessage = nil }
            } message: {
                Text(scanner.errorMessage ?? "Unknown error")
            }
        }
    }
}
