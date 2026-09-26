import SwiftUI

@main
struct NFCCardApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scanner = NFCScanner(driver: Self.makeReader())
    @StateObject private var library = CardLibraryStore()

    private static func makeReader() -> NFCReaderDriving {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-ndef-unsupported") {
            return UnsupportedNDEFUITestReader()
        }
#endif
        return CoreNFCReader()
    }

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

#if DEBUG
/// Simulator-only fixture; absent from Release. Exercises the normal coordinator.
private final class UnsupportedNDEFUITestReader: NFCReaderDriving {
    func start(scanID: UUID, profile: NFCScanProfile, eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
        eventHandler(scanID, .failure(.init(kind: .unavailable, message: "Test reader", diagnostic: "Test reader")))
    }
    func startNDEF(scanID: UUID, profile: NFCScanProfile, request: NDEFRequest,
                   eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
        guard !request.isWrite else {
            eventHandler(scanID, .failure(.init(kind: .configuration, message: "Test must never write", diagnostic: "Unexpected write")))
            return
        }
        let card = NFCCardProfile(name: "NDEF Unsupported Test Card", technology: "ISO 7816",
                                   uidHex: "01020304050607", subtype: "TEST-AID", details: ["Initial AID": "TEST-AID"])
        var result = NDEFReadResult(identity: card.uidHex!, technology: card.technology,
                                    access: .unsupported, capacity: 0, records: nil, inspectedAt: .now)
        result.cardProfile = card
        eventHandler(scanID, .availability(true))
        eventHandler(scanID, .active)
        eventHandler(scanID, .ndefRead(result))
    }
    func stop(scanID: UUID, message: String?, completion: @escaping () -> Void) { completion() }
    func reset(scanID: UUID) {}
}
#endif
