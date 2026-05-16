//
//  AppDelegate.swift
//  PushNowDemo (SwiftUI)
//
//  SwiftUI apps still get a UIApplicationDelegate when you use the
//  `@UIApplicationDelegateAdaptor` property wrapper, and that's the
//  cleanest place to instantiate PushNow — it runs before any scene
//  is connected, so the SDK is ready before the first view appears.
//

import UIKit
import PushNow

final class AppDelegate: NSObject, UIApplicationDelegate {

    static private(set) weak var shared: AppDelegate?

    private var pushnow: PushNow?
    private weak var inbox: NotificationInbox?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppDelegate.shared = self

        let pushnow = PushNow(UIApplication.shared)
        self.pushnow = pushnow

        // Trigger the registration prompt right away. Your production
        // app can defer this to a later moment if you want to ask for
        // permission at a more contextual time.
        pushnow.onRegister { deviceToken, error in
            if let error {
                print("PushNow register failed:", error.localizedDescription)
                return
            }
            print("PushNow device token:", deviceToken)
        }

        // Forward payloads into the SwiftUI-observable inbox once
        // `bindInbox` is called.
        pushnow.onNotificationReceived { [weak self] data, ack in
            self?.inbox?.record(userInfo: data, kind: .received)
            ack(.newData)
        }
        pushnow.onNotificationOpened { [weak self] data in
            self?.inbox?.record(userInfo: data, kind: .tapped)
        }
        return true
    }

    func bindInbox(_ inbox: NotificationInbox) { self.inbox = inbox }
}
