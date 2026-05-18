import Foundation

/// Apple-Calendar-style side-by-side layout for overlapping events on a
/// single-day timeline. Given a set of time-ranged entries, returns per-entry
/// `(columnIndex, columnCount, isOverflow)` so the caller can size each block
/// to `availableWidth / columnCount` and offset it horizontally.
///
/// Overlap behavior:
///   - Up to `maxVisibleColumns` events render side-by-side at full height
///   - The (maxVisibleColumns)-th and beyond are marked overflow; UI is
///     expected to render a "+N more" affordance in the last column
///   - Items are grouped into "clusters" of transitively-overlapping events;
///     columnCount is uniform across a cluster so widths line up visually
enum OverlapLayout {

    /// Minimal time-range protocol the helper needs.
    struct Entry: Hashable {
        let id: String
        let start: Date
        let end: Date
    }

    struct Position: Equatable {
        let columnIndex: Int
        /// Total columns visible in this entry's cluster — used to compute
        /// width = `availableWidth / columnCount`.
        let columnCount: Int
        /// True when the entry would have been assigned to a column beyond
        /// `maxVisibleColumns`. Caller hides these and renders a single
        /// "+N more" chip aggregating them.
        let isOverflow: Bool
        /// On the entries that ARE the "+N more" anchor (one per cluster
        /// that has overflow), this is the count of hidden siblings. Zero
        /// on everything else.
        let overflowCount: Int
    }

    /// Compute positions for a list of entries.
    static func positions(
        for entries: [Entry],
        maxVisibleColumns: Int = 4
    ) -> [String: Position] {
        guard !entries.isEmpty else { return [:] }

        let sorted = entries.sorted { a, b in
            if a.start != b.start { return a.start < b.start }
            return a.end > b.end // longer first on ties
        }

        // 1. Assign column index to each entry (lowest available column where
        //    the last item in that column ends before this one starts).
        var columnEnds: [Date] = []       // columnEnds[i] = end time of last entry in column i
        var assignedColumn: [String: Int] = [:]
        var overflowIDs: Set<String> = []

        for entry in sorted {
            var placed = false
            for (idx, end) in columnEnds.enumerated() {
                if end <= entry.start {
                    columnEnds[idx] = entry.end
                    assignedColumn[entry.id] = idx
                    placed = true
                    break
                }
            }
            if !placed {
                let newIdx = columnEnds.count
                columnEnds.append(entry.end)
                assignedColumn[entry.id] = newIdx
                if newIdx >= maxVisibleColumns {
                    overflowIDs.insert(entry.id)
                }
            }
        }

        // 2. Build clusters: walk sorted entries, group transitively-overlapping
        //    entries. Track each cluster's max column index.
        var clusters: [[Entry]] = []
        var currentCluster: [Entry] = []
        var currentEnd: Date = .distantPast

        for entry in sorted {
            if currentCluster.isEmpty {
                currentCluster = [entry]
                currentEnd = entry.end
            } else if entry.start < currentEnd {
                currentCluster.append(entry)
                currentEnd = max(currentEnd, entry.end)
            } else {
                clusters.append(currentCluster)
                currentCluster = [entry]
                currentEnd = entry.end
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        // 3. For each cluster, compute its column count and assign positions.
        var positions: [String: Position] = [:]
        for cluster in clusters {
            let rawMaxCol = cluster.compactMap { assignedColumn[$0.id] }.max() ?? 0
            let columnCount = min(rawMaxCol + 1, maxVisibleColumns)

            // Find the entry that will host the "+N more" affordance — the
            // last-starting visible entry in the cluster that's NOT overflow.
            let overflowInCluster = cluster.filter { overflowIDs.contains($0.id) }
            let overflowCount = overflowInCluster.count

            // Pick the cluster's "+N more anchor" = the visible entry in the
            // overflow column (maxVisibleColumns - 1) with the latest start.
            let overflowAnchor: String? = {
                guard overflowCount > 0 else { return nil }
                let lastColumnEntries = cluster
                    .filter { (assignedColumn[$0.id] ?? -1) == maxVisibleColumns - 1 }
                    .sorted { $0.start > $1.start }
                return lastColumnEntries.first?.id
            }()

            for entry in cluster {
                let col = assignedColumn[entry.id] ?? 0
                let isOverflow = overflowIDs.contains(entry.id)
                let anchorCount = (entry.id == overflowAnchor) ? overflowCount : 0
                positions[entry.id] = Position(
                    columnIndex: col,
                    columnCount: columnCount,
                    isOverflow: isOverflow,
                    overflowCount: anchorCount
                )
            }
        }

        return positions
    }
}
