import SwiftUI

struct CapabilityMapView: View {
    let card: NFCCardProfile

    var body: some View {
        List(card.capabilities) { capability in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: capability.available ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(capability.available ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.title).font(.headline)
                    Text(capability.detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
        .navigationTitle("Capability Map")
    }
}
