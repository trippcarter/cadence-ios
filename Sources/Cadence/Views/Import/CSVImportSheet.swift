import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Build 22: CSV import flow. UIDocumentPicker → preview → confirm import.
///
/// Auto-detects Things 3 / TickTick / Todoist exports by their header
/// column names and maps to TaskItem fields. Unrecognized CSVs fall back
/// to a generic column-name heuristic (title/name/task → title,
/// notes/description → notes, due/date/deadline → dueDate, etc.).
struct CSVImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum Phase { case picking, preview, importing, done }

    @State private var phase: Phase = .picking
    @State private var fileURL: URL?
    @State private var preview: CSVImportService.Preview?
    @State private var rawContent: String?
    @State private var defaultListName: String = "Imported"
    @State private var importedCount: Int = 0
    @State private var errorMessage: String?
    @State private var isShowingDocPicker: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                        .disabled(phase == .importing)
                }
                if phase == .preview {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import") { startImport() }
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.accent2)
                    }
                }
                if phase == .done {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(Tokens.Color.accent2)
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingDocPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .picking:   pickingView
        case .preview:   previewView
        case .importing: importingView
        case .done:      doneView
        }
    }

    // MARK: Phase 1 — picking

    private var pickingView: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Color.indigo.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Tokens.Color.indigo)
            }
            VStack(spacing: 8) {
                Text("Import from CSV")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Things 3, TickTick, Todoist, or any tool that exports tasks as CSV. We'll auto-detect the format and let you preview before importing.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.rose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            Spacer()
            Button {
                Haptics.tap()
                isShowingDocPicker = true
            } label: {
                Text("Choose CSV file")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md + 2)
                    .background(
                        LinearGradient(
                            colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                    .shadow(color: Tokens.Color.accentGlow, radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.bottom, Tokens.Space.xl)
        }
    }

    // MARK: Phase 2 — preview

    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                if let preview {
                    formatBanner(format: preview.format, rowCount: preview.rowCount)
                    if preview.mapping.listIndex == nil {
                        defaultListSection
                    }
                    headerMappingSection(preview: preview)
                    sampleRowsSection(preview: preview)
                }
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, 80)
        }
    }

    private func formatBanner(format: CSVImportService.DetectedFormat, rowCount: Int) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: formatIcon(format))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Detected: \(format.displayName)")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("\(rowCount) rows ready to import")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func formatIcon(_ format: CSVImportService.DetectedFormat) -> String {
        switch format {
        case .things:   return "circle.dashed"
        case .ticktick: return "checkmark.circle.fill"
        case .todoist:  return "checklist"
        case .generic:  return "doc.text"
        }
    }

    private var defaultListSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Default list".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            TextField("Imported", text: $defaultListName)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.md)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
            Text("This CSV doesn't include a list column — everything will land in one new list.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
        }
    }

    private func headerMappingSection(preview: CSVImportService.Preview) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Field mapping".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            VStack(spacing: 0) {
                mappingRow("Title", index: preview.mapping.titleIndex, headers: preview.headers)
                Divider().background(Tokens.Color.borderSoft)
                mappingRow("Notes", index: preview.mapping.notesIndex, headers: preview.headers)
                Divider().background(Tokens.Color.borderSoft)
                mappingRow("Due date", index: preview.mapping.dueDateIndex, headers: preview.headers)
                Divider().background(Tokens.Color.borderSoft)
                mappingRow("Priority", index: preview.mapping.priorityIndex, headers: preview.headers)
                Divider().background(Tokens.Color.borderSoft)
                mappingRow("List", index: preview.mapping.listIndex, headers: preview.headers)
                Divider().background(Tokens.Color.borderSoft)
                mappingRow("Status", index: preview.mapping.statusIndex, headers: preview.headers)
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    private func mappingRow(_ label: String, index: Int?, headers: [String]) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
            Spacer()
            if let idx = index, idx < headers.count {
                Text(headers[idx])
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Tokens.Color.accent2)
            } else {
                Text("—")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md - 2)
    }

    private func sampleRowsSection(preview: CSVImportService.Preview) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Sample tasks".uppercased())
                .font(Tokens.Font.label)
                .kerning(0.6)
                .foregroundStyle(Tokens.Color.text3)
            VStack(spacing: 0) {
                ForEach(Array(preview.sampleRows.enumerated()), id: \.offset) { idx, row in
                    if let titleIdx = preview.mapping.titleIndex, titleIdx < row.count {
                        HStack {
                            Image(systemName: "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(Tokens.Color.text3)
                            Text(row[titleIdx])
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Color.text)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, Tokens.Space.lg)
                        .padding(.vertical, Tokens.Space.sm + 2)
                        if idx < preview.sampleRows.count - 1 {
                            Divider().background(Tokens.Color.borderSoft)
                        }
                    }
                }
            }
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
    }

    // MARK: Phase 3 — importing

    private var importingView: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Tokens.Color.accent2)
            Text("Importing tasks…")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Spacer()
        }
    }

    // MARK: Phase 4 — done

    private var doneView: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Color.mint.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Tokens.Color.mint)
            }
            VStack(spacing: 6) {
                Text("\(importedCount) tasks imported")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Look for the new lists in the Lists tab.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    // MARK: Actions

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            fileURL = url
            // iOS security-scoped resource — must open + close around read.
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                rawContent = content
                if let parsedPreview = CSVImportService.makePreview(from: content) {
                    preview = parsedPreview
                    if defaultListName == "Imported" {
                        let base = url.deletingPathExtension().lastPathComponent
                        if !base.isEmpty { defaultListName = base }
                    }
                    phase = .preview
                } else {
                    errorMessage = "Couldn't parse that file. Make sure it's a valid CSV with a header row."
                }
            } catch {
                errorMessage = "Couldn't read the file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "File picker error: \(error.localizedDescription)"
        }
    }

    private func startImport() {
        guard let content = rawContent else { return }
        Haptics.tap()
        phase = .importing
        Task { @MainActor in
            let count = CSVImportService.importContent(
                content,
                defaultListName: defaultListName.isEmpty ? "Imported" : defaultListName,
                context: modelContext
            )
            importedCount = count
            Haptics.success()
            WidgetReloader.reload()
            phase = .done
        }
    }
}
