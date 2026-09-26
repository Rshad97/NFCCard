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
                        Label(scanner.isScanning ? "Scanning…" : "Add / Analyze NFC Card", systemImage: "wave.3.right.circle.fill")
                    }
                    .disabled(!scanner.canStartScan)
                    .accessibilityIdentifier("scan.standard")

                    Button {
                        scanner.startFeliCaScan()
                    } label: {
                        Label("Analyze FeliCa / NFC-F", systemImage: "radiowaves.left.and.right")
                    }
                    .disabled(!scanner.canStartScan)
                    .accessibilityIdentifier("scan.felica")

                    if scanner.isScanning {
                        Button("Cancel Scan", role: .destructive) {
                            scanner.cancelScan()
                        }
                    }

                    if scanner.isRecovering {
                        Label("Closing the previous NFC session…", systemImage: "hourglass")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if scanner.requiresRelaunch {
                        Text("Close NFCCard from the app switcher and reopen it to recover the NFC reader.")
                            .font(.caption).foregroundStyle(.orange)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Status")
                        Spacer()
                        Text(scanner.statusMessage)
                            .accessibilityIdentifier("scan.status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Add a card to Library")
                } footer: {
                    Text("This saves a public card snapshot even without NDEF support. Open it in Library to prepare a Wallet display pass. Hold one card near the top of your iPhone.")
                }

                Section("Read / Write") {
                    NavigationLink { NDEFReadWriteView() } label: {
                        Label("Read / Write NDEF", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("ndef.open")
                }

                if let error = scanner.errorMessage {
                    Section("Scan could not finish") {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("scan.error")
                        if let details = scanner.errorDetails {
                            Text(details).font(.caption.monospaced()).textSelection(.enabled)
                        }
                        ShareLink(item: scanner.diagnosticReport) {
                            Label("Share Diagnostic Report", systemImage: "square.and.arrow.up")
                        }
                        Button("Dismiss Error") { scanner.dismissError() }
                            .accessibilityIdentifier("scan.dismiss-error")
                    }
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
        }
    }
}
