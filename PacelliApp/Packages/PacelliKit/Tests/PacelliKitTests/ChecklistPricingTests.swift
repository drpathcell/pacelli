import Foundation
import Testing

@testable import PacelliKit

@Suite("Checklist pricing (line and list totals)")
struct ChecklistPricingTests {

    private func item(_ id: String, price: Double?, qty: String?, checked: Bool = false,
                      observedAt: String = "2026-09-22T19:00:00Z") -> ChecklistItem {
        ChecklistItem(
            id: id, checklistId: "cl", title: "t\(id)", quantity: qty, isChecked: checked,
            source: price.map { ChecklistItemSource(retailer: "dunnes", sku: "1\(id)", price: $0, observedAt: observedAt) })
    }

    @Test("quantity strings become multipliers, defaulting to one")
    func multiplier() {
        #expect(ChecklistPricing.multiplier(nil) == 1)
        #expect(ChecklistPricing.multiplier("") == 1)
        #expect(ChecklistPricing.multiplier("  ") == 1)
        #expect(ChecklistPricing.multiplier("some") == 1)
        #expect(ChecklistPricing.multiplier("0") == 1)
        #expect(ChecklistPricing.multiplier("4") == 4)
        #expect(ChecklistPricing.multiplier(" 2 x") == 2)
        #expect(ChecklistPricing.multiplier("1.5") == 1.5)
        #expect(ChecklistPricing.multiplier("1,5 kg") == 1.5)
        #expect(ChecklistPricing.multiplier("3.") == 3)
        #expect(ChecklistPricing.multiplier("2.5.1") == 2.5)
    }

    @Test("line total is price × quantity in cents; unpriced rows have none")
    func lines() {
        #expect(ChecklistPricing.lineCents(item("a", price: 0.89, qty: "4")) == 356)
        #expect(ChecklistPricing.lineCents(item("b", price: 3.1, qty: nil)) == 310)
        #expect(ChecklistPricing.lineCents(item("c", price: nil, qty: "2")) == nil)
        #expect(ChecklistPricing.lineCents(item("d", price: -1, qty: "2")) == nil)
    }

    @Test("summary sums in cents, splits ticked, counts unpriced rows")
    func summary() {
        // 0.1 + 0.2 summed as Double is 0.30000000000000004; cents must not care.
        let items = [
            item("1", price: 0.1, qty: "1"),
            item("2", price: 0.2, qty: "1", checked: true, observedAt: "2026-09-20T10:00:00Z"),
            item("3", price: 0.89, qty: "4"),
            item("4", price: nil, qty: "2"),
            item("5", price: nil, qty: nil),
        ]
        let s = ChecklistPricing.summary(items)
        #expect(s.totalCents == 10 + 20 + 356)
        #expect(s.checkedCents == 20)
        #expect(s.remainingCents == 366)
        #expect(s.pricedCount == 3)
        #expect(s.unpricedCount == 2)
        #expect(s.oldestObservedAt == ISO8601DateFormatter().date(from: "2026-09-20T10:00:00Z"))
    }

    @Test("euro formatting")
    func euros() {
        #expect(ChecklistPricing.euros(8910) == "€89.10")
        #expect(ChecklistPricing.euros(5) == "€0.05")
    }
}
