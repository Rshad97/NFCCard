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
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background { scanner.enteredBackground() }
                }
        }
    }
}
