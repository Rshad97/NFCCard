import SwiftUI

struct WalletHubView: View {
    @EnvironmentObject private var scanner: NFCScanner

    var body: some View {
        NavigationStack {
            Group {
                if let card = scanner.lastCard {
                    WalletCompatibilityView(card: card)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "wallet.pass").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Analyze a Card First").font(.headline)
                        Text("NFCCard will map the legitimate Apple contactless paths available for the card or use case.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Wallet")
        }
    }
}
