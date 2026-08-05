import Foundation

// Entry point for the privileged helper (a LaunchDaemon running as root).
// It listens on a Mach service and serves LidlessHelperProtocol over XPC. The
// Mach service name is handed in by the LaunchDaemon plist (per build config), so
// the same binary serves both the Release and the `.dev` daemons.
let machLabel = ProcessInfo.processInfo.environment[LidlessHelper.machLabelEnvKey] ?? LidlessHelper.fallbackLabel
// The label also names the owning app, which is half of the client code-signing
// requirement the delegate enforces on every incoming connection.
let delegate = HelperListenerDelegate(machLabel: machLabel)
let listener = NSXPCListener(machServiceName: machLabel)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
