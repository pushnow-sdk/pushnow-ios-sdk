//
//  DemoApp.swift
//  PushFlyDemo
//
//  All it takes to bring PushFly in:
//
//    1. Call PushFly.configure() once at launch.
//    2. Call PushFly.shared.onRegister { token in ... } when you want
//       the device token.
//
//  The SDK handles APNs, UNUserNotificationCenter, and everything
//  else. No AppDelegate plumbing required.
//

import SwiftUI
import PushFly

@main
struct DemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var inbox = NotificationInbox()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inbox)
                .onAppear {
                    // AppDelegate already installed the PushFly instance;
                    // hook our inbox up so the SwiftUI view renders payloads.
                    AppDelegate.shared?.bindInbox(inbox)
                }
        }
    }
}
