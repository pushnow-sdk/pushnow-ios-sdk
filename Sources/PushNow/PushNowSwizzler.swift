//
//  PushNowSwizzler.swift
//  PushNow
//
//  Runtime swizzling so the SDK can intercept APNs callbacks on the
//  host app's `UIApplicationDelegate` without the host having to wire
//  anything up.
//
//  We swizzle two selectors on the delegate class:
//
//    - application:didRegisterForRemoteNotificationsWithDeviceToken:
//    - application:didFailToRegisterForRemoteNotificationsWithError:
//
//  If the host already implements them, we invoke the original IMP
//  after our own handler runs. If they don't, we add our own
//  implementation and iOS treats the host as if it had always had one.
//
//  The UNUserNotificationCenter delegate is handled separately
//  (see `PushNow` class) via a chaining proxy — swizzling there gets
//  tangled with the many optional methods on the protocol.
//

import UIKit
import ObjectiveC.runtime

enum PushNowSwizzler {

    /// Called once from `PushNow.configure(...)`. Idempotent.
    static func installAPNsSwizzles() {
        guard let delegateClass = object_getClass(UIApplication.shared.delegate)
                ?? UIApplication.shared.delegate.map({ type(of: $0) }) else {
            // No app delegate assigned yet (host uses SwiftUI App without
            // @UIApplicationDelegateAdaptor). Defer until `register` is
            // called — UIApplication.shared.delegate is always non-nil
            // after the app has finished launching on real devices.
            return
        }
        installSuccess(on: delegateClass)
        installFailure(on: delegateClass)
    }

    // MARK: - didRegister...WithDeviceToken:

    private static var installedSuccess = false
    private static func installSuccess(on cls: AnyClass) {
        guard !installedSuccess else { return }
        installedSuccess = true
        let selector = #selector(
            UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
        )
        let swizzled: @convention(block) (AnyObject, UIApplication, Data) -> Void = { receiver, app, token in
            // Forward to the original IMP first if the host had one.
            if let original = Self.originalSuccessIMP {
                let typed = unsafeBitCast(
                    original,
                    to: (@convention(c) (AnyObject, Selector, UIApplication, Data) -> Void).self
                )
                typed(receiver, selector, app, token)
            }
            PushNow.shared?._didReceiveAPNsDeviceToken(token)
        }
        let block = imp_implementationWithBlock(swizzled)
        if let existing = class_getInstanceMethod(cls, selector) {
            originalSuccessIMP = method_getImplementation(existing)
            method_setImplementation(existing, block)
        } else {
            class_addMethod(cls, selector, block, "v@:@@")
        }
    }
    private static var originalSuccessIMP: IMP?

    // MARK: - didFailToRegister...WithError:

    private static var installedFailure = false
    private static func installFailure(on cls: AnyClass) {
        guard !installedFailure else { return }
        installedFailure = true
        let selector = #selector(
            UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)
        )
        let swizzled: @convention(block) (AnyObject, UIApplication, Error) -> Void = { receiver, app, error in
            if let original = Self.originalFailureIMP {
                let typed = unsafeBitCast(
                    original,
                    to: (@convention(c) (AnyObject, Selector, UIApplication, Error) -> Void).self
                )
                typed(receiver, selector, app, error)
            }
            PushNow.shared?._didFailAPNsRegistration(error)
        }
        let block = imp_implementationWithBlock(swizzled)
        if let existing = class_getInstanceMethod(cls, selector) {
            originalFailureIMP = method_getImplementation(existing)
            method_setImplementation(existing, block)
        } else {
            class_addMethod(cls, selector, block, "v@:@@")
        }
    }
    private static var originalFailureIMP: IMP?
}
