# PushNow Demos

Two reference integrations of the PushNow iOS SDK:

| Folder        | Stack              | Best for                                    |
|---------------|--------------------|---------------------------------------------|
| `UIKitDemo`   | UIKit + AppDelegate| Classic UIKit apps                          |
| `SwiftUIDemo` | SwiftUI + App protocol | Modern SwiftUI apps, including @UIApplicationDelegateAdaptor |

Both use the same SDK surface; the only real difference is where you
instantiate `PushNow(UIApplication.shared)`.

## Running a demo

1. Open `UIKitDemo/PushNowDemo.xcodeproj` or
   `SwiftUIDemo/PushNowDemo.xcodeproj` in Xcode 15+.
2. Pick a real iOS device as the run destination — the simulator
   doesn't actually register with APNs, so `register` will time out.
3. In **Signing & Capabilities**, pick your development team. The
   project already has **Push Notifications** and **Background Modes →
   Remote notifications** enabled.
4. Build and run.

Each demo references the PushNow SDK as a **local Swift package**
(relative path `../..` to the repo root). In a real integration
you'd point at a remote URL instead.

## UIKit integration in one file

This is the entire integration for a UIKit app, copied straight out of
`UIKitDemo/PushNowDemo/AppDelegate.swift`:

```swift
import UIKit
import PushNow

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let pushnow = PushNow(UIApplication.shared)
        pushnow.toggleInAppBanner(true)

        pushnow.onRegister { deviceToken, error in
            if let error {
                return print("Registration failed: \(error.localizedDescription)")
            }
            print("PushNow device token: \(deviceToken)")
            UserDefaults.standard.set(deviceToken, forKey: "pushnowToken")
        }

        pushnow.onNotificationReceived { data, ack in
            print("Received: \(data)")
            ack(.newData)
        }

        pushnow.onNotificationOpened { data in
            print("Tapped: \(data)")
        }
        return true
    }
}
```

## SwiftUI integration

SwiftUI apps use `@UIApplicationDelegateAdaptor` to get an
`AppDelegate` so the SDK can be instantiated at the canonical moment:

```swift
@main
struct DemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}
```

See `SwiftUIDemo/PushNowDemo/AppDelegate.swift` for the full
integration.
