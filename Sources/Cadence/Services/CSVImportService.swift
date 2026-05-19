import Foundation
import SwiftData

/// Build 22: import tasks from a CSV file (Things 3 / TickTick / Todoist
/// exports + generic). Detects the format from header column names and
/// maps to TaskItem fields. Lightweight RFC-4180 parser that handles
/// quoted fields with embedded commas + escaped quotes.
@MainActor
enum CSVImportService {

    enum DetectedFormat: String {
        case things       // Things 3 export
        case ticktick     // TickTick export
        case todoist      // Todoist export
        case generic      // unknown — best-effort column mapping

        var displayName: String {
            switch self {
            case .things:   return "Things 3"
            case .ticktick: return "TickTick"
            case .todoist:  return "Todoist"
            case .generic:  return "CSV"
            }
        }
    }

    struct Preview {
        let format: DetectedFormat
        let headers: [String]
        let mapping: ColumnMapping
        let rowCount: Int
        let sampleRows: [[String]]  // first 3 rows for the preview
    }

    /// Which CSV columns map to which TaskItem fields. nil = field not
    /// present in this CSV.
    struct ColumnMapping {
        var titleIndex: Int?
        var notesIndex: Int?
        var dueDateIndex: Int?
        var priorityIndex: Int?
        var listIndex: Int?
        var statusIndex: Int?
        var tagsIndex: Int?
    }

    // MARK: Parsing

    /// Parses the entire CSV into a header row + data rows. Returns nil if
    /// the file is empty or malformed.
    static func parse(_ content: String) -> (headers: [String], rows: [[String]])? {
        let lines = splitCSVRows(content)
        guard lines.count >= 1 else { return nil }
        let headers = parseRow(lines[0])
        let rows = lines.dropFirst().map { parseRow($0) }
        return (headers, Array(rows))
    }

