//
//  AppDelegate.swift
//  PushFlyDemo (UIKit)
//
//  A complete PushFly integration in one file. Mirrors the Pushy-style
//  call site you see in other push SDKs — instantiate, toggle options,
//  call register, attach notification handlers.
//

import UIKit
import PushFly

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Install the root UI (programmatic, no storyboard).
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController())
        window?.makeKeyAndVisible()

        // Initialize PushFly SDK. The backend identifies your app by
        // its bundle ID, so no API key needs to live in the binary.
        let pushfly = PushFly(UIApplication.shared)

        // Register the device for push notifications
        // 4eeeac1658c995bdc6009cbfb844da0de263f5dcab659937d26219aab36152a9
        pushfly.onRegister { deviceToken, error in
            // Handle registration errors
            if let error {
                return print("Registration failed: \(error.localizedDescription)")
            }

            // Print device token to console
            print("PushFly device token: \(deviceToken)")

            // Persist the device token locally and send it to your backend later
            UserDefaults.standard.set(deviceToken, forKey: "pushflyToken")
        }

        // Handle incoming notifications
        pushfly.onNotificationReceived { [weak self] msg, ack in
            // Print notification payload
            print("Received notification: \(msg)")

            // Show an alert dialog
            let alert = UIAlertController(
                title: "Incoming Notification",
                message: msg["message"] as? String,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self?.window?.rootViewController?.present(alert, animated: true)

            // Reset iOS badge number (and clear all app notifications)
            UIApplication.shared.applicationIconBadgeNumber = 0

            // Call `ack` when you finish processing (including any
            // asynchronous operations, if applicable).
            ack(.newData)
        }

        // Handle notification tap event
        pushfly.onNotificationOpened { [weak self] msg in
            // Show an alert dialog
            let alert = UIAlertController(
                title: "Notification Tapped",
                message: msg["message"] as? String,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self?.window?.rootViewController?.present(alert, animated: true)

            // Navigate the user to another page or
            // execute other logic on notification tap
        }

        return true
    }
}
