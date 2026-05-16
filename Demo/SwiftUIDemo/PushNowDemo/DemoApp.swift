//
//  DemoApp.swift
//  PushNowDemo
//
//  All it takes to bring PushNow in:
//
//    1. Instantiate `PushNow(UIApplication.shared)` once at launch
//       (here, in AppDelegate).
//    2. Call `pushnow.onRegister { ... }` when you want the device token.
//
//  The SDK handles APNs, UNUserNotificationCenter, and everything
//  else. No AppDelegate plumbing required.
//

import SwiftUI
import PushNow

@main
struct DemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var inbox = NotificationInbox()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inbox)
                .onAppear {
                    // AppDelegate already installed the PushNow instance;
                    // hook our inbox up so the SwiftUI view renders payloads.
                    AppDelegate.shared?.bindInbox(inbox)
                }
        }
    }
}
