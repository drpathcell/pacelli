import Foundation
import Testing

@testable import PacelliKit

/// `checklist_items.source` is written by the API only (functions/src/index.ts
/// `checklistItemsAdd`, validated shape in `types/models.ts`). The repository
/// decrypts it to a JSON string; these tests take that string exactly as the
/// API emits it and check the app reads it — and, more importantly, that a
/// bad one never costs the row.
@Suite("Checklist item source (retailer provenance)")
struct ChecklistItemSourceTests {

    /// Verbatim from a live `push_list_to_pacelli` on 2026-09-21 (trimmed).
    private let apiSourceJSON = """
    {"retailer":"dunnes","sku":"100287099","name":"Dunnes Stores Simply Better Authentic Greek Yogurt 450g",
     "price":2.49,"pricePerUnit":"€5.53/kg","observedAt":"2026-09-21T18:10:09Z",
     "imageUrl":"https://images.cdn.dunnesstoresgrocery.com/cell/100287099_1.jpg",
     "brand":"Dunnes Stores","serving":"450g · 3 servings",
     "info":[{"heading":"Ingredients","text":"Skimmed Greek MILK\\nLive Yogurt Cultures"},
             {"heading":"Allergy Advice","text":"Milk - Contains"}],
     "nutrition":[{"profile":"per 100g","entries":[
        {"name":"Energy","amount":262,"unit":"kJ","dailyPercent":3.12},
        {"name":"Protein","amount":10,"unit":"g","dailyPercent":20},
        {"name":"Salt","amount":0.22,"unit":"g","trace":false}]}]}
    """

    private func itemMap(source: Any) -> [String: Any] {
        [
            "id": "i-1", "checklist_id": "cl-1", "household_id": "hh-1",
            "title": "Greek yogurt", "quantity": "1", "is_checked": false,
            "created_by": "uid-1", "created_at": "2026-09-21T18:10:09.000Z",
            "source": source,
        ]
    }

    @Test("The API's source JSON decodes with price, sections and nutrition")
    func decodesApiShape() throws {
        let item = try #require(ChecklistItem(map: itemMap(source: apiSourceJSON)))
        let src = try #require(item.source)
        #expect(src.retailer == "dunnes")
        #expect(src.sku == "100287099")
        #expect(src.price == 2.49)
        #expect(src.priceText == "€2.49")
        #expect(src.retailerDisplayName == "Dunnes Stores")
        #expect(src.observedDate != nil)
        #expect(src.info?.count == 2)
        #expect(src.info?.first?.heading == "Ingredients")
        #expect(src.info?.first?.text.contains("MILK") == true)
        let profile = try #require(src.nutrition?.first)
        #expect(profile.profile == "per 100g")
        #expect(profile.entries.count == 3)
        #expect(profile.entries[1].name == "Protein" && profile.entries[1].amount == 10)
        #expect(profile.entries[0].dailyPercent == 3.12)
    }

    @Test("A source with only the required fields decodes")
    func minimalSource() throws {
        let item = try #require(ChecklistItem(map: itemMap(source: #"{"retailer":"dunnes","sku":"1"}"#)))
        let src = try #require(item.source)
        #expect(src.price == nil && src.info == nil && src.nutrition == nil)
        #expect(src.priceText == nil)
    }

    @Test("Garbage, empty, wrong-type or missing source never drops the row")
    func badSourceKeepsRow() throws {
        for bad: Any in ["not json", "", "{}", #"{"retailer":"","sku":"1"}"#, #"{"sku":"1"}"#, 42, NSNull(), ["a": 1]] {
            let item = try #require(ChecklistItem(map: itemMap(source: bad)),
                                    "row dropped for source \(bad)")
            #expect(item.source == nil, "source should be nil for \(bad)")
            #expect(item.title == "Greek yogurt")
        }
        var map = itemMap(source: apiSourceJSON)
        map.removeValue(forKey: "source")
        #expect(ChecklistItem(map: map)?.source == nil)
    }

    @Test("toMap() never writes source (the app is not a writer of it)")
    func toMapOmitsSource() throws {
        let item = try #require(ChecklistItem(map: itemMap(source: apiSourceJSON)))
        #expect(item.source != nil)
        #expect(item.toMap()["source"] == nil)
    }
}
