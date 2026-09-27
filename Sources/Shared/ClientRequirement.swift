import Foundation

/// Builds the code-signing requirement the privileged helper uses to decide which
/// XPC clients it will talk to (pure, unit-testable). The Security-framework
/// lookups that feed it live in the helper target.
///
/// The helper is a root LaunchDaemon and its Mach service lives in the global
/// bootstrap namespace, so *any* local process can open a connection to it.
/// Without a requirement, anything on the machine can call `setKeepAwake(true)`
/// and `heartbeat()` — which both flips `SleepDisabled` and defeats the helper's
/// own watchdog, bypassing the battery and thermal guards that live app-side.
public enum ClientRequirement {

    /// The app bundle id that owns a given helper label — the inverse of
    /// `LidlessHelper.label(appBundleID:)`.
    ///
    /// Returns nil when the label isn't a helper label, so a malformed
    /// environment fails closed rather than authorizing something unexpected.
    public static func appBundleID(fromHelperLabel label: String) -> String? {
        let suffix = ".helper"
        guard label.hasSuffix(suffix) else { return nil }
        let base = String(label.dropLast(suffix.count))
        return base.isEmpty ? nil : base
    }

    /// Requirement demanding an Apple-issued signature, the owning app's
    /// identifier, and the same team that signed the helper.
    ///
    /// The team id is read from the helper's own signature at runtime rather than
    /// hardcoded, so forks and Debug builds signed by a different team validate
    /// against themselves instead of against upstream's team.
    ///
    /// Returns nil if either component contains anything outside the character
    /// set Apple actually issues, rather than interpolating it into a requirement
    /// string where a quote would change the expression's meaning.
    public static func requirement(appBundleID: String, teamID: String) -> String? {
        guard isSafeIdentifier(appBundleID), isSafeIdentifier(teamID) else { return nil }
        return "anchor apple generic"
            + " and identifier \"\(appBundleID)\""
            + " and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    /// Bundle ids and team ids are alphanumerics, dots, and hyphens. Anything
    /// else — quotes, spaces, escapes — is rejected outright.
    static func isSafeIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
