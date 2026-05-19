import SwiftUI
import SwiftData

/// Build 22: full-sheet Reminders import flow. Three phases:
///   1. .needsAccess — explain + request EventKit permission
///   2. .picking — show user's Reminders lists with multi-select toggles
///   3. .importing — progress overlay
///   4. .done — confirmation with task count + done button
struct RemindersImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var service = RemindersImportService.shared

    enum Phase { case needsAccess, picking, importing, done }

    @State private var phase: Phase = .needsAccess
    @State private var sourceLists: [RemindersImportService.SourceList] = []
    @State private var selectedIDs: Set<String> = []
    @State private var includeCompleted: Bool = false
    @State private var progress: RemindersImportService.ProgressUpdate?
    @State private var finalCount: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Import Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Tokens.Color.text2)
                        .disabled(phase == .importing)
                }
                if phase == .picking {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import") { startImport() }
                            .font(Tokens.Font.bodyEmphasis)
                            .foregroundStyle(canImport ? Tokens.Color.accent2 : Tokens.Color.text3)
                            .disabled(!canImport)
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
        }
        .onAppear { refreshPhase() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .needsAccess: accessRequestView
        case .picking:     pickerView
        case .importing:   progressView
        case .done:        doneView
        }
    }

    // MARK: Phase 1 — request access

    private var accessRequestView: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Color.accent.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
            VStack(spacing: 8) {
                Text("Bring your Reminders in")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Cadence can read your existing Apple Reminders lists so you don't have to retype them. Read-only — nothing in Reminders changes.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            Spacer()
            Button {
                Task { await requestAccessAndProceed() }
            } label: {
                Text("Allow access")
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

    // MARK: Phase 2 — list picker

    private var pickerView: some View {
        VStack(spacing: 0) {
            includeCompletedRow
                .padding(.horizontal, Tokens.Space.lg)
                .padding(.vertical, Tokens.Space.md)
            List {
                Section {
                    ForEach(sourceLists) { list in
                        sourceListRow(list)
                    }
                } header: {
                    Text("Your lists")
                        .font(Tokens.Font.label)
                        .kerning(0.6)
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var includeCompletedRow: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Color.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Include completed reminders")
                    .font(Tokens.Font.bodyEmphasis)
                    .foregroundStyle(Tokens.Color.text)
                Text("Off by default — most users want only open items.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.text3)
            }
            Spacer()
            Toggle("", isOn: $includeCompleted)
                .labelsHidden()
                .tint(Tokens.Color.accent)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
    }

    private func sourceListRow(_ list: RemindersImportService.SourceList) -> some View {
        let isSelected = selectedIDs.contains(list.id)
        let countText = includeCompleted
            ? "\(list.totalCount) \(list.totalCount == 1 ? "item" : "items")"
            : "\(list.openCount) open \(list.totalCount > list.openCount ? "· \(list.totalCount - list.openCount) done" : "")"
        return Button {
            Haptics.tap()
            if isSelected {
                selectedIDs.remove(list.id)
            } else {
                selectedIDs.insert(list.id)
            }
        } label: {
            HStack(spacing: Tokens.Space.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Tokens.Color.accent : Tokens.Color.text3)
                if let cg = list.color {
                    Circle()
                        .fill(Color(cgColor: cg))
                        .frame(width: 10, height: 10)
                } else {
                    Circle().fill(Tokens.Color.text3).frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.title)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text(countText)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: Phase 3 — progress

    private var progressView: some View {
        VStack(spacing: Tokens.Space.lg) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(Tokens.Color.accent2)
            if let p = progress {
                VStack(spacing: 4) {
                    Text("Importing \(p.listsProcessed)/\(p.totalLists) lists")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    if let title = p.currentListTitle {
                        Text(title)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Color.text3)
                    }
                    Text("\(p.tasksImported) tasks imported")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
            } else {
                Text("Starting…")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
            }
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
                Text("\(finalCount) tasks imported")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Color.text)
                Text("Look for the new lists in the Lists tab.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text3)
                    .multilineTextAlignment(.center)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Color.rose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            Spacer()
        }
    }

    // MARK: State helpers

    private var canImport: Bool {
        !selectedIDs.isEmpty
    }

    private func refreshPhase() {
        switch service.authorizationState() {
        case .authorized:
            phase = .picking
            Task { await loadSourceLists() }
        case .notDetermined:
            phase = .needsAccess
        case .denied, .restricted:
            phase = .needsAccess
            errorMessage = "Reminders access is off. Enable it in Settings → Privacy → Reminders."
        }
    }

    private func requestAccessAndProceed() async {
        let result = await service.requestAccess()
        if result == .authorized {
            phase = .picking
            await loadSourceLists()
        } else {
            errorMessage = "Reminders access is off. Open Settings → Privacy → Reminders and enable Cadence."
        }
    }

    private func loadSourceLists() async {
        do {
            sourceLists = try await service.fetchSourceLists()
        } catch {
            errorMessage = "Couldn't load your Reminders: \(error.localizedDescription)"
        }
    }

    private func startImport() {
        Haptics.tap()
        phase = .importing
        Task {
            do {
                let count = try await service.importLists(
                    sourceListIDs: selectedIDs,
                    includeCompleted: includeCompleted,
                    context: modelContext
                ) { update in
                    Task { @MainActor in
                        self.progress = update
                    }
                }
                finalCount = count
                Haptics.success()
                phase = .done
                WidgetReloader.reload()
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
                phase = .done
            }
        }
    }
}
