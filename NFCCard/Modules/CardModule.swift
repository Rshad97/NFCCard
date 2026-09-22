import Foundation

struct CardModuleDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let family: String
    let summary: String
}

protocol CardModule {
    var descriptor: CardModuleDescriptor { get }
    func matches(_ card: NFCCardProfile) -> Bool
}
