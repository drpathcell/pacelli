import FirebaseCore
import SwiftUI

@main
struct PacelliApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
