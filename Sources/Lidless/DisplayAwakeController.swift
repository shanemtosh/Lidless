import Foundation
import IOKit.pwr_mgt

/// Process-owned protection: macOS releases it even if Lidless crashes.
/// This prevents idle display sleep, without changing password or lock settings.
final class DisplayAwakeController {
    private(set) var assertionID: IOPMAssertionID?

    @discardableResult
    func setActive(_ active: Bool) -> IOReturn {
        if !active {
            guard let id = assertionID else { return kIOReturnSuccess }
            let result = IOPMAssertionRelease(id)
            if result == kIOReturnSuccess { assertionID = nil }
            return result
        }
        guard assertionID == nil else { return kIOReturnSuccess }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lidless: keep display awake for computer use" as CFString,
            &id
        )
        if result == kIOReturnSuccess { assertionID = id }
        return result
    }

    deinit {
        if let id = assertionID { IOPMAssertionRelease(id) }
    }
}
