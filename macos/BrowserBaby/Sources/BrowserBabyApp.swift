import SwiftUI

@main
struct BrowserBabyApp: App {
    @StateObject private var store = BrowserStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1320, height: 840)
    }
}
