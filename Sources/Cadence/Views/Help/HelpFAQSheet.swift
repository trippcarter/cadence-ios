import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

/// Build 26: searchable FAQ with expandable answers, reachable from
/// Settings → "Help & FAQ". Each entry tap-toggles open. Bottom of the
/// sheet has a "Contact support" button that opens MFMailComposeViewController
/// pre-filled to tripp@mcinnis.net. If the device has no mail account
/// configured, it falls back to a mailto: URL.
struct HelpFAQSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authSession: AuthSession

    @State private var searchText: String = ""
    @State private var expanded: Set<String> = []
    @State private var showingMail: Bool = false
    @State private var mailFallbackAlert: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.sm) {
                        if filtered.isEmpty {
                            emptySearchState
                                .padding(.top, Tokens.Space.xxl)
                        } else {
                            ForEach(filtered) { entry in
                                faqCard(entry)
                            }
                        }
                        contactSupportCard
                            .padding(.top, Tokens.Space.xl)
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search FAQs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Tokens.Color.accent2)
                }
            }
            #if canImport(MessageUI)
            .sheet(isPresented: $showingMail) {
                MailComposeView(
                    recipient: "tripp@mcinnis.net",
                    subject: defaultSupportSubject,
                    body: defaultSupportBody
                )
                .ignoresSafeArea()
            }
            #endif
            .alert("Mail not set up", isPresented: $mailFallbackAlert) {
                Button("Copy email address") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = "tripp@mcinnis.net"
                    #endif
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add a mail account in iOS Settings, or email tripp@mcinnis.net directly from another app.")
            }
        }
    }

    // MARK: Search

    private var filtered: [FAQEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return FAQEntry.all }
        return FAQEntry.all.filter { entry in
            entry.question.lowercased().contains(trimmed)
                || entry.answer.lowercased().contains(trimmed)
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Tokens.Color.text3)
            Text("No matches")
                .font(Tokens.Font.bodyEmphasis)
                .foregroundStyle(Tokens.Color.text)
            Text("Try a different word, or tap Contact support below.")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Color.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: FAQ card

    private func faqCard(_ entry: FAQEntry) -> some View {
        let isOpen = expanded.contains(entry.id)
        return Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                if isOpen { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: isOpen ? Tokens.Space.sm : 0) {
                HStack(alignment: .top, spacing: Tokens.Space.md) {
                    Image(systemName: entry.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(entry.tint)
                        .frame(width: 22)
                        .padding(.top, 1)
                    Text(entry.question)
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Tokens.Color.text3)
                        .padding(.top, 3)
                }
                if isOpen {
                    Text(entry.answer)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Color.text2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 34)
                        .padding(.trailing, Tokens.Space.sm)
                        .padding(.bottom, Tokens.Space.xs)
                }
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

    // MARK: Contact support

    private var contactSupportCard: some View {
        Button {
            Haptics.tap()
            openSupport()
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Color.accent.opacity(0.20))
                        .frame(width: 36, height: 36)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.accent2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact support")
                        .font(Tokens.Font.bodyEmphasis)
                        .foregroundStyle(Tokens.Color.text)
                    Text("Email tripp@mcinnis.net — real human, real reply.")
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

    private func openSupport() {
        #if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            showingMail = true
            return
        }
        #endif
        if let url = URL(string: mailtoFallbackURL) {
            openURL(url) { accepted in
                if !accepted { mailFallbackAlert = true }
            }
        } else {
            mailFallbackAlert = true
        }
    }

    private var defaultSupportSubject: String {
        let name = authSession.state.user?.displayName ?? "Cadence user"
        return "Cadence Support: \(name)"
    }

    private var defaultSupportBody: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return """


        ─── please write above this line ───
        Cadence v\(version) (build \(build))
        \(deviceModel())
        \(systemVersion())
        """
    }

    private var mailtoFallbackURL: String {
        let subj = defaultSupportSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = defaultSupportBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "mailto:tripp@mcinnis.net?subject=\(subj)&body=\(body)"
    }

    private func deviceModel() -> String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Mac"
        #endif
    }

    private func systemVersion() -> String {
        #if canImport(UIKit)
        return "iOS \(UIDevice.current.systemVersion)"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }
}

// MARK: - FAQ data

struct FAQEntry: Identifiable, Hashable {
    let id: String
    let question: String
    let answer: String
    let icon: String
    let tint: Color

