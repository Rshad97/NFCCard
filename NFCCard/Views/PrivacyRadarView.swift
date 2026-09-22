import SwiftUI

struct PrivacyRadarView: View {
    let card: NFCCardProfile

    var body: some View {
        List(card.privacyInsights) { insight in
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(insight.title).font(.headline)
                    Spacer()
                    Text(insight.severity.rawValue.uppercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(insight.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        }
        .navigationTitle("Privacy Radar")
    }
}
