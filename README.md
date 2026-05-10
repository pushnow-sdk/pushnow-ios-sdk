# PushFly iOS SDK

The official iOS companion SDK for the
[PushFly](https://pushfly.example.com) push notification service.
The SDK handles APNs registration internally and hands you back a
device token. **You** pass that token to your backend; your backend
passes it to PushFly when it wants to send a notification.

- iOS 13.0+
- Swift 5.9 / Xcode 15
- Swift Package Manager and CocoaPods supported
- Works from Swift and Objective-C
- Zero AppDelegate plumbing required

## Install

### Swift Package Manager

In Xcode → File → Add Packages…

```
https://github.com/pushfly/pushfly-sdk-ios.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushfly/pushfly-sdk-ios.git", from: "0.1.0")
]
```

### CocoaPods

```ruby
pod 'PushFly', '~> 0.1'
```

## Quick start

### 1. Enable push in Xcode

- **Signing & Capabilities** → add **Push Notifications**
- **Signing & Capabilities** → add **Background Modes → Remote notifications**

### 2. Register the device

```swift
import PushFly

// Once, in AppDelegate.application(_:didFinishLaunchingWithOptions:)
// (or the @UIApplicationDelegateAdaptor for SwiftUI apps).
let pushfly = PushFly(UIApplication.shared)

pushfly.onRegister { deviceToken, error in
    if let error {
        return print("Registration failed: \(error.localizedDescription)")
    }
    // Send this token to YOUR backend.
    // Your backend then hands it to PushFly when sending pushes.
    myApi.saveDeviceToken(deviceToken)
}
```

Or with Swift Concurrency:

```swift
let token = try await pushfly.onRegister()
```

That's the whole SDK surface you need for registration. PushFly
swizzles the two APNs callbacks on your `UIApplicationDelegate`
under the hood — you don't wire up anything yourself.

### 3. Handle incoming notifications

```swift
pushfly.onNotificationReceived { data, ack in
    print("received:", data)
    ack(.newData)
}

pushfly.onNotificationOpened { data in
    print("tapped:", data)
}

// Optional: show banners for notifications received in the foreground.
pushfly.toggleInAppBanner(true)
```

PushFly installs itself as the `UNUserNotificationCenter` delegate
and chains to any existing delegate you already had, so this
works alongside other SDKs that hook into notifications.

## How the device token flows

```
 iOS device                                 Your backend                 PushFly
 ─────────                                  ────────────                 ───────
 PushFly.onRegister { token in
     POST /users/me/push-token  ────────►   store(token)
 }
                                            POST /v1/notifications  ───►  deliver
                                            { target: { deviceToken }}
```

The SDK never talks to PushFly directly. Credentials stay on your
backend.

## Objective-C

```objc
PushFly *pushfly = [[PushFly alloc] init:UIApplication.sharedApplication];

[pushfly onRegister:^(NSString *deviceToken, NSError *err) {
    if (err) { NSLog(@"register failed: %@", err); return; }
    NSLog(@"token: %@", deviceToken);
}];
```

## Error handling

Errors come back as `PushFlyError` with a stable `code`:

| code                       | when                                                        |
|----------------------------|-------------------------------------------------------------|
| `push_permission_denied`   | User declined the prompt or disabled notifications          |
| `apns_registration_failed` | APNs returned an error (no certificate, etc.)               |
| `timed_out`                | APNs never called back (usually: no network, wrong entitlement) |
| `not_configured`           | Used internally; shouldn't reach callers                    |
| `already_in_flight`        | Another `onRegister` call is still running                  |

## What gets stored on device

One string, in the keychain:

| Key                    | Contents                                        |
|------------------------|-------------------------------------------------|
| `_pushflyDeviceToken`  | Hex APNs device token from the last register   |

## Demo app

See `Demo/README.md` — a three-file SwiftUI app that shows the full
flow end-to-end.

## License

Apache-2.0.
