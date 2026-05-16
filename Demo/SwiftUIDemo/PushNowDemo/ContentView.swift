//
//  ContentView.swift
//  PushNowDemo
//
//  Tap "Register" to obtain a device token. Send that token to your
//  own backend; your backend hands it to PushNow when posting a
//  notification.
//

import SwiftUI
import PushNow

struct ContentView: View {
    @EnvironmentObject private var inbox: NotificationInbox
    @StateObject private var model = DemoViewModel()

    var body: some View {
        NavigationStack {
            Form {
                deviceSection
                inboxSection
            }
            .navigationTitle("PushNow Demo")
            .onAppear { model.refresh() }
            .alert(item: $model.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Sections

    private var deviceSection: some View {
        Section {
            LabeledContent("Device token") {
                Text(model.deviceToken ?? "—")
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            LabeledContent("Registered") {
                Text(model.isRegistered ? "Yes" : "No")
                    .foregroundStyle(model.isRegistered ? .green : .secondary)
            }
            Button(action: model.register) {
                HStack {
                    Text("Register")
                    Spacer()
                    if model.isRegistering { ProgressView() }
                }
            }
            .disabled(model.isRegistering)
        } header: {
            Text("Device")
        } footer: {
            Text("Send this device token to your own backend. Your backend forwards it to PushNow when sending a notification.")
        }
    }

    private var inboxSection: some View {
        Section("Inbox (\(inbox.entries.count))") {
            if inbox.entries.isEmpty {
                Text("No notifications yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(inbox.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.kind.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(entry.kind == .tapped ? .blue : .green)
                            Spacer()
                            Text(entry.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.snippet)
                            .font(.footnote)
                    }
                }
            }
        }
    }
}

// MARK: - View model

@MainActor
final class DemoViewModel: ObservableObject {
    struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published private(set) var deviceToken: String?
    @Published private(set) var isRegistered: Bool = false
    @Published private(set) var isRegistering: Bool = false
    @Published var alert: AlertContent?

    func refresh() {
        deviceToken = PushNow.shared?.deviceToken()
        isRegistered = PushNow.shared?.isRegistered() ?? false
    }

    func register() {
        isRegistering = true
        PushNow.shared?.onRegister { [weak self] token, error in
            guard let self else { return }
            self.isRegistering = false
            if let error {
                self.alert = AlertContent(
                    title: "Registration failed",
                    message: error.localizedDescription
                )
                return
            }
            self.deviceToken = token
            self.isRegistered = true
            self.alert = AlertContent(
                title: "Registered",
                message: "Device token: \(token.prefix(16))…\n\nSend this to your backend."
            )
        }
    }
}
