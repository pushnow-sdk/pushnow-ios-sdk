//
//  PushFly.swift
//  PushFly
//
//  Public entry point. End-to-end shape:
//
//      let pushfly = PushFly(UIApplication.shared)
//      pushfly.onRegister { deviceToken, error in ... }
//      pushfly.onNotificationReceived { data, ack in ... }
//      pushfly.onNotificationOpened { data in ... }
//
//  What the SDK does under the hood:
//
//    1. Swizzles the host `UIApplicationDelegate`'s two APNs
//       callbacks so the host doesn't forward anything manually.
//    2. Installs a chaining `UNUserNotificationCenterDelegate` proxy
//       so delivery + tap events route through PushFly while any
//       existing host delegate keeps working.
//    3. Requests APNs authorization when `onRegister` is called.
//    4. Exchanges the long APNs token for a short `deviceToken` via
//       the backend endpoints in `docs/BACKEND_API.md`. The app only
//       ever sees the short token.
//    5. On cold launch with a cached `(deviceToken, auth)`, validates
//       them with the backend before claiming the app is registered.
//       Re-registers on validation miss.
//    6. Detects APNs token rotation (Apple issuing a fresh token for
//       the same install) and refreshes the server-side mapping via
//       `/v1/sdk/refresh-apns-token`; the short `deviceToken` stays
//       stable so the customer's backend needs no update.
//
//  Tenant identification: the backend keys applications off the app's
//  `CFBundleIdentifier`, sent in every SDK request. No API key is
//  shipped in the app binary.
//

import Foundation
import UIKit
import UserNotifications

public final class PushFly: NSObject {

    // MARK: - Shared

    @objc public private(set) static var shared: PushFly?

    /// SDK version, for log correlation.
    @objc public static var sdkVersion: String { PushFlyConfig.sdkVersion }

    // MARK: - Dependencies

    private let storage: PushFlyStorage
    private let notificationCenter: UNUserNotificationCenter
    private let application: UIApplication
    private let http: PushFlyHTTPClient

    // MARK: - State

