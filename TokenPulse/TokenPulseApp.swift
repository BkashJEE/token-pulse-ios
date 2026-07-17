import SwiftUI

@main
struct TokenPulseApp: App {
    @State private var store = PulseStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
