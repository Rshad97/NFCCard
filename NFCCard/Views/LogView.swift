import SwiftUI

struct LogView: View {
    @EnvironmentObject private var scanner: NFCScanner

    var body: some View {
        List(Array(scanner.log.enumerated()), id: \.offset) { _, line in
            Text(line)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .navigationTitle("Flight Recorder")
        .toolbar {
            ShareLink(item: scanner.diagnosticReport) { Image(systemName: "square.and.arrow.up") }
        }
    }
}
