//
//  ViewController.swift
//  PushFlyDemo (UIKit)
//
//  A minimal screen. All the PushFly integration lives in
//  `AppDelegate.swift`. This screen just shows the current device
//  token and lets you copy it for pasting into your backend while
//  you're testing.
//

import UIKit
import PushFly

final class ViewController: UIViewController {

    private let tokenLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "PushFly Demo"

        let header = UILabel()
        header.text = "APNs device token"
        header.textColor = .secondaryLabel
        header.font = .preferredFont(forTextStyle: .subheadline)
        header.translatesAutoresizingMaskIntoConstraints = false

        tokenLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tokenLabel.textColor = .label
        tokenLabel.numberOfLines = 0
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy", for: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        let footer = UILabel()
        footer.text = "Send this token to your backend. Your backend forwards it to PushFly when sending a notification."
        footer.textColor = .secondaryLabel
        footer.font = .preferredFont(forTextStyle: .footnote)
        footer.numberOfLines = 0
        footer.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [header, tokenLabel, copyButton, footer])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])

        refreshToken()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshToken()
    }

    private func refreshToken() {
        if let token = PushFly.shared?.deviceToken(), !token.isEmpty {
            tokenLabel.text = token
        } else {
            tokenLabel.text = "Waiting for APNs — register runs in AppDelegate."
            tokenLabel.textColor = .tertiaryLabel
        }
    }

    @objc private func copyTapped() {
        guard let token = PushFly.shared?.deviceToken(), !token.isEmpty else { return }
        UIPasteboard.general.string = token
        let alert = UIAlertController(title: "Copied", message: "Device token copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
