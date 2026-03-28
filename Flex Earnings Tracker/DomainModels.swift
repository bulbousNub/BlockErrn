import SwiftUI
import Foundation
import SwiftData
import CoreLocation

public enum ExpenseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case drinks
    case gas
    case snacks
    case parkingTolls

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .drinks: return "Drinks"
        case .gas: return "Gas"
        case .snacks: return "Snacks"
        case .parkingTolls: return "Parking/Tolls"
        }
    }

    public var excludedFromTotals: Bool {
        switch self {
        case .gas: return true
        default: return false
        }
    }
}

public struct ExpenseCategoryDescriptor: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String

    public static var defaultList: [ExpenseCategoryDescriptor] {
        ExpenseCategory.allCases.map { descriptor(for: $0) }
    }

    public static func descriptor(for category: ExpenseCategory) -> ExpenseCategoryDescriptor {
        ExpenseCategoryDescriptor(id: category.rawValue, name: category.displayName)
    }

    public static func custom(name: String) -> ExpenseCategoryDescriptor {
        ExpenseCategoryDescriptor(id: "custom.\(UUID().uuidString)", name: name)
    }
}

public enum AuditAction: String, Codable, CaseIterable {
    case created
    case updated
    case deleted
    case statusChanged
    case tipsUpdated
    case expenseAdded
    case expenseRemoved
    case milesUpdated
}

public struct RoutePoint: Codable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date

    public init(latitude: Double, longitude: Double, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }

    public init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public enum BlockStatus: String, Codable, CaseIterable, Identifiable {
    case accepted
    case completed
    case cancelled
    case noShow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .accepted: return "Accepted"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No-Show"
        }
    }
}

@Model
public final class Expense {
    @Attribute(.unique) public var id: UUID
    public var categoryRaw: String
    public var amount: Decimal
    public var note: String?
    public var createdAt: Date
    public var block: Block?

    public init(id: UUID = UUID(), category: ExpenseCategory, amount: Decimal, note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
    }

    public init(id: UUID = UUID(), categoryRaw: String, amount: Decimal, note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.categoryRaw = categoryRaw
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
    }

    public var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .drinks }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
public final class AuditEntry {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var actionRaw: String
    public var field: String?
    public var oldValue: String?
    public var newValue: String?
    public var note: String?
    public var block: Block?

    public init(id: UUID = UUID(), timestamp: Date = Date(), action: AuditAction, field: String? = nil, oldValue: String? = nil, newValue: String? = nil, note: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.actionRaw = action.rawValue
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.note = note
    }

    public var action: AuditAction {
        get { AuditAction(rawValue: actionRaw) ?? .updated }
        set { actionRaw = newValue.rawValue }
    }
}

@Model
public final class Block {
    @Attribute(.unique) public var id: UUID

    public var date: Date
    public var durationMinutes: Int

    public var grossBase: Decimal
    public var hasTips: Bool
    public var tipsAmount: Decimal?

    public var miles: Decimal
    public var irsRateSnapshot: Decimal
    public var startTime: Date?
    public var endTime: Date?
    public var routePointsData: Data?
    public var userStartTime: Date?
    public var userCompletionTime: Date?

    public var statusRaw: String

    @Relationship(deleteRule: .cascade, inverse: \Expense.block) public var expenses: [Expense]
    @Relationship(deleteRule: .cascade, inverse: \AuditEntry.block) public var auditEntries: [AuditEntry]

    public var notes: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationMinutes: Int,
        grossBase: Decimal,
        hasTips: Bool = false,
        tipsAmount: Decimal? = nil,
        miles: Decimal = 0,
        irsRateSnapshot: Decimal,
        status: BlockStatus = .accepted,
        expenses: [Expense] = [],
        auditEntries: [AuditEntry] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        routePointsData: Data? = nil,
        userStartTime: Date? = nil,
        userCompletionTime: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.grossBase = grossBase
        self.hasTips = hasTips
        self.tipsAmount = tipsAmount
        self.miles = miles
        self.irsRateSnapshot = irsRateSnapshot
        self.statusRaw = status.rawValue
        self.expenses = expenses
        self.auditEntries = auditEntries
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startTime = startTime
        self.endTime = endTime
        self.routePointsData = routePointsData
        self.userStartTime = userStartTime
        self.userCompletionTime = userCompletionTime
    }

    public var status: BlockStatus {
        get { BlockStatus(rawValue: statusRaw) ?? .accepted }
        set { statusRaw = newValue.rawValue }
    }

    public var routePoints: [RoutePoint]? {
        get {
            guard
                let data = routePointsData,
                let decoded = try? Self.routeDecoder.decode([RoutePoint].self, from: data),
                !decoded.isEmpty
            else {
                return nil
            }
            return decoded
        }
        set {
            if let points = newValue, !points.isEmpty {
                routePointsData = try? Self.routeEncoder.encode(points)
            } else {
                routePointsData = nil
            }
        }
    }

    private static let routeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let routeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

