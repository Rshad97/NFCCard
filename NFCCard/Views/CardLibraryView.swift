import SwiftUI

struct CardLibraryView: View {
    @EnvironmentObject private var library: CardLibraryStore

    var body: some View {
        NavigationStack {
            List {
                if library.cards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No Card Snapshots").font(.headline)
                        Text("Analyze a card to create its first local snapshot.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(library.cards) { card in
                        NavigationLink {
                            CardDetailView(card: card)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.name == "Unknown Card" ? card.technology : card.name).font(.headline)
                                Text(card.genome.map { String($0.prefix(16)).uppercased() } ?? "No genome")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: library.remove)
                }
            }
            .navigationTitle("Library")
        }
    }
}