    /// RFC-4180-ish row splitter — handles quoted fields with newlines.
    private static func splitCSVRows(_ content: String) -> [String] {
        var rows: [String] = []
        var current = ""
        var insideQuotes = false
        for char in content {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char)
            } else if char == "\n" && !insideQuotes {
                if !current.isEmpty || !rows.isEmpty {
                    rows.append(current)
                }
                current = ""
            } else if char == "\r" {
                continue
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Splits a single row by commas, honoring quoted segments and
    /// converting "" → " inside quotes.
    private static func parseRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        var i = row.startIndex
        while i < row.endIndex {
            let char = row[i]
            if char == "\"" {
                let next = row.index(after: i)
                if insideQuotes, next < row.endIndex, row[next] == "\"" {
                    current.append("\"")
                    i = row.index(after: next)
                    continue
                }
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i = row.index(after: i)
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: Format detection

    static func detect(headers: [String]) -> (DetectedFormat, ColumnMapping) {
        let lower = headers.map { $0.lowercased() }

        // Things 3 export columns: Title, Notes, When, Deadline, Tags,
        // Project, Area, Heading, Status (sometimes more).
        if lower.contains("when") && lower.contains("project") {
            var m = ColumnMapping()
            m.titleIndex = lower.firstIndex(of: "title")
            m.notesIndex = lower.firstIndex(of: "notes")
            m.dueDateIndex = lower.firstIndex(of: "deadline") ?? lower.firstIndex(of: "when")
            m.listIndex = lower.firstIndex(of: "project") ?? lower.firstIndex(of: "area")
            m.tagsIndex = lower.firstIndex(of: "tags")
            m.statusIndex = lower.firstIndex(of: "status")
            return (.things, m)
        }

        // TickTick export: List Name, Title, Content, Tags, Is Check list,
        // Start Date, Due Date, Reminder, Repeat, Priority, Status, Created Time.
        if lower.contains("list name") && lower.contains("due date") {
            var m = ColumnMapping()
            m.titleIndex = lower.firstIndex(of: "title")
            m.notesIndex = lower.firstIndex(of: "content")
            m.dueDateIndex = lower.firstIndex(of: "due date")
            m.priorityIndex = lower.firstIndex(of: "priority")
            m.listIndex = lower.firstIndex(of: "list name")
            m.statusIndex = lower.firstIndex(of: "status")
            m.tagsIndex = lower.firstIndex(of: "tags")
            return (.ticktick, m)
        }

        // Todoist export: TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,
        // RESPONSIBLE,DATE,DATE_LANG,TIMEZONE. List name is in a separate
        // header section that appears as TYPE=section. Simplified mapping:
        if lower.contains("type") && lower.contains("priority") && lower.contains("date") {
            var m = ColumnMapping()
            m.titleIndex = lower.firstIndex(of: "content")
            m.notesIndex = lower.firstIndex(of: "description")
            m.dueDateIndex = lower.firstIndex(of: "date")
            m.priorityIndex = lower.firstIndex(of: "priority")
            return (.todoist, m)
        }

        // Generic — fuzzy column-name heuristic.
        var m = ColumnMapping()
        m.titleIndex = lower.firstIndex { ["title", "name", "task", "content"].contains($0) }
        m.notesIndex = lower.firstIndex { ["notes", "note", "description", "details"].contains($0) }
        m.dueDateIndex = lower.firstIndex { ["due", "due date", "duedate", "date", "deadline"].contains($0) }
        m.priorityIndex = lower.firstIndex { ["priority", "importance"].contains($0) }
        m.listIndex = lower.firstIndex { ["list", "project", "category", "list name"].contains($0) }
        m.statusIndex = lower.firstIndex { ["status", "state", "completed"].contains($0) }
        m.tagsIndex = lower.firstIndex { ["tags", "labels"].contains($0) }
        return (.generic, m)
    }

    // MARK: Preview construction

    static func makePreview(from content: String) -> Preview? {
        guard let parsed = parse(content) else { return nil }
        let (format, mapping) = detect(headers: parsed.headers)
        return Preview(
            format: format,
            headers: parsed.headers,
            mapping: mapping,
            rowCount: parsed.rows.count,
            sampleRows: Array(parsed.rows.prefix(3))
        )
    }

    // MARK: Import

    /// Bulk-create TaskItems from a parsed CSV. Groups by the list column
    /// (if present); else everything lands in a single TaskList named by
    /// the file or "Imported".
    static func importContent(
        _ content: String,
        defaultListName: String,
        context: ModelContext
    ) -> Int {
        guard let preview = makePreview(from: content),
              let parsed = parse(content) else { return 0 }
        let mapping = preview.mapping

        let descriptor = FetchDescriptor<TaskList>(
            sortBy: [SortDescriptor(\TaskList.sortOrder, order: .reverse)]
        )
        var nextSort = ((try? context.fetch(descriptor).first?.sortOrder) ?? 0) + 1

        // Pre-create lists. If the CSV doesn't have a list column, use
        // a single fallback list named after the file.
        var listsByName: [String: TaskList] = [:]
        if mapping.listIndex == nil {
            let single = TaskList(
                name: defaultListName,
                colorKey: "indigo",
                iconKey: "tray.full.fill",
                sortOrder: nextSort,
                isSeeded: false
            )
            context.insert(single)
            listsByName[defaultListName] = single
            nextSort += 1
        }

        var imported = 0
        for row in parsed.rows {
            guard let titleIdx = mapping.titleIndex,
                  titleIdx < row.count else { continue }
            let title = row[titleIdx]
            guard !title.isEmpty else { continue }

            let listName: String = {
                if let idx = mapping.listIndex, idx < row.count, !row[idx].isEmpty {
                    return row[idx]
                }
                return defaultListName
            }()

            let list: TaskList = {
                if let existing = listsByName[listName] { return existing }
                let l = TaskList(
                    name: listName,
                    colorKey: "indigo",
                    iconKey: "tray.full.fill",
                    sortOrder: nextSort,
                    isSeeded: false
                )
                context.insert(l)
                listsByName[listName] = l
                nextSort += 1
                return l
            }()

            let notes = (mapping.notesIndex.flatMap { idx in idx < row.count ? row[idx] : nil })?.nilIfEmpty
            let dueDate = (mapping.dueDateIndex.flatMap { idx in idx < row.count ? row[idx] : nil })
                .flatMap { Self.parseDate($0) }
            let priority = (mapping.priorityIndex.flatMap { idx in idx < row.count ? row[idx] : nil })
                .flatMap { Self.parsePriority($0, format: preview.format) } ?? .none
            let status: TaskStatus = (mapping.statusIndex.flatMap { idx in idx < row.count ? row[idx] : nil })
                .flatMap { Self.parseStatus($0) } ?? .open

            let tags: [String] = (mapping.tagsIndex.flatMap { idx in idx < row.count ? row[idx] : nil })
                .map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } } ?? []

            let task = TaskItem(
                title: title,
                notes: notes,
                dueDate: dueDate,
                allDay: dueDate != nil,
                priority: priority,
                status: status,
                tags: tags,
                list: list
            )
            context.insert(task)
            imported += 1
        }

        try? context.save()
        return imported
    }

    // MARK: Field parsers

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd HH:mm",
            "MM/dd/yyyy",
            "MM/dd/yyyy HH:mm",
            "dd/MM/yyyy",
            "MMMM d, yyyy",
            "MMM d, yyyy"
        ]
        return formats.map { fmt in
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            return df
        }
    }()

    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        for df in dateFormatters {
            if let date = df.date(from: trimmed) { return date }
        }
        return nil
    }

    static func parsePriority(_ raw: String, format: DetectedFormat) -> Priority? {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        // Todoist uses 1-4 (1 = highest); TickTick uses 0/1/3/5
        if let int = Int(lower) {
            switch format {
            case .todoist:
                switch int { case 1: return .high; case 2: return .medium; case 3: return .low; default: return Priority.none }
            case .ticktick:
                switch int { case 1, 5: return .high; case 3: return .medium; case 0: return Priority.none; default: return .low }
            default:
                if int >= 3 { return .high }
                if int == 2 { return .medium }
                if int == 1 { return .low }
                return Priority.none
            }
        }
        switch lower {
        case "high", "h":   return .high
        case "medium", "m": return .medium
        case "low", "l":    return .low
        default:            return Priority.none
        }
    }

    static func parseStatus(_ raw: String) -> TaskStatus? {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "completed", "done", "complete", "true", "1", "yes", "y":
            return .completed
        default:
            return .open
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
