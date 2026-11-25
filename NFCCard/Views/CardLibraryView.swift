import SwiftUI

struct CardLibraryView: View {
    @EnvironmentObject private var library: CardLibraryStore

    @State private var query = ""

    var body: some View {
        let matches = library.cards(matching: query)
        return NavigationStack {
            List {
                if library.cards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No Card Snapshots").font(.headline)
                        Text("Analyze a card to create its first local snapshot.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if matches.isEmpty {
                    Text("No matching snapshots").foregroundStyle(.secondary)
                } else {
                    ForEach(matches) { card in
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
                    .onDelete { offsets in
                        library.remove(ids: Set(offsets.map { matches[$0].id }))
                    }
                }
                if let error = library.storageError {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Name, technology, subtype, or genome")
            .navigationTitle("Library")
        }
    }
}
