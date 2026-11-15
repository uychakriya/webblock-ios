import SwiftUI

@main
struct WebBlockApp: App {
    @State private var appState = AppState()

    init() {
        // Blue large titles like the page headers in the Figma design.
        let brand = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x6E9BEA) : UIColor(hex: 0x4379D6) }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: brand]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = [.foregroundColor: brand]
        scrolled.largeTitleTextAttributes = [.foregroundColor: brand]
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.wbBrand)
        }
    }
}
