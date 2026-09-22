import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Scan", systemImage: "wave.3.right") }

            CardLibraryView()
                .tabItem { Label("Library", systemImage: "rectangle.stack") }

            LabView()
                .tabItem { Label("Lab", systemImage: "scope") }

            WalletHubView()
                .tabItem { Label("Wallet", systemImage: "wallet.pass") }
        }
    }
}
