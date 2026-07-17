# Token Pulse for iOS

Native SwiftUI companion for a Token Pulse mobile relay. It supports a user-configurable server URL, stores the dashboard access key in the iOS Keychain, refreshes on launch/foreground and pull-to-refresh, and never stores the desktop write credential.

## Build handoff

1. On macOS, install Xcode and XcodeGen.
2. Run `xcodegen generate` in this directory.
3. Open `TokenPulse.xcodeproj`, select the Apple Developer team, and set the final bundle identifier.
4. Test on an iPhone with a self-hosted or managed Token Pulse server.
5. Archive and upload using Xcode Organizer.

This project was prepared on Windows and must not be considered App Store-ready until it compiles and passes device QA in Xcode.
