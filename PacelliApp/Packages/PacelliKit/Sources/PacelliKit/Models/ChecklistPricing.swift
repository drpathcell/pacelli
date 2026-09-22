import Foundation

/// Line totals and the list total for checklist rows that carry a retailer
/// price (`ChecklistItem.source.price`, written by the API at push time).
///
/// Money is summed in whole cents so a 39-row list cannot drift by a cent
/// from Double rounding. A row with no price (a free-text line, or a product
/// the retailer does not sell) contributes nothing and is counted, so the UI
/// can say how much of the list the total covers.
///
/// The price is the one observed when the item was added. It is an estimate:
/// the till is the truth, and the receipt (1.12.0) is what corrects it.
public enum ChecklistPricing {

    /// The multiplier a quantity string stands for. `nil`, blank or a string
    /// with no leading number ("some") count as 1: a row on the list is at
    /// least one of the thing. "2", "2 x", "1.5", "1,5 kg" read their number.
    /// Zero or negative is 1 as well; a row nobody wants is deleted, not zeroed.
    public static func multiplier(_ quantity: String?) -> Double {
        guard let q = quantity?.trimmingCharacters(in: .whitespaces), !q.isEmpty else { return 1 }
        var digits = ""
        var seenSeparator = false
        for ch in q {
            if ch.isASCII, ch.isNumber {
                digits.append(ch)
            } else if (ch == "." || ch == ","), !seenSeparator, !digits.isEmpty {
                digits.append("."); seenSeparator = true
            } else {
                break
            }
        }
        if digits.hasSuffix(".") { digits.removeLast() }
        guard let value = Double(digits), value > 0 else { return 1 }
        return value
    }

    /// Unit price in cents, or nil when the row has no usable price.
    public static func unitCents(_ item: ChecklistItem) -> Int? {
        guard let price = item.source?.price, price.isFinite, price >= 0 else { return nil }
        return Int((price * 100).rounded())
    }

    /// Unit price × quantity, in cents; nil when the row has no price.
    public static func lineCents(_ item: ChecklistItem) -> Int? {
        guard let unit = unitCents(item) else { return nil }
        return Int((Double(unit) * multiplier(item.quantity)).rounded())
    }

    public struct Summary: Equatable, Sendable {
        /// Every priced row, ticked or not.
        public var totalCents: Int
        /// Priced rows already ticked (in the trolley).
        public var checkedCents: Int
        public var pricedCount: Int
        public var unpricedCount: Int
        /// The oldest price date among priced rows: "prices as of".
        public var oldestObservedAt: Date?

        public var remainingCents: Int { totalCents - checkedCents }
    }

    public static func summary(_ items: [ChecklistItem]) -> Summary {
        var s = Summary(totalCents: 0, checkedCents: 0, pricedCount: 0, unpricedCount: 0, oldestObservedAt: nil)
        for item in items {
            guard let line = lineCents(item) else { s.unpricedCount += 1; continue }
            s.pricedCount += 1
            s.totalCents += line
            if item.isChecked { s.checkedCents += line }
            if let d = item.source?.observedDate, d < (s.oldestObservedAt ?? .distantFuture) {
                s.oldestObservedAt = d
            }
        }
        return s
    }

    /// "€3.56" (euro, Irish formatting; every retailer we read prices in EUR).
    public static func euros(_ cents: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "en_IE")
        return f.string(from: NSNumber(value: Double(cents) / 100)) ?? "€\(cents / 100).\(String(format: "%02d", cents % 100))"
    }
}
