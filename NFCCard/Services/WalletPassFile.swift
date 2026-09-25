import Foundation

enum WalletPassFile {
    static let maximumBytes = 10 * 1024 * 1024

    enum ImportError: LocalizedError {
        case wrongType, tooLarge, empty, notAFile

        var errorDescription: String? {
            switch self {
            case .wrongType: return "Select a signed .pkpass file. An exported JSON source cannot be added to Wallet until it is signed."
            case .tooLarge: return "The pass exceeds the 10 MB import limit."
            case .empty: return "The selected pass is empty."
            case .notAFile: return "Select a local Wallet pass file, not a folder."
            }
        }
    }

    static func validateFileName(_ url: URL) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "pkpass" else {
            throw ImportError.wrongType
        }
    }

    static func validateByteCount(_ count: Int) throws {
        guard count > 0 else { throw ImportError.empty }
        guard count <= maximumBytes else { throw ImportError.tooLarge }
    }

    /// Bounded off-main-thread read, including security-scoped Files/iCloud URLs.
    static func load(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try validateFileName(url)
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard resource.isRegularFile == true else { throw ImportError.notAFile }
            if let size = resource.fileSize { try validateByteCount(size) }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            // Never allocate based on an untrusted file's claimed size.
            let data = try file.read(upToCount: maximumBytes + 1) ?? Data()
            try validateByteCount(data.count)
            return data
        }.value
    }
}
