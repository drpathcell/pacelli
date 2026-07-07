import SwiftUI

/// Root of the native app.
///
/// **Design invariant (Guideline 5.1.1(v), build 25 rejection):** guest mode
/// is a first-class path. "Continue as guest" must land on a fully usable
/// Home — anonymous auth, auto-provisioned household, zero setup walls.
/// Account creation is an optional upgrade (`linkWithCredential` semantics),
/// never a gate.
struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        switch appState.phase {
        case .welcome:
            WelcomeView(appState: appState)
                .task { await appState.restoreSession() }
        case .working(let label):
            ProgressView(label)
        case .home(let current):
            HomeView(current: current)
        }
    }
}

struct WelcomeView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Pacelli")
                .font(.largeTitle.bold())

            Text("A peaceful, organised home")
                .font(.title3)
                .foregroundStyle(.secondary)

            if let error = appState.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Guest-first: primary action requires no account.
            Button {
                Task { await appState.enterGuestMode() }
            } label: {
                Text("Continue as guest")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                // Phase 4 (next): SIWA / Google / email
            } label: {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(24)
    }
}

#Preview {
    RootView()
}
