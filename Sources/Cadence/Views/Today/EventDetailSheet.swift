import SwiftUI

struct EventDetailSheet: View {
    let event: CachedEvent
    @Environment(\.dismiss) private var dismiss
    #if canImport(UIKit)
    @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        title
                        properties
                        if let url = event.meetingURL {
                            joinMeetingButton(url: url)
                        }
                        if let notes = event.notes, !notes.isEmpty {
                            notesBlock(notes: notes)
                        }
                        if let htmlLink = event.htmlLink {
                            openInGoogleButton(url: htmlLink)
                        }
                        Spacer(minLength: Tokens.Space.xl)
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Tokens.Color.accent2)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("EVENT")
                        .font(Tokens.Font.label)
                        .kerning(1.2)
                        .foregroundStyle(Tokens.Color.text3)
                }
            }
            .toolbarBackground(Tokens.Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Tokens.Color.text)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                Text(event.isAllDay ? "All day · \(event.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))" : "\(event.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())) – \(event.end.formatted(.dateTime.hour().minute()))")
                    .font(Tokens.Font.chip)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Tokens.Color.teal.opacity(0.14))
            .foregroundStyle(Tokens.Color.teal)
            .clipShape(Capsule())
        }
    }

    private var properties: some View {
        VStack(spacing: 0) {
            if let location = event.location, !location.isEmpty {
                propertyRow(icon: "mappin.and.ellipse", title: "Location", value: location) {
                    #if canImport(UIKit)
                    let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
                        openURL(url)
                    }
                    #endif
                }
                Divider().background(Tokens.Color.borderSoft)
            }
            if !event.attendees.isEmpty {
                propertyRow(icon: "person.2.fill", title: "Attendees", value: "\(event.attendees.count) people")
                Divider().background(Tokens.Color.borderSoft)
                ForEach(event.attendees.prefix(8), id: \.self) { attendee in
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.Color.text3)
                            .frame(width: 18)
                        Text(attendee)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Color.text2)
                        Spacer()
                    }
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.vertical, 6)
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

    private func propertyRow(icon: String, title: String, value: String, onTap: (() -> Void)? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Color.text3)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Tokens.Font.label)
                    .foregroundStyle(Tokens.Color.text3)
                Text(value)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Color.text)
                    .lineLimit(2)
            }
            Spacer()
            if onTap != nil {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent2)
            }
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func notesBlock(notes: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("NOTES")
                .font(Tokens.Font.label)
                .kerning(0.8)
                .foregroundStyle(Tokens.Color.text3)
            Text(notes)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Color.text)
                .padding(Tokens.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
                )
        }
    }

    private func joinMeetingButton(url: URL) -> some View {
        Button {
            #if canImport(UIKit)
            openURL(url)
            #endif
        } label: {
            HStack {
                Image(systemName: "video.fill")
                Text("Join meeting")
                    .font(Tokens.Font.bodyEmphasis)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, Tokens.Space.md)
            .padding(.horizontal, Tokens.Space.lg)
            .background(
                LinearGradient(
                    colors: [Tokens.Color.accent, Tokens.Color.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func openInGoogleButton(url: URL) -> some View {
        Button {
            #if canImport(UIKit)
            openURL(url)
            #endif
        } label: {
            HStack {
                Image(systemName: "arrow.up.forward.app")
                Text("Open in Google Calendar")
                    .font(Tokens.Font.body)
                Spacer()
            }
            .foregroundStyle(Tokens.Color.text2)
            .padding(.vertical, Tokens.Space.md)
            .padding(.horizontal, Tokens.Space.lg)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Color.borderSoft, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
