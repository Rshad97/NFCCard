import Foundation

enum NFCErrorDiagnostics {
    /// Preserve nested XPC/permission errors without dumping arbitrary userInfo
    /// values, which can include card content. Bound recursion for cyclic errors.
    static func describe(_ error: NSError, depth: Int = 0) -> String {
        var result = "\(error.domain) (\(error.code)): \(error.localizedDescription)"
        if let reason = error.localizedFailureReason { result += "; reason=\(reason)" }
        if depth < 3, let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            result += "; underlying=" + describe(underlying, depth: depth + 1)
        }
        return result
    }
}
