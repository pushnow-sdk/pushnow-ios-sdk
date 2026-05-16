//
//  NotificationInbox.swift
//  PushNowDemo
//
//  Tiny observable store for the last handful of received / tapped
//  notification payloads so the UI has something to show once a push
//  arrives. In a real app you'd route these into your own feature
//  modules; here we just keep the latest 20 entries.
//

import Foundation
import SwiftUI

@MainActor
final class NotificationInbox: ObservableObject {
    enum Kind: String {
        case received
        case tapped
    }

    struct Entry: Identifiable, Hashable {
        let id = UUID()
        let kind: Kind
        let timestamp: Date
        let snippet: String
    }

    @Published private(set) var entries: [Entry] = []

    func record(userInfo: [AnyHashable: Any], kind: Kind) {
        let snippet = Self.summarize(userInfo)
        let entry = Entry(kind: kind, timestamp: Date(), snippet: snippet)
        entries.insert(entry, at: 0)
        if entries.count > 20 { entries.removeLast(entries.count - 20) }
    }

    private static func summarize(_ userInfo: [AnyHashable: Any]) -> String {
        // Pull something useful out of the APS payload if present;
        // otherwise just render the whole thing compactly.
        if let aps = userInfo["aps"] as? [String: Any],
           let alert = aps["alert"] {
            if let s = alert as? String { return s }
            if let dict = alert as? [String: Any] {
                let title = dict["title"] as? String ?? ""
                let body = dict["body"] as? String ?? ""
                return [title, body].filter { !$0.isEmpty }.joined(separator: " — ")
            }
        }
        return String(describing: userInfo)
    }
}
