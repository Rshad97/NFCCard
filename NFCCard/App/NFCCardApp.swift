import SwiftUI

@main
struct NFCCardApp: App {
    @StateObject private var scanner = NFCScanner()
    @StateObject private var library = CardLibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanner)
                .environmentObject(library)
                .task {
                    scanner.library = library
                }
        }
    }
}
