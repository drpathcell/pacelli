import PacelliKit
import SwiftUI

/// What you get when you tap the picture on a shopping-list row: the product
/// large enough to match against the shelf, and the label information the
/// assistant carried over from the retailer's catalogue (price when it was
/// added, ingredients with allergens in capitals, storage, nutrition).
///
/// Everything shown is on the item document already, so it reads fine on the
/// one bar of signal a supermarket aisle offers. The only network here is the
/// full-size picture, and the thumbnail stands in until it arrives.
struct ChecklistItemDetailView: View {
    let item: ChecklistItem
    let photo: Photo?
    let householdId: String

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var loadingImage = false

    private var source: ChecklistItemSource? { item.source }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    picture
                    header
                    if let source {
                        priceCard(source)
                        if let info = source.info, !info.isEmpty {
                            ForEach(Array(info.enumerated()), id: \.offset) { _, section in
                                labelSection(section)
                            }
                        }
                        if let nutrition = source.nutrition, !nutrition.isEmpty {
                            ForEach(Array(nutrition.enumerated()), id: \.offset) { _, profile in
                                nutritionTable(profile)
                            }
                        }
                        Text("\(source.retailerDisplayName) product \(source.sku). Information as published by the retailer when the item was added; always check the label.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    } else if photo == nil {
                        Text("No picture or product information on this item yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("item_detail_done")
                }
            }
        }
        .task { await loadFullImage() }
    }

    // MARK: pieces

    @ViewBuilder private var picture: some View {
        if let image = fullImage ?? photo?.thumbnail.flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 320)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if loadingImage && fullImage == nil {
                        ProgressView().padding(8)
                    }
                }
                .accessibilityIdentifier(fullImage == nil ? "item_detail_thumb" : "item_detail_full_image")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.title2.weight(.semibold))
            HStack(spacing: 8) {
                if let brand = source?.brand, !brand.isEmpty { Text(brand) }
                if let serving = source?.serving, !serving.isEmpty { Text(serving) }
                if let qty = item.quantity, !qty.isEmpty { Text("Qty \(qty)") }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func priceCard(_ source: ChecklistItemSource) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let price = source.priceText {
                    Text(price).font(.title.weight(.bold))
                        .accessibilityIdentifier("item_detail_price")
                }
                if let unit = source.pricePerUnit, !unit.isEmpty {
                    Text(unit).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(source.retailerDisplayName).font(.subheadline.weight(.medium))
                if let date = source.observedDate {
                    Text("price on \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func labelSection(_ section: ChecklistItemSource.Section) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.heading).font(.headline)
            Text(section.text)
                .font(.body)
                .foregroundStyle(section.heading.localizedCaseInsensitiveContains("allergy") ? .primary : .secondary)
                .textSelection(.enabled)
        }
    }

    private func nutritionTable(_ profile: ChecklistItemSource.NutritionProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nutrition \(profile.profile)").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(Array(profile.entries.enumerated()), id: \.offset) { _, e in
                    GridRow {
                        Text(e.name).foregroundStyle(.secondary)
                        Text(e.trace == true ? "trace" : amountText(e))
                            .gridColumnAlignment(.trailing)
                            .monospacedDigit()
                        if let pct = e.dailyPercent {
                            Text("\(Self.clampedInt(pct))%")
                                .foregroundStyle(.tertiary)
                                .gridColumnAlignment(.trailing)
                                .monospacedDigit()
                        } else {
                            Text("")
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("item_detail_nutrition")
    }

    /// `Int(_:)` traps on NaN, infinity and anything outside Int's range.
    /// `source` is a member-written encrypted field, so a hostile or merely
    /// broken value must never take the app down (AUDIT_2026-09-23).
    static func clampedInt(_ v: Double) -> Int {
        guard v.isFinite else { return 0 }
        return Int(min(max(v.rounded(), -1e9), 1e9))
    }

    private func amountText(_ e: ChecklistItemSource.NutritionEntry) -> String {
        let amount = e.amount == e.amount.rounded() && abs(e.amount) < 1e9 ? String(Self.clampedInt(e.amount)) : String(format: "%.1f", e.amount)
        return "\(amount) \(e.unit)".trimmingCharacters(in: .whitespaces)
    }

    private func loadFullImage() async {
        guard let photo, photo.uploadState == .ready else { return }
        loadingImage = true
        defer { loadingImage = false }
        if let data = try? await PhotoService.fullImage(photoId: photo.id, householdId: householdId),
           let image = UIImage(data: data) {
            fullImage = image
        }
    }
}
