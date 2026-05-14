import Foundation

/// Extracts structured fields (due date, list, priority, tags) from a
/// free-form task title like
/// "Email Sam tomorrow at 3pm #joint-business !high @followup".
///
/// Strategy: hand-rolled regex for the unambiguous Cadence tokens
/// (#list / !priority / @tag) — they're trivially parseable and don't
/// collide with natural English. The harder open-ended date+time phrasing
/// is delegated to NSDataDetector, which handles "tomorrow",
/// "next Friday at 3pm", "in 3 days", "MM/DD", and many others.
///
/// Designed to be re-run on every keystroke from the AddTaskSheet without
/// allocating heavy state.
enum NaturalLanguageTaskParser {

    // MARK: Public surface

    struct Result: Equatable {
        let originalText: String
        /// Title with all recognized tokens removed and whitespace collapsed.
        let title: String
        let dueDate: Date?
        let allDay: Bool
        /// Raw "#token" payload (without the #). Caller fuzzy-matches against
        /// real list names — we don't know them here.
        let listToken: String?
        let priority: Priority?
        let tags: [String]
        let highlights: [Highlight]

        static let empty = Result(
            originalText: "",
            title: "",
            dueDate: nil,
            allDay: false,
            listToken: nil,
            priority: nil,
            tags: [],
            highlights: []
        )
    }

    struct Highlight: Equatable {
        let range: NSRange
        let kind: Kind
        enum Kind { case date, list, priority, tag }
    }

    static func parse(_ input: String) -> Result {
        let trimmed = input
        guard !trimmed.isEmpty else { return .empty }

        let nsInput = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsInput.length)
        var highlights: [Highlight] = []
        var rangesToStrip: [NSRange] = []

        // 1. #list — first one wins
        var listToken: String?
        if let regex = try? NSRegularExpression(pattern: #"#([A-Za-z0-9][\w-]*)"#),
           let match = regex.firstMatch(in: trimmed, range: fullRange) {
            listToken = nsInput.substring(with: match.range(at: 1))
            highlights.append(Highlight(range: match.range, kind: .list))
            rangesToStrip.append(match.range)
        }

        // 2. !priority — first one wins
        var priority: Priority?
        if let regex = try? NSRegularExpression(pattern: #"!(high|medium|med|low|none)\b"#, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, range: fullRange) {
            let value = nsInput.substring(with: match.range(at: 1)).lowercased()
            switch value {
            case "high":             priority = .high
            case "medium", "med":    priority = .medium
            case "low":              priority = .low
            case "none":             priority = Priority.none
            default: break
            }
            highlights.append(Highlight(range: match.range, kind: .priority))
            rangesToStrip.append(match.range)
        }

        // 3. @tags — all matches
        var tags: [String] = []
        if let regex = try? NSRegularExpression(pattern: #"@([A-Za-z0-9][\w-]*)"#) {
            regex.enumerateMatches(in: trimmed, range: fullRange) { match, _, _ in
                guard let match else { return }
                let tag = nsInput.substring(with: match.range(at: 1))
                tags.append(tag)
                highlights.append(Highlight(range: match.range, kind: .tag))
                rangesToStrip.append(match.range)
            }
        }

        // 4. Date + time via NSDataDetector — first detected match wins.
        // Limit the search to a "scrubbed" copy of the input that has our
        // own tokens (#/!/@) blanked out so the detector doesn't get
        // confused by them.
        var dueDate: Date?
        var allDay = false
        let scrubbed = scrub(trimmed, ranges: rangesToStrip, nsString: nsInput)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: scrubbed, range: NSRange(location: 0, length: (scrubbed as NSString).length))
            if let first = matches.first, let date = first.date {
                dueDate = date
                allDay = isMidnight(date)
                highlights.append(Highlight(range: first.range, kind: .date))
                rangesToStrip.append(first.range)
            }
        }

        // 5. Build the title by removing all stripped ranges in descending order.
        let title = removeRanges(rangesToStrip, from: trimmed, nsString: nsInput)

        return Result(
            originalText: trimmed,
            title: title,
            dueDate: dueDate,
            allDay: allDay,
            listToken: listToken,
            priority: priority,
            tags: tags,
            highlights: highlights.sorted { $0.range.location < $1.range.location }
        )
    }

    // MARK: List fuzzy-match
    //
    // Lowercase + strip non-alphanumerics so "joint-business" matches
    // "Joint Business" and "personal" matches "Personal".

    static func fuzzyMatch(token: String, against names: [String]) -> String? {
        let normalizedToken = normalize(token)
        return names.first { normalize($0) == normalizedToken }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: Internals

    /// Replace ranges with spaces (preserves length so subsequent NSRanges
    /// computed on the same string stay valid).
    private static func scrub(_ input: String, ranges: [NSRange], nsString: NSString) -> String {
        guard !ranges.isEmpty else { return input }
        let mutable = NSMutableString(string: input)
        for range in ranges {
            let replacement = String(repeating: " ", count: range.length)
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return mutable as String
    }

    private static func removeRanges(_ ranges: [NSRange], from input: String, nsString: NSString) -> String {
        guard !ranges.isEmpty else { return collapseWhitespace(input) }
        let sorted = ranges.sorted { $0.location > $1.location }
        var working = input as NSString
        for range in sorted {
            // Bounds-check: if multiple regex matches overlapped this gets messy.
            guard NSMaxRange(range) <= working.length else { continue }
            working = working.replacingCharacters(in: range, with: "") as NSString
        }
        return collapseWhitespace(working as String)
    }

    private static func collapseWhitespace(_ s: String) -> String {
        let collapsed = s
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed
    }

    /// NSDataDetector reports relative dates like "tomorrow" at 00:00. We
    /// treat midnight as "no specific time given" → allDay = true.
    private static func isMidnight(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return comps.hour == 0 && comps.minute == 0 && comps.second == 0
    }
}
