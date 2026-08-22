import PacelliKit
import SwiftUI

/// Search tab: debounced client-side search across all decrypted content.
struct SearchView: View {
    let current: CurrentHousehold
    let appState: AppState

    @State private var query = ""
    @State private var results: [SearchService.Result] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var mode: Mode = .everything

    /// Two ways of finding the same household, on one screen. Photos are not a
    /// sixth tab: an empty query with Photos selected IS the gallery, and
    /// typing narrows it. Browsing the wall and searching the text are the
    /// same act.
    private enum Mode: String, CaseIterable, Identifiable {
        case everything, photos
        var id: String { rawValue }
        var label: String {
            switch self {
            case .everything: return String(localized: "Everything")
            case .photos: return String(localized: "Photos")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if mode == .photos {
                    PhotoGalleryView(current: current, query: query)
                } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView(
                        "Search your household",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Tasks, checklists, plans and the manual — everything is searched after decryption, on this device."))
                } else if searching {
                    ProgressView()
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.kind.systemImage)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                HStack(spacing: 6) {
                                    Text(result.kind.displayName)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(.tint.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.tint)
                                    if let subtitle = result.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.bar)
                .accessibilityIdentifier("search_mode")
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search everything")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    results = []
                    searching = false
                    return
                }
                searching = true
                let householdId = current.household.id
                searchTask = Task {
                    // Debounce fast typing.
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    let found =
                        (try? await SearchService.search(
                            query: trimmed, householdId: householdId)) ?? []
                    guard !Task.isCancelled else { return }
                    results = found
                    searching = false
                }
            }
        }
    }
}