    static let all: [FAQEntry] = [
        FAQEntry(
            id: "share-space",
            question: "How do I share a space with someone?",
            answer: "Open the Lists tab, tap the space you want to share, then tap the share icon in the top right. Send the link via Messages or Mail. The recipient taps it on their iPhone and Cadence opens — your space appears in their Lists tab within a few seconds. They need an iCloud account on their device for sharing to work.",
            icon: "person.2.fill",
            tint: Tokens.Color.accent
        ),
        FAQEntry(
            id: "spaces-vs-lists",
            question: "What's the difference between Spaces and Lists?",
            answer: "A List is a single bucket of tasks (\"Groceries,\" \"Reading queue,\" \"Bug backlog\"). A Space is a group of lists you share with someone. A Space called \"Joint Business\" might contain lists \"Marketing,\" \"Sales,\" and \"Operations,\" all shared with your business partner. Solo lists you don't share live outside any Space.",
            icon: "rectangle.3.group.fill",
            tint: Tokens.Color.teal
        ),
        FAQEntry(
            id: "switch-apple-id",
            question: "How do I switch Apple IDs?",
            answer: "Settings → Account → Switch Apple ID. Cadence signs you out, clears local credentials, and brings you back to the Sign in with Apple screen. Your data stays in whichever iCloud account it was synced to — switching just changes whose data the app is reading.",
            icon: "arrow.left.arrow.right",
            tint: Tokens.Color.indigo
        ),
        FAQEntry(
            id: "not-syncing",
            question: "Why isn't my data syncing?",
            answer: "Three usual suspects: (1) Make sure you're signed into iCloud in iOS Settings — open Settings → [your name] → iCloud → check Cadence is toggled on. (2) Make sure iCloud Drive is enabled on that iCloud account. (3) Check Settings → iCloud sync inside Cadence — it shows current sync status and any errors. Sync usually catches up within 30 seconds once those are right.",
            icon: "icloud.fill",
            tint: Tokens.Color.accent2
        ),
        FAQEntry(
            id: "import-reminders",
            question: "How do I import from Apple Reminders?",
            answer: "Settings → Import from… → Apple Reminders. Cadence asks for permission, then shows your existing Reminders lists with checkboxes. Pick what to bring over and tap Import. Existing Reminders stay where they are; Cadence makes its own copies.",
            icon: "tray.and.arrow.down.fill",
            tint: Tokens.Color.amber
        ),
        FAQEntry(
            id: "delete-account",
            question: "How do I delete my account?",
            answer: "Settings → Account → Delete my account. Confirms via destructive alert, then wipes local data and signs you out. Note: data already synced to your iCloud private database remains tied to your Apple ID. To remove it fully, sign out of Cadence in iOS Settings → Apple ID → iCloud → Cadence, then delete the app.",
            icon: "trash.fill",
            tint: Tokens.Color.rose
        ),
        FAQEntry(
            id: "export-data",
            question: "Can I export my data?",
            answer: "Yes. Settings → Account → Export my data. Cadence generates a JSON file containing every task, list, space, habit, focus session, and review log. You can save it to the Files app or email it to yourself. Use it as a backup, or move to another app any time.",
            icon: "square.and.arrow.up.fill",
            tint: Tokens.Color.mint
        ),
        FAQEntry(
            id: "no-notifications",
            question: "Why aren't notifications firing?",
            answer: "Settings → Notifications inside Cadence shows the current permission state. If it says \"Notifications blocked,\" tap \"Open System Settings\" and enable notifications for Cadence. Also confirm that Focus modes (Do Not Disturb, Work) aren't silencing the app. Use the \"Send a test\" button to confirm delivery.",
            icon: "bell.slash.fill",
            tint: Tokens.Color.rose
        ),
        FAQEntry(
            id: "siri-commands",
            question: "How do I use Siri commands?",
            answer: "Say things like \"Hey Siri, add to Cadence: pay rent next Friday\" or \"Hey Siri, what's on my plate today.\" Settings → Voice & Siri lists the supported phrases. You can also build custom Shortcuts in the Shortcuts app — Cadence exposes the actions \"Add task,\" \"Complete task,\" and \"Read today's tasks.\"",
            icon: "mic.fill",
            tint: Tokens.Color.accent2
        ),
        FAQEntry(
            id: "focus-mode",
            question: "What's Focus mode for?",
            answer: "Tap the timer icon on any task to start a focus session — a Pomodoro-style timer (default 25 minutes with a 5-minute break). Cadence tracks the session so your stats reflect where your attention actually went. Adjust durations in Settings → Focus.",
            icon: "timer",
            tint: Tokens.Color.accent
        ),
        FAQEntry(
            id: "daily-review",
            question: "How does the daily review work?",
            answer: "An optional evening check-in. Enable Settings → Daily review → Evening review and pick a time. Cadence sends a quiet notification at that time; tap it to see what you finished, what carried over, and write a one-line intention for tomorrow. It's optional and skipping it never breaks anything.",
            icon: "moon.zzz.fill",
            tint: Tokens.Color.indigo
        ),
        FAQEntry(
            id: "widget",
            question: "How do I add the widget to my home screen?",
            answer: "Long-press an empty area on your home screen → tap the + in the top-left → search \"Cadence\" → pick a widget size → Add Widget. Cadence offers small, medium, and large widgets showing today's tasks. Edit the widget to choose which list it reads from.",
            icon: "square.grid.2x2.fill",
            tint: Tokens.Color.teal
        )
    ]
}

#if canImport(MessageUI)
/// Build 26: MFMailComposeViewController wrapped for SwiftUI. Falls back
/// to nothing if the device can't send mail — caller is responsible for
/// checking `MFMailComposeViewController.canSendMail()` first.
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}
#endif
