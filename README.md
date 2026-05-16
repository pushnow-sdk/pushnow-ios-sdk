# PushNow iOS SDK

The official iOS companion SDK for the
[PushNow](https://pushnow.example.com) push notification service.
The SDK handles APNs registration internally and hands you back a
device token. **You** pass that token to your backend; your backend
passes it to PushNow when it wants to send a notification.

- iOS 13.0+
- Swift 5.9 / Xcode 15
- Swift Package Manager and CocoaPods supported
- Works from Swift and Objective-C
- Zero AppDelegate plumbing required

## Install

### Swift Package Manager

In Xcode → File → Add Packages…

```
https://github.com/pushnow/pushnow-sdk-ios.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushnow/pushnow-sdk-ios.git", from: "0.1.0")
]
```

### CocoaPods

```ruby
pod 'PushNow', '~> 0.1'
```

## Quick start

### 1. Enable push in Xcode

- **Signing & Capabilities** → add **Push Notifications**
- **Signing & Capabilities** → add **Background Modes → Remote notifications**

### 2. Register the device

```swift
import PushNow

// Once, in AppDelegate.application(_:didFinishLaunchingWithOptions:)
// (or the @UIApplicationDelegateAdaptor for SwiftUI apps).
let pushnow = PushNow(UIApplication.shared)

pushnow.onRegister { deviceToken, error in
    if let error {
        return print("Registration failed: \(error.localizedDescription)")
    }
    // Send this token to YOUR backend.
    // Your backend then hands it to PushNow when sending pushes.
    myApi.saveDeviceToken(deviceToken)
}
```

Or with Swift Concurrency:

```swift
let token = try await pushnow.onRegister()
```

That's the whole SDK surface you need for registration. PushNow
swizzles the two APNs callbacks on your `UIApplicationDelegate`
under the hood — you don't wire up anything yourself.

### 3. Handle incoming notifications

```swift
pushnow.onNotificationReceived { data, ack in
    print("received:", data)
    ack(.newData)
}

pushnow.onNotificationOpened { data in
    print("tapped:", data)
}

// Optional: show banners for notifications received in the foreground.
pushnow.toggleInAppBanner(true)
```

PushNow installs itself as the `UNUserNotificationCenter` delegate
and chains to any existing delegate you already had, so this
works alongside other SDKs that hook into notifications.

## How the device token flows

```
 iOS device                                 Your backend                 PushNow
 ─────────                                  ────────────                 ───────
 PushNow.onRegister { token in
     POST /users/me/push-token  ────────►   store(token)
 }
                                            POST /v1/notifications  ───►  deliver
                                            { target: { deviceToken }}
```

The SDK registers the device with PushNow’s HTTP API (identified by
your app’s bundle ID). Your backend keeps the secrets used to send
notifications; it passes the short device token when targeting a device.

## Objective-C

```objc
PushNow *pushnow = [[PushNow alloc] init:UIApplication.sharedApplication];

[pushnow onRegister:^(NSString *deviceToken, NSError *err) {
    if (err) { NSLog(@"register failed: %@", err); return; }
    NSLog(@"token: %@", deviceToken);
}];
```

## Error handling

Errors come back as `PushNowError` with a stable `code`:

| code                       | when                                                        |
|----------------------------|-------------------------------------------------------------|
| `push_permission_denied`   | User declined the prompt or disabled notifications          |
| `apns_registration_failed` | APNs returned an error (no certificate, etc.)               |
| `timed_out`                | APNs never called back (usually: no network, wrong entitlement) |
| `not_configured`           | Used internally; shouldn't reach callers                    |
| `already_in_flight`        | Another `onRegister` call is still running                  |

## What gets stored on device

Three values, keychain-backed (mirrored to `UserDefaults` for reads):

| Key                   | Contents                                              |
|-----------------------|-------------------------------------------------------|
| `_pushnowApnsToken`   | Hex APNs token from Apple                             |
| `_pushnowDeviceToken` | Short device ID returned by PushNow after register   |
| `_pushnowAuth`        | Per-device secret for refresh / validate / unregister |

## Demo app

See `Demo/README.md` — a three-file SwiftUI app that shows the full
flow end-to-end.

## License

Apache-2.0.
