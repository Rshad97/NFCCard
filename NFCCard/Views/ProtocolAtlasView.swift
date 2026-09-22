import SwiftUI

struct ProtocolAtlasView: View {
    let card: NFCCardProfile

    private var report: ProtocolAtlasReport {
        ProtocolAtlasService.analyze(card)
    }

    var body: some View {
        List {
            Section("Identification") {
                LabeledContent("Family", value: report.family)
                LabeledContent("Variant", value: report.variant)
                LabeledContent("Confidence", value: "\(report.confidencePercent)%")

                ProgressView(value: report.confidence)
                    .accessibilityLabel("Identification confidence")
                    .accessibilityValue("\(report.confidencePercent) percent")
            }

            Section("Evidence Trail") {
                ForEach(report.evidence) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.source).font(.headline)
                            Spacer()
                            Text(String(format: "%.0f%% weight", item.weight * 100))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Text(item.observation)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Text(item.interpretation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }

            Section("Next Safe Probes") {
                ForEach(report.nextReadOnlyProbes, id: \.self) { probe in
                    Label(probe, systemImage: "magnifyingglass")
                }
            }

            Section("Limits") {
                ForEach(report.limitations, id: \.self) { limitation in
                    Text(limitation).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Protocol Atlas")
    }
}
