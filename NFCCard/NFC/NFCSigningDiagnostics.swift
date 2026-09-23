import Foundation
import Darwin

struct NFCSigningDiagnostics {
    let report: String
    let missingTagEntitlement: Bool

    static func inspect() -> Self {
        // SecTask is a runtime diagnostic for the jailbreak build. Fail open if
        // the OS does not export it; an unreadable signature is not a rejection.
        guard let library = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY) else {
            return .init(report: "Runtime entitlements: unavailable", missingTagEntitlement: false)
        }
        defer { dlclose(library) }
        typealias CreateTask = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
        typealias CopyValue = @convention(c) (CFTypeRef, CFString, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFTypeRef>?
        guard let createSymbol = dlsym(library, "SecTaskCreateFromSelf"),
              let valueSymbol = dlsym(library, "SecTaskCopyValueForEntitlement") else {
            return .init(report: "Runtime entitlements: SecTask unavailable", missingTagEntitlement: false)
        }
        let create = unsafeBitCast(createSymbol, to: CreateTask.self)
        let copy = unsafeBitCast(valueSymbol, to: CopyValue.self)
        guard let task = create(nil)?.takeRetainedValue() else {
            return .init(report: "Runtime entitlements: task unavailable", missingTagEntitlement: false)
        }
        var error: Unmanaged<CFError>?
        let formats = copy(task, "com.apple.developer.nfc.readersession.formats" as CFString, &error)?.takeRetainedValue() as? [String]
        let readError = error?.takeRetainedValue()
        let platform = copy(task, "platform-application" as CFString, nil)?.takeRetainedValue() as? Bool
        let identifier = copy(task, "application-identifier" as CFString, nil)?.takeRetainedValue() as? String
        let formatText = formats.map { $0.joined(separator: ",") } ?? (readError == nil ? "missing" : "unreadable")
        return .init(report: "Runtime entitlements: formats=\(formatText); platform-application=\(platform == true); application-identifier=\(identifier ?? "not present"); bundle=\(Bundle.main.bundleIdentifier ?? "unknown")",
                     missingTagEntitlement: readError == nil && !(formats?.contains("TAG") ?? false))
    }
}
