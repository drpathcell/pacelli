import Foundation

/// Where a checklist item came from, when an assistant built the list from a
/// retailer catalogue (the Dunnes scraper, 2026-09-21).
///
/// Stored on `checklist_items.source` as ONE encrypted JSON string, written only
/// by the API. The app never writes it: item edits use `updateData`, so the
/// field survives a title change or a tick. Everything here is optional beyond
/// `retailer` and `sku`, and a `source` that fails to decode is simply absent —
/// it must never cost the row itself.
///
/// It is deliberately on the item rather than in a shared catalogue collection:
/// the place you read it is a supermarket aisle with one bar of signal, and an
/// item's document is already in Firestore's offline cache by then.
public struct ChecklistItemSource: Codable, Equatable, Sendable {
    public struct Section: Codable, Equatable, Sendable {
        public var heading: String
        public var text: String
        public init(heading: String, text: String) { self.heading = heading; self.text = text }
    }

    public struct NutritionEntry: Codable, Equatable, Sendable {
        public var name: String
        public var amount: Double
        public var unit: String
        public var trace: Bool?
        public var dailyPercent: Double?
        public init(name: String, amount: Double, unit: String, trace: Bool? = nil, dailyPercent: Double? = nil) {
            self.name = name; self.amount = amount; self.unit = unit; self.trace = trace; self.dailyPercent = dailyPercent
        }
    }

    public struct NutritionProfile: Codable, Equatable, Sendable {
        public var profile: String
        public var entries: [NutritionEntry]
        public init(profile: String, entries: [NutritionEntry]) { self.profile = profile; self.entries = entries }
    }

    public var retailer: String
    public var sku: String
    public var name: String?
    public var price: Double?
    public var pricePerUnit: String?
    public var observedAt: String?
    public var imageUrl: String?
    public var brand: String?
    public var serving: String?
    public var info: [Section]?
    public var nutrition: [NutritionProfile]?

    public init(retailer: String, sku: String, name: String? = nil, price: Double? = nil,
                pricePerUnit: String? = nil, observedAt: String? = nil, imageUrl: String? = nil,
                brand: String? = nil, serving: String? = nil, info: [Section]? = nil,
                nutrition: [NutritionProfile]? = nil) {
        self.retailer = retailer; self.sku = sku; self.name = name; self.price = price
        self.pricePerUnit = pricePerUnit; self.observedAt = observedAt; self.imageUrl = imageUrl
        self.brand = brand; self.serving = serving; self.info = info; self.nutrition = nutrition
    }

    /// Decodes the decrypted JSON; nil for anything that is not a valid source.
    public static func decode(_ json: String?) -> ChecklistItemSource? {
        guard let json, let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ChecklistItemSource.self, from: data),
              !decoded.retailer.isEmpty, !decoded.sku.isEmpty
        else { return nil }
        return decoded
    }

    /// "Dunnes" for `dunnes`; other retailers as given, capitalised.
    public var retailerDisplayName: String {
        switch retailer.lowercased() {
        case "dunnes": return "Dunnes Stores"
        default: return retailer.prefix(1).uppercased() + retailer.dropFirst()
        }
    }

    /// "€1.95" in the retailer's currency (euro for every retailer we know).
    public var priceText: String? {
        guard let price else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "en_IE")
        return f.string(from: NSNumber(value: price))
    }

    public var observedDate: Date? {
        guard let observedAt else { return nil }
        return ISO8601DateFormatter().date(from: observedAt) ?? DartISO8601.date(from: observedAt)
    }
}
