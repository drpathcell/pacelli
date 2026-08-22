import PacelliKit
import SwiftUI
import UIKit

/// Every picture in the household, on one screen.
///
/// It lives inside Search rather than becoming a sixth tab, and that is not a
/// space-saving compromise — it is what the feature is. "Search by looking at
/// the pictures" and "search by typing" are the same act on the same set, so
/// they belong on the same screen: an empty query is the whole wall, and typing
/// narrows it.
struct PhotoGalleryView: View {
    let current: CurrentHousehold
    /// Shared with the Everything tab, so switching modes keeps your query.
    let query: String

    @State private var photos: [Photo] = []
    @State private var provenance: [String: PhotosRepository.Provenance] = [:]
    @State private var categories: [TaskCategory] = []
    @State private var categoryFilter: String?
    @State private var loading = true
    @State private var viewing: Photo?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    private var filtered: [Photo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return photos.filter { photo in
            if let categoryFilter, photo.categoryId != categoryFilter { return false }
            guard !q.isEmpty else { return true }
            if photo.searchableText.lowercased().contains(q) { return true }
            return provenance[photo.subjectId]?.title.lowercased().contains(q) ?? false
        }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if photos.isEmpty {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(
                        "Add one from a task or a shopping item. The original stays on your phone; everyone in the household can see it."
                    ))
            } else {
                ScrollView {
                    if !categories.isEmpty {
                        categoryChips
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filtered) { photo in
                                Button { viewing = photo } label: { cell(photo) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("gallery_cell")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $viewing) { photo in
            PhotoViewer(photo: photo, householdId: current.household.id) {
                Task {
                    try? await PhotoService.delete(
                        photoId: photo.id, householdId: current.household.id)
                    viewing = nil
                    await load()
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: String(localized: "All"), id: nil)
                ForEach(categories) { category in
                    chip(title: category.name, id: category.id)
                }
                // Photos the inference could not place. Named plainly so it
                // reads as a job to do rather than a fault.
                chip(title: String(localized: "Unfiled"), id: "")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func chip(title: String, id: String?) -> some View {
        let selected = categoryFilter == id
        return Button {
            categoryFilter = selected ? nil : id
        } label: {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func cell(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            PhotoThumbnail(photo: photo, size: 104)
                .frame(maxWidth: .infinity)
            let p = provenance[photo.subjectId]
            Text(p?.title ?? String(localized: "Deleted item"))
                .font(.caption)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(p?.kind ?? "—")
                if let name = categoryName(photo.categoryId) {
                    Text("·")
                    Text(name)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func categoryName(_ id: String?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }?.name
    }

    private func load() async {
        let householdId = current.household.id
        async let all = try? PhotosRepository.fetchAll(householdId: householdId)
        async let prov = PhotosRepository.provenance(householdId: householdId)
        async let cats = try? CategoriesRepository.fetchCategories(householdId: householdId)

        photos = await all ?? []
        provenance = await prov
        categories = await cats ?? []
        loading = false

        // Bring down the full size of what is on screen, so tapping is
        // instant. Best-effort and silent — a convenience, not a promise.
        let recent = photos
        Task.detached(priority: .background) {
            await PhotoService.prefetch(recent, householdId: householdId)
        }
    }
}
