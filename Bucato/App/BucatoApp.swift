import SwiftData
import SwiftUI

@main
struct BucatoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SavedGarment.self)
    }
}
