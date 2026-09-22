import SwiftUI

struct LabView: View {
    @EnvironmentObject private var scanner: NFCScanner

    var body: some View {
        NavigationStack {
            List {
                Section("Protocol Modules") {
                    ForEach(CardModuleRegistry.modules.map(\.descriptor)) { module in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(module.name).font(.headline)
                            Text(module.family).font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(module.summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Design") {
                    Label("Read-only discovery first", systemImage: "shield")
                    Label("User-authorized keys only", systemImage: "key")
                    Label("No secret material in logs or Card Genome", systemImage: "eye.slash")
                }

                Section("Flight Recorder") {
                    NavigationLink("Open NFC Log") { LogView() }
                    Button("Clear Log", role: .destructive) { scanner.clearLog() }
                }
            }
            .navigationTitle("Lab")
        }
    }
}
