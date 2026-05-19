import SwiftUI

/// Build 26: lists MetricKit-captured crash and hang reports, with
/// raw JSON inspection and a "Clear all" sweep. Reachable from
/// Settings → About → "Crash & diagnostic logs" when one or more
/// logs exist.
struct CrashLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [DiagnosticLogFile] = []
    @State private var detail: DiagnosticLogFile?
    @State private var confirmingClear: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                Group {
                    if logs.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Tokens.Space.sm) {
                                introCard
                                ForEach(logs) { log in
                                    logRow(log)
                                }
                            }
                            .padding(.horizontal, Tokens.Space.lg)
                            .padding(.top, Tokens.Space.md)
                            .padding(.bottom, 60)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .navigationTitle("Crash logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
                if !logs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            confirmingClear = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(Tokens.Color.rose)
                    }
                }
            }
            .onAppear { reload() }
            .sheet(item: $detail) { log in
                CrashLogDetailSheet(log: log)
            }
            .alert("Clear all logs?", isPresented: $confirmingClear) {
                Button("Clear", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes \(logs.count) diagnostic log\(logs.count == 1 ? "" : "s") from this device. Apple's MetricKit may deliver new ones tomorrow.")
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("From MetricKit, on-device only")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Text("Apple collects crash and hang reports privately and hands them to Cadence at most once per day. They're never uploaded anywhere — they live in this app's container until you clear them.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
        )
    }

    private func logRow(_ log: DiagnosticLogFile) -> some View {
        Button {
            Haptics.tap()
            detail = log
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(tint(for: log).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon(for: log))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint(for: log))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.kind)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("\(log.modifiedAt, format: .relative(presentation: .named)) · \(byteString(log.sizeBytes))")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Color.text3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.text3)
            }
            .padding(Tokens.Space.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tokens.Color.mint)
            Text("No crashes recorded")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Text("Nothing here means Cadence has been stable on this device. New reports show up here once iOS delivers them — usually overnight after a crash.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
        }
        .padding(.top, Tokens.Space.xxxl)
    }

    private func reload() {
        logs = MetricKitObserver.listLogs()
    }

    private func clearAll() {
        for log in logs {
            try? FileManager.default.removeItem(at: log.url)
        }
        reload()
    }

    private func icon(for log: DiagnosticLogFile) -> String {
        switch log.kind {
        case "Crash": return "exclamationmark.octagon.fill"
        case "Hang":  return "tortoise.fill"
        default:      return "doc.text"
        }
    }

    private func tint(for log: DiagnosticLogFile) -> Color {
        switch log.kind {
        case "Crash": return Tokens.Color.rose
        case "Hang":  return Tokens.Color.amber
        default:      return Tokens.Color.text3
        }
    }

    private func byteString(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct CrashLogDetailSheet: View {
    let log: DiagnosticLogFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    Text(prettyJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Tokens.Color.text2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Space.lg)
                }
            }
            .navigationTitle(log.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: log.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(Tokens.Color.accent2)
                }
            }
        }
    }

    private var prettyJSON: String {
        guard let data = try? Data(contentsOf: log.url) else { return "(could not read file)" }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let text = String(data: pretty, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "(invalid utf-8)"
    }
}
