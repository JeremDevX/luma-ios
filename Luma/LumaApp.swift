import SwiftUI

@main
struct LumaApp: App {
    @State private var store = LumaStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .tint(Color("accent"))
        }
    }
}
