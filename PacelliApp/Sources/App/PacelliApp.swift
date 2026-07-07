import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct PacelliApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
