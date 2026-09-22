import SwiftUI

struct LogView: View {
    @EnvironmentObject private var scanner: NFCScanner

    var body: some View {
        List(scanner.log, id: \.self) { line in
            Text(line)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .navigationTitle("Flight Recorder")
    }
}
