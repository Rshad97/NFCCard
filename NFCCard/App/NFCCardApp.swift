import SwiftUI

@main
struct NFCCardApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scanner = NFCScanner(driver: CoreNFCReader())
    @StateObject private var library = CardLibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanner)
                .environmentObject(library)
                .task {
                    scanner.library = library
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-wallet") {
                        library.save(NFCCardProfile(
                            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                            name: "Wallet Test Card", technology: "ISO 7816",
                            uidHex: "01020304050607", genome: "ui-test-wallet-fixture"))
                    }
#endif
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background { scanner.enteredBackground() }
                }
        }
    }
}
