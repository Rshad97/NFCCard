import SwiftUI

struct WalletCompatibilityView: View {
    let card: NFCCardProfile

    var body: some View {
        List(WalletCompatibilityService.evaluate(card)) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    Text(item.status.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Text(item.explanation).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Wallet")
    }
}
