import SwiftUI
import PassKit
import UniformTypeIdentifiers

/// Imports an issuer-signed pass without storing certificates, uploading card
/// data, or bypassing PassKit's validation and user-confirmation screen.
struct WalletPassImportView: View {
    @State private var choosingFile = false
    @State private var loading = false
    @State private var pass: PKPass?
    @State private var presentation: WalletPassPresentation?
    @State private var error: String?
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        Button {
            error = nil
            choosingFile = true
        } label: {
            Label("Import Signed Wallet Pass", systemImage: "square.and.arrow.down")
        }
        .disabled(loading)
        .accessibilityIdentifier("wallet.import")
        .fileImporter(isPresented: $choosingFile,
                      allowedContentTypes: [UTType(filenameExtension: "pkpass") ?? UTType(importedAs: "com.apple.pkpass")]) { result in
            switch result {
            case .success(let url): importPass(url)
            case .failure(let failure):
                if (failure as NSError).code != NSUserCancelledError {
                    error = "Could not open the selected file. Try choosing it again in Files."
                }
            }
        }

        if loading { ProgressView("Validating pass…") }
        if let pass {
            Text("Ready for Wallet review: \(pass.localizedName)")
                .font(.subheadline)
            WalletAddPassButton {
                guard PKAddPassesViewController.canAddPasses(),
                      let controller = PKAddPassesViewController(pass: pass) else {
                    error = "Apple Wallet cannot add this pass on this device."
                    return
                }
                presentation = WalletPassPresentation(controller: controller)
            }
            .frame(height: 48)
            .accessibilityIdentifier("wallet.add-pass")
            .accessibilityLabel("Add to Apple Wallet")
        }
        if let error {
            Text(error).foregroundStyle(.red)
                .accessibilityIdentifier("wallet.import-error")
        }
        Text("Choose a signed .pkpass from Files. Apple Wallet reviews the pass before you approve adding it. Importing a pass does not link it to a scanned card or add NFC emulation.")
            .font(.footnote).foregroundStyle(.secondary)
            .sheet(item: $presentation) { item in
                WalletPassSheet(controller: item.controller) { presentation = nil }
            }
            .onDisappear {
                importTask?.cancel()
                importTask = nil
                loading = false
            }
    }

    private func importPass(_ url: URL) {
        importTask?.cancel()
        pass = nil
        error = nil
        guard PKAddPassesViewController.canAddPasses() else {
            error = "Adding passes to Apple Wallet is not available on this device."
            return
        }
        loading = true
        importTask = Task { @MainActor in
            do {
                let data = try await WalletPassFile.load(url)
                guard !Task.isCancelled else { return }
                // PKPass rejects malformed or untrusted packages; never bypass it.
                pass = try PKPass(data: data)
            } catch {
                guard !Task.isCancelled else { return }
                if let validation = error as? WalletPassFile.ImportError {
                    self.error = validation.localizedDescription
                } else {
                    self.error = "Could not validate this Wallet pass. It must be a complete .pkpass signed with a valid Apple Pass Type ID certificate. An unsigned JSON source or an NFC snapshot is not a Wallet pass."
                }
            }
            loading = false
        }
    }
}

private struct WalletPassPresentation: Identifiable {
    let id = UUID()
    let controller: PKAddPassesViewController
}

private struct WalletPassSheet: UIViewControllerRepresentable {
    let controller: PKAddPassesViewController
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: PKAddPassesViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            // Completion also fires for cancellation; do not report "added".
            onFinish()
        }
    }
}

private struct WalletAddPassButton: UIViewRepresentable {
    let action: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .blackOutline)
        button.addTarget(context.coordinator, action: #selector(Coordinator.add), for: .touchUpInside)
        return button
    }
    func updateUIView(_ button: PKAddPassButton, context: Context) { context.coordinator.action = action }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func add() { action() }
    }
}
