import SwiftUI

/// Usable Home — the tab shell a guest lands on with zero walls.
/// Feature tabs arrive as Phase 5 modules land: Tasks → Checklists → …
struct HomeView: View {
    let current: CurrentHousehold
    let appState: AppState

    var body: some View {
        TabView {
            Tab("Tasks", systemImage: "checkmark.circle") {
                TasksView(current: current, appState: appState)
            }
            Tab("Checklists", systemImage: "list.bullet.rectangle") {
                ChecklistsView(current: current, appState: appState)
            }
            Tab("Plans", systemImage: "calendar") {
                PlansView(current: current, appState: appState)
            }
        }
    }
}
