import SwiftUI

@main
struct Snap_FighterApp: App {
    @StateObject private var deckStore = DeckStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deckStore)
        }
    }
}
