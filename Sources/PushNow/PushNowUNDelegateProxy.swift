//
//  PushNowUNDelegateProxy.swift
//  PushNow
//
//  Chaining `UNUserNotificationCenterDelegate` that hooks PushNow into
//  notification delivery without clobbering any delegate the host app
//  already installed. Every method forwards to the original delegate
//  before (or after) running PushNow's logic, so existing integrations
//  keep working unchanged.
//

import Foundation
import UIKit
import UserNotifications

final class PushNowUNDelegateProxy: NSObject, UNUserNotificationCenterDelegate {
    private weak var pushNow: PushNow?
    private weak var original: (any UNUserNotificationCenterDelegate)?

    init(pushNow: PushNow, original: (any UNUserNotificationCenterDelegate)?) {
        self.pushNow = pushNow
        self.original = original
    }

    // MARK: - Foreground presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // If the host had its own delegate, let it drive the response
        // and just observe the payload from the sidelines.
        if let original, original.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            pushNow?._handleRemoteNotification(userInfo: userInfo) { _ in }
            original.userNotificationCenter?(
                center,
                willPresent: notification,
                withCompletionHandler: completionHandler
            )
            return
        }

        // No host delegate: PushNow owns the presentation decision.
        // Fire the notification handler and then honour the in-app
        // banner toggle.
        let fallback: UNNotificationPresentationOptions
        if #available(iOS 14.0, *) {
            fallback = [.banner, .sound, .list]
        } else {
            fallback = [.alert, .sound]
        }
        let options = pushNow?._handleForegroundNotification(userInfo: userInfo, suggestedOptions: fallback) ?? []
        completionHandler(options)
    }

    // MARK: - Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        pushNow?._handleNotificationTap(userInfo: userInfo)

        if let original, original.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            original.userNotificationCenter?(
                center,
                didReceive: response,
                withCompletionHandler: completionHandler
            )
            return
        }
        completionHandler()
    }

    // MARK: - Pass-through for anything else

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return original?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let original, original.responds(to: aSelector) { return original }
        return nil
    }
}