    private let stateQueue = DispatchQueue(label: "me.pushfly.sdk.state")
    private var _registerCompletion: ((String, Error?) -> Void)?
    private var _notificationHandler: (([AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void)?
    private var _notificationClickListener: (([AnyHashable: Any]) -> Void)?
    private var _notificationOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    private var _delegateProxy: PushFlyUNDelegateProxy?
    private var _registerTimeoutTimer: DispatchSourceTimer?
    private var _inAppBannerEnabled: Bool = false

    /// Max time to wait for APNs to call back after
    /// `registerForRemoteNotifications()`. Surfaced for tests.
    var apnsCallbackTimeout: TimeInterval = 30

    // MARK: - Init

    /// Initialize the SDK.
    ///
    /// Call once, typically from
    /// `AppDelegate.application(_:didFinishLaunchingWithOptions:)`:
    /// ```swift
    /// let pushfly = PushFly(UIApplication.shared)
    /// ```
    ///
    /// The backend identifies your application by the app's
    /// `CFBundleIdentifier`, so no API key is required on device.
    @objc public convenience init(_ application: UIApplication) {
        self.init(application, apiBaseUrl: PushFlyConfig.defaultApiBaseUrl)
    }

    /// Initializer with an overridable API origin, for self-hosted /
    /// preview deployments.
    @objc public convenience init(_ application: UIApplication, apiBaseUrl: String) {
        self.init(
            application: application,
            storage: DefaultPushFlyStorage(),
            transport: URLSession.shared,
            installSwizzles: true,
            apiBaseUrl: apiBaseUrl
        )
        validateCachedCredentialsInBackground()
    }

    /// Dependency-injection initializer. Test-only; not exposed to Obj-C
    /// because `PushFlyHTTPTransport` isn't representable there.
    init(
        application: UIApplication,
        storage: PushFlyStorage,
        transport: PushFlyHTTPTransport,
        notificationCenter: UNUserNotificationCenter = .current(),
        installSwizzles: Bool = false,
        apiBaseUrl: String = PushFlyConfig.defaultApiBaseUrl
    ) {
        self.application = application
        self.storage = storage
        self.notificationCenter = notificationCenter
        self.http = PushFlyHTTPClient(transport: transport, baseUrl: apiBaseUrl)
        super.init()
        if PushFly.shared == nil { PushFly.shared = self }
        if installSwizzles { install() }
    }

    private func install() {
        PushFlySwizzler.installAPNsSwizzles()
        let proxy = PushFlyUNDelegateProxy(pushFly: self, original: notificationCenter.delegate)
        _delegateProxy = proxy
        notificationCenter.delegate = proxy
    }

    // MARK: - Toggles

    /// Show an in-app banner when a notification arrives while the
    /// app is in the foreground. Defaults to `false`.
    @objc public func toggleInAppBanner(_ value: Bool) {
        stateQueue.sync { _inAppBannerEnabled = value }
    }

    /// Customise `UNAuthorizationOptions` requested during `register`.
    /// Defaults to `[.alert, .badge, .sound]`.
    @objc public func setNotificationOptions(_ options: UNAuthorizationOptions) {
        stateQueue.sync { _notificationOptions = options }
    }

    // MARK: - Register

    /// Register for push notifications.
    ///
    /// Prompts for permission if needed, asks APNs for a device
    /// token, exchanges it for a short PushFly `deviceToken` via the
    /// backend, and returns that token via `handler` on the main
    /// thread.
    ///
    /// Send the returned token to **your own backend**; your backend
    /// passes it to PushFly when submitting a notification.
    public func onRegister(_ handler: @escaping (_ deviceToken: String, _ error: Error?) -> Void) {
        let alreadyInFlight: Bool = stateQueue.sync {
            if _registerCompletion != nil { return true }
            _registerCompletion = handler
            return false
        }
        if alreadyInFlight {
            deliverOnMain { handler("", PushFlyError(
                code: .alreadyInFlight,
                message: "A register(...) call is already in flight."
            )) }
            return
        }

        notificationCenter.requestAuthorization(options: currentNotificationOptions()) { [weak self] granted, error in
            guard let self = self else { return }
            if let error = error {
                self.completeRegister(token: "", error: PushFlyError(
                    code: .pushPermissionDenied,
                    message: "Authorization failed: \(error.localizedDescription)",
                    underlying: error
                ))
                return
            }
            if !granted {
                self.completeRegister(token: "", error: PushFlyError(
                    code: .pushPermissionDenied,
                    message: "Please enable push notifications for this app in iOS Settings."
                ))
                return
            }
            DispatchQueue.main.async {
                PushFlySwizzler.installAPNsSwizzles()
                self.application.registerForRemoteNotifications()
                self.armAPNsTimeout()
            }
        }
    }

    // MARK: - Unregister

    /// Delete the registration server-side and clear local state.
    /// Safe to call if the device was never registered — completes
    /// with `(nil)` in that case.
    public func unregister(_ handler: @escaping (_ error: Error?) -> Void) {
        guard let deviceToken = storage.string(forKey: PushFlyStorageKeys.deviceToken),
              let auth = storage.string(forKey: PushFlyStorageKeys.auth) else {
            clearLocalCredentials()
            deliverOnMain { handler(nil) }
            return
        }
        guard let bundleId = Bundle.main.bundleIdentifier else {
            deliverOnMain { handler(PushFlyError(
                code: .missingBundleId,
                message: "Please configure a Bundle ID for your app to use PushFly."
            )) }
            return
        }
        let body = UnregisterRequest(deviceToken: deviceToken, auth: auth, bundleId: bundleId)
        http.sendVoid(method: "POST", path: "/unregister", body: body) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.clearLocalCredentials()
                self.deliverOnMain { handler(nil) }
            case .failure(let e)
                where e.httpStatus == 404
                   || e.httpStatus == 401
                   || e.code == .deviceNotFound
                   || e.code == .invalidCredentials:
                // Already gone on the server, or our auth is stale
                // enough the server won't honour it. Either way the
                // local state is worse than useless — clear it so
                // the next onRegister starts clean.
                self.clearLocalCredentials()
                self.deliverOnMain { handler(nil) }
            case .failure(let e):
                self.deliverOnMain { handler(e) }
            }
        }
    }

