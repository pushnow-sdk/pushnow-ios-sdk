//
//  PushFlyDevice.swift
//  PushFly
//
//  Small helpers that extract device metadata the backend wants on
//  /register requests. Kept separate from the main class so we can
//  swap implementations in tests and keep `PushFly.swift` focused on
//  orchestration.
//

import Foundation
import UIKit

enum PushFlyDevice {
    /// Hardware model identifier (`"iPhone15,3"`, `"iPad13,1"`, etc.)
    ///
    /// Pulled from `uname()` because `UIDevice.current.model` only
    /// returns the generic family ("iPhone"), which isn't useful to
    /// the PushFly dashboard. The backend spec explicitly asks for
    /// the machine identifier.
    ///
    /// On the simulator we fall back to the `SIMULATOR_MODEL_IDENTIFIER`
    /// environment variable Apple populates (e.g.
    /// `"iPhone16,2"` on an iPhone 15 Pro Max simulator).
    static func modelIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !sim.isEmpty {
            return sim
        }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) { ptr -> String in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { cstr in
                String(cString: cstr)
            }
        }
        return machine
    }

    /// The running OS version (`"17.4.1"`). Thin wrapper kept here so
    /// the call site in `PushFly.swift` stays symmetrical with
    /// `modelIdentifier()`.
    static func systemVersion() -> String {
        UIDevice.current.systemVersion
    }
}
