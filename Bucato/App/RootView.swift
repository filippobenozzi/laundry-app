import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Etichetta", systemImage: "text.viewfinder") }
            SymbolLibraryView()
                .tabItem { Label("Simboli", systemImage: "square.grid.2x2") }
            FiberLibraryView()
                .tabItem { Label("Fibre", systemImage: "list.bullet") }
        }
        .tint(Theme.ink)
    }
}
