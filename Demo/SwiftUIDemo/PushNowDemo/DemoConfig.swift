//
//  DemoConfig.swift
//  PushNowDemo
//
//  The demo doesn't need any PushNow configuration — the SDK deals
//  with APNs on the device and hands you back a device token. You
//  forward that token to your own backend.
//
//  This file is kept as a placeholder for anything demo-specific you
//  want to tweak.
//

import Foundation

enum DemoConfig {
    /// The URL of YOUR backend endpoint that accepts the device token
    /// and stores it alongside your user record. Left blank in the
    /// demo; logging only.
    static let myBackendEndpoint: String? = nil
}