public extension Block {
    var hoursDecimal: Decimal { Decimal(durationMinutes) / 60 }
    var grossPayout: Decimal { grossBase + (tipsAmount ?? 0) }
    var mileageDeduction: Decimal { miles * irsRateSnapshot }
    var additionalExpensesTotal: Decimal {
        expenses.reduce(0 as Decimal) { partial, e in
            if ExpenseCategory(rawValue: e.categoryRaw)?.excludedFromTotals == true {
                return partial
            } else {
                return partial + e.amount
            }
        }
    }
    var totalProfit: Decimal { grossPayout - mileageDeduction - additionalExpensesTotal }
    var roundedMiles: Decimal {
        var mutable = miles
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutable, 0, .plain)
        return rounded
    }
    var roundedMilesDisplay: String {
        let value = NSDecimalNumber(decimal: roundedMiles).intValue
        return "\(value) mi"
    }
    var scheduledStartDate: Date { startTime ?? date }
    var scheduledEndDate: Date {
        if let explicitEnd = endTime {
            return explicitEnd
        }
        let effectiveStart = scheduledStartDate
        let effectiveMinutes = max(1, durationMinutes)
        return effectiveStart.addingTimeInterval(TimeInterval(effectiveMinutes * 60))
    }
}

public enum AppearancePreference: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Model
public final class AppSettings {
    @Attribute(.unique) public var id: UUID
    public var irsMileageRate: Decimal
    public var currencyCode: String
    public var roundingScale: Int
    public var preferredAppearanceRaw: String?
    public var includePreReminder: Bool = true
    public var hasDismissedPlanCard: Bool = false
    public var hasCompletedOnboarding: Bool

    private static let defaultExpenseCategoryDescriptors = ExpenseCategoryDescriptor.defaultList
    private static let defaultExpenseCategoryJSON: String = {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(defaultExpenseCategoryDescriptors)
        return String(data: data ?? Data(), encoding: .utf8) ?? "[]"
    }()

    private var expenseCategoriesJSON: String = defaultExpenseCategoryJSON

    public var expenseCategoryDescriptors: [ExpenseCategoryDescriptor] {
        get {
            Self.decodeExpenseCategoryDescriptors(from: expenseCategoriesJSON)
        }
        set {
            expenseCategoriesJSON = Self.encodeExpenseCategoryDescriptors(newValue)
        }
    }

    public init(
        id: UUID = UUID(),
        irsMileageRate: Decimal = 0.70,
        currencyCode: String = "USD",
        roundingScale: Int = 2,
        preferredAppearance: AppearancePreference = .system,
        includePreReminder: Bool = true,
        hasDismissedPlanCard: Bool = false,
        expenseCategories: [ExpenseCategoryDescriptor]? = nil,
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.irsMileageRate = irsMileageRate
        self.currencyCode = currencyCode
        self.roundingScale = roundingScale
        self.preferredAppearanceRaw = preferredAppearance.rawValue
        self.includePreReminder = includePreReminder
        self.hasDismissedPlanCard = hasDismissedPlanCard
        let categoriesToUse = expenseCategories ?? Self.defaultExpenseCategoryDescriptors
        self.expenseCategoriesJSON = Self.encodeExpenseCategoryDescriptors(categoriesToUse)
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var preferredAppearance: AppearancePreference {
        get { AppearancePreference(rawValue: preferredAppearanceRaw ?? AppearancePreference.system.rawValue) ?? .system }
        set { preferredAppearanceRaw = newValue.rawValue }
    }

    private static func decodeExpenseCategoryDescriptors(from json: String) -> [ExpenseCategoryDescriptor] {
        let decoder = JSONDecoder()
        if let data = json.data(using: .utf8),
           let decoded = try? decoder.decode([ExpenseCategoryDescriptor].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return Self.defaultExpenseCategoryDescriptors
    }

    private static func encodeExpenseCategoryDescriptors(_ descriptors: [ExpenseCategoryDescriptor]) -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(descriptors),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return Self.defaultExpenseCategoryJSON
    }
}