    // MARK: - Notifications

    public func onNotificationReceived(
        _ handler: @escaping (_ data: [AnyHashable: Any], _ ack: @escaping (UIBackgroundFetchResult) -> Void) -> Void
    ) {
        stateQueue.sync { _notificationHandler = handler }
    }

    public func onNotificationOpened(
        _ handler: @escaping (_ data: [AnyHashable: Any]) -> Void
    ) {
        stateQueue.sync { _notificationClickListener = handler }
    }

    // MARK: - Introspection

    /// The short PushFly device token from the last successful
    /// registration, or `nil`.
    @objc public func deviceToken() -> String? {
        storage.string(forKey: PushFlyStorageKeys.deviceToken)
    }

    @MainActor
    @objc public func isRegistered() -> Bool {
        application.isRegisteredForRemoteNotifications && deviceToken() != nil
    }

    // MARK: - APNs callbacks (invoked from the swizzler)

    func _didReceiveAPNsDeviceToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        let previousApns = storage.string(forKey: PushFlyStorageKeys.apnsToken)

        // Three cases to disambiguate:
        //   1. There's a pending `onRegister` call — always go through
        //      the full /register backend flow so the caller's
        //      completion fires.
        //   2. We already have a (deviceToken, auth) pair AND the APNs
        //      hex is unchanged — nothing to do.
        //   3. We have a pair but APNs rotated — call
        //      /refresh-apns-token so the server-side mapping updates
        //      without minting a new deviceToken.
        let hasPending = stateQueue.sync { _registerCompletion != nil }
        if hasPending {
            performBackendRegister(apnsHex: hex)
            return
        }
        if let deviceToken = storage.string(forKey: PushFlyStorageKeys.deviceToken),
           let auth = storage.string(forKey: PushFlyStorageKeys.auth) {
            if previousApns == hex {
                return // no change, nothing to do
            }
            performRefresh(deviceToken: deviceToken, auth: auth, apnsHex: hex)
            return
        }
        // No cached credentials and no pending onRegister — APNs fired
        // without an explicit onRegister call. Cache the hex so the
        // next onRegister can use it without waiting for another
        // rotation.
        storage.setString(hex, forKey: PushFlyStorageKeys.apnsToken)
    }

    func _didFailAPNsRegistration(_ error: Error) {
        completeRegister(token: "", error: PushFlyError(
            code: .apnsRegistrationFailed,
            message: "APNs failed to register: \(error.localizedDescription)",
            underlying: error
        ))
    }

    // MARK: - Delegate-proxy callbacks

    /// Invoked by `PushFlyUNDelegateProxy` from
    /// `userNotificationCenter(_:willPresent:)`. Returns the
    /// presentation options to use when no host delegate owns it.
    func _handleForegroundNotification(
        userInfo: [AnyHashable: Any],
        suggestedOptions: UNNotificationPresentationOptions
    ) -> UNNotificationPresentationOptions {
        _handleRemoteNotification(userInfo: userInfo) { _ in }
        let banner = stateQueue.sync { _inAppBannerEnabled }
        return banner ? suggestedOptions : []
    }

    func _handleRemoteNotification(
        userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let handler = stateQueue.sync { _notificationHandler }
        if let handler {
            handler(userInfo, completionHandler)
        } else {
            completionHandler(.noData)
        }
    }

    func _handleNotificationTap(userInfo: [AnyHashable: Any]) {
        let listener = stateQueue.sync { _notificationClickListener }
        listener?(userInfo)
    }

    // MARK: - Backend wiring

    private func performBackendRegister(apnsHex: String) {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
            completeRegister(token: "", error: PushFlyError(
                code: .missingBundleId,
                message: "Please configure a Bundle ID for your app to use PushFly."
            ))
            return
        }
        let body = RegisterRequest(
            platform: "ios",
            apnsToken: apnsHex,
            apnsEnvironment: PushFlyEnvironment.current(),
            bundleId: bundleId,
            deviceModel: PushFlyDevice.modelIdentifier(),
            systemVersion: PushFlyDevice.systemVersion()
        )
        http.send(
            method: "POST",
            path: "/register",
            body: body,
            responseType: RegisterResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                
                self.storage.setString(apnsHex, forKey: PushFlyStorageKeys.apnsToken)
                self.storage.setString(response.deviceToken, forKey: PushFlyStorageKeys.deviceToken)
                self.storage.setString(response.auth, forKey: PushFlyStorageKeys.auth)
                self.completeRegister(token: response.deviceToken, error: nil)
            case .failure(let error):
                
                self.completeRegister(token: "", error: error)
            }
        }
    }

    private func performRefresh(deviceToken: String, auth: String, apnsHex: String) {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let body = RefreshRequest(
            deviceToken: deviceToken,
            auth: auth,
            apnsToken: apnsHex,
            apnsEnvironment: PushFlyEnvironment.current(),
            bundleId: bundleId
        )
        http.sendVoid(method: "POST", path: "/refresh-apns-token", body: body) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.storage.setString(apnsHex, forKey: PushFlyStorageKeys.apnsToken)
            case .failure(let error)
                where error.httpStatus == 401
                   || error.httpStatus == 404
                   || error.code == .invalidCredentials
                   || error.code == .deviceNotFound:
                // Server says our cached pair is stale (rotated auth)
                // or gone entirely. Only recovery is a fresh
                // /register with the current APNs token — drop local
                // credentials so the next onRegister mints new ones.
                self.clearLocalCredentials()
            case .failure:
                // Transient (rate limit, 5xx). Leave state alone; the
                // next APNs rotation or cold launch will retry.
                break
            }
        }
    }

    private func validateCachedCredentialsInBackground() {
        guard let deviceToken = storage.string(forKey: PushFlyStorageKeys.deviceToken),
              let auth = storage.string(forKey: PushFlyStorageKeys.auth),
              let bundleId = Bundle.main.bundleIdentifier else {
            return
        }
        let body = ValidateRequest(deviceToken: deviceToken, auth: auth, bundleId: bundleId)
        http.send(
            method: "POST",
            path: "/validate",
            body: body,
            responseType: ValidateResponse.self
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response) where response.valid == false:
                self.clearLocalCredentials()
            case .success:
                break
            case .failure:
                // Network / rate-limit / 5xx — backend spec says
                // assume valid:true and proceed with the cached
                // pair. The worst case is one stale delivery
                // attempt, which fails cleanly server-side.
                break
            }
        }
    }

    // MARK: - Internals

    private func currentNotificationOptions() -> UNAuthorizationOptions {
        stateQueue.sync { _notificationOptions }
    }

    private func completeRegister(token: String, error: Error?) {
        let handler = stateQueue.sync { () -> ((String, Error?) -> Void)? in
            let h = _registerCompletion
            _registerCompletion = nil
            return h
        }
        cancelAPNsTimeout()
        guard let handler else { return }
        deliverOnMain { handler(token, error) }
    }

    private func clearLocalCredentials() {
        storage.setString(nil, forKey: PushFlyStorageKeys.deviceToken)
        storage.setString(nil, forKey: PushFlyStorageKeys.auth)
        storage.setString(nil, forKey: PushFlyStorageKeys.apnsToken)
    }

    private func armAPNsTimeout() {
        cancelAPNsTimeout()
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + apnsCallbackTimeout)
        timer.setEventHandler { [weak self] in
            self?.completeRegister(token: "", error: PushFlyError(
                code: .timedOut,
                message: "APNs did not return a device token within \(Int(self?.apnsCallbackTimeout ?? 0))s."
            ))
        }
        _registerTimeoutTimer = timer
        timer.resume()
    }

    private func cancelAPNsTimeout() {
        _registerTimeoutTimer?.cancel()
        _registerTimeoutTimer = nil
    }

    private func deliverOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
