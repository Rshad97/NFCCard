import SwiftUI

struct WalletHubView: View {
    @EnvironmentObject private var scanner: NFCScanner
    @EnvironmentObject private var library: CardLibraryStore

    var body: some View {
        NavigationStack {
            List {
                Section("Card display passes") {
                    if library.cards.isEmpty, scanner.lastCard == nil {
                        Text("Scan a card first to prepare its display pass. You can import an existing signed pass below without scanning.")
                    }
                    ForEach(library.cards.isEmpty ? [scanner.lastCard].compactMap { $0 } : library.cards) { card in
                        NavigationLink {
                            WalletCardView(card: card)
                        } label: {
                            Label(card.name == "Unknown Card" ? card.technology : card.name, systemImage: "wallet.pass")
                        }
                    }
                }
                Section("Apple Wallet") { WalletPassImportView() }
                Section("Contactless status") {
                    Text(WalletPassSource.limitation)
                        .accessibilityIdentifier("wallet.access-limitation")
                    if let card = scanner.lastCard ?? library.cards.first {
                        NavigationLink("Contactless Route Details") { WalletCompatibilityView(card: card) }
                    }
                }
            }
            .navigationTitle("Wallet")
        }
    }
}
