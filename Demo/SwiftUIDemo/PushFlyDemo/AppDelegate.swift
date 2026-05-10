//
//  AppDelegate.swift
//  PushFlyDemo (SwiftUI)
//
//  SwiftUI apps still get a UIApplicationDelegate when you use the
//  `@UIApplicationDelegateAdaptor` property wrapper, and that's the
//  cleanest place to instantiate PushFly — it runs before any scene
//  is connected, so the SDK is ready before the first view appears.
//

import UIKit
import PushFly

final class AppDelegate: NSObject, UIApplicationDelegate {

    static private(set) weak var shared: AppDelegate?

    private var pushfly: PushFly?
    private weak var inbox: NotificationInbox?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDelegate.shared = self

        let pushfly = PushFly(UIApplication.shared)
        self.pushfly = pushfly

        // Trigger the registration prompt right away. Your production
        // app can defer this to a later moment if you want to ask for
        // permission at a more contextual time.
        pushfly.onRegister { deviceToken, error in
            if let error {
                print("PushFly register failed:", error.localizedDescription)
                return
            }
            print("PushFly device token:", deviceToken)
        }

        // Forward payloads into the SwiftUI-observable inbox once
        // `bindInbox` is called.
        pushfly.onNotificationReceived { [weak self] data, ack in
            self?.inbox?.record(userInfo: data, kind: .received)
            ack(.newData)
        }
        pushfly.onNotificationOpened { [weak self] data in
            self?.inbox?.record(userInfo: data, kind: .tapped)
        }
        return true
    }

    func bindInbox(_ inbox: NotificationInbox) { self.inbox = inbox }
}
