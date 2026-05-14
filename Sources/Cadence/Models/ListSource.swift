import Foundation

/// Either a persisted TaskList or one of the computed Smart Lists.
/// Allows ListDetailView to render the same UI from either input.
enum ListSource: Hashable {
    case list(TaskList)
    case smart(SmartListKind)

    var displayName: String {
        switch self {
        case .list(let list): return list.name
        case .smart(let kind): return kind.displayName
        }
    }

    var iconKey: String {
        switch self {
        case .list(let list): return list.iconKey
        case .smart(let kind): return kind.iconKey
        }
    }

    var colorKey: String {
        switch self {
        case .list(let list): return list.colorKey
        case .smart(let kind): return kind.colorKey
        }
    }
}

enum SmartListKind: String, CaseIterable, Hashable, Identifiable {
    case noDueDate
    case overdue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noDueDate: return "No due date"
        case .overdue:   return "Overdue"
        }
    }

    var subtitle: String {
        switch self {
        case .noDueDate: return "Tasks waiting for a date"
        case .overdue:   return "Past due, still open"
        }
    }

    var iconKey: String {
        switch self {
        case .noDueDate: return "infinity"
        case .overdue:   return "exclamationmark.triangle.fill"
        }
    }

    var colorKey: String {
        switch self {
        case .noDueDate: return "indigo"
        case .overdue:   return "rose"
        }
    }
}
