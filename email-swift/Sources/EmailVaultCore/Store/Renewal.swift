import Foundation

/// How a subscription repeats; stored in `accounts.renew_cycle`.
public enum RenewalCycle: String, CaseIterable, Sendable {
    case once
    case monthly
    case yearly
}

/// Renewal reminder attached to an account. `dueDate` is a local calendar day (`yyyy-MM-dd`).
public struct Renewal: Equatable, Sendable {
    public static let defaultLeadDays = 7

    public var dueDate: String
    public var cycle: RenewalCycle
    public var amount: String
    public var leadDays: Int

    public init(dueDate: String, cycle: RenewalCycle = .once, amount: String = "", leadDays: Int = Renewal.defaultLeadDays) {
        self.dueDate = dueDate
        self.cycle = cycle
        self.amount = amount
        self.leadDays = max(0, leadDays)
    }

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func format(_ date: Date) -> String {
        formatter.string(from: date)
    }

    public static func parse(_ text: String) -> Date? {
        formatter.date(from: text)
    }

    /// Calendar days from `today` to the due date; negative when overdue. nil if the date is malformed.
    public func daysUntilDue(today: Date = Date()) -> Int? {
        guard let due = Renewal.parse(dueDate) else { return nil }
        let cal = Renewal.calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: today), to: cal.startOfDay(for: due)).day
    }

    /// True when within the reminder window or overdue.
    public func isDue(today: Date = Date()) -> Bool {
        guard let days = daysUntilDue(today: today) else { return false }
        return days <= leadDays
    }

    /// Reminder after paying: due date moved forward one cycle; nil for one-off renewals.
    public func renewed() -> Renewal? {
        let component: Calendar.Component
        switch cycle {
        case .once: return nil
        case .monthly: component = .month
        case .yearly: component = .year
        }
        guard
            let due = Renewal.parse(dueDate),
            let next = Renewal.calendar.date(byAdding: component, value: 1, to: due)
        else { return nil }
        var copy = self
        copy.dueDate = Renewal.format(next)
        return copy
    }
}
