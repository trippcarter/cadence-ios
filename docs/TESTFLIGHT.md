# TestFlight playbook

Operational notes for shipping new Cadence builds to your iPhone (and
eventually your co-owner's) via TestFlight. Phase 7 set this up;
Phase 8 added Sign in with Apple gating + production seed cleanup;
Phase 9 closed the auth-isolation hole and made list creation + shared-list
data round-trip actually work.

## What testers see now (post-Phase 9)

1. **3-page onboarding pager** (first launch only). Welcome → Lists
   overview → Notifications hint. Skippable.
2. **Sign in with Apple** — system-native button. Apple ID is the
   credential; no password, no separate account.
   - First sign-in: Apple offers to share name + email, or hide email
     behind a `privaterelay.appleid.com` alias.
   - Subsequent sign-ins: same Apple ID restores existing tasks via
     iCloud Private DB.
   - **Account isolation** (new in Phase 9): the Apple Sign-In identity
     is bound to the iCloud user record at sign-in time. If a future
     launch detects the iCloud has changed (or doesn't match), Cadence
     wipes the local auth blob and shows SignInView again. Prevents the
     "I see your name on my device" failure mode.
3. **Welcome splash** (~1.5s) — animated handoff to the main app.
4. **Clean empty lists** — Inbox, Personal, Business, Joint Business.
   Real users never see the developer sample tasks (gated behind
   `#if DEBUG`).
5. **Create your own lists** (Phase 9). Lists tab → "New" pill →
   CreateListSheet (name + color + icon picker). Long-press any
   user-created list for Edit / Delete options. Default lists are
   editable but non-deletable.
6. **Shared lists actually sync** (Phase 9). Tap the share icon on any
   list, send via Messages, recipient accepts → list and tasks
   materialize on their phone. Edits flow in both directions within
   ~30 seconds via CloudKit silent pushes. See "How sharing works
   under the hood" below for the architecture.

## Settings → Account (Phase 9 additions)

- **Backed by iCloud: <name>** — diagnostic line showing which iCloud
  account is signed into the device. If this ever disagrees with the
  Apple Sign-In name above it, something is off.
- **Switch Apple ID** — destructive action. Signs out of the current
  Apple credential and returns to SignInView with a "Pick a different
  Apple ID" hint. Useful for testing as a different user without
  reinstalling.

## Where data lives

- **Tasks, lists, recurrence, time-blocks, sharing** → user's iCloud
  Private Database. Tied to their Apple ID, not Cadence's servers.
  Cadence doesn't host or see this data.
- **Apple user identifier + display name + email** → device Keychain
  (with simulator file-fallback). Used only for "who's signed in here?"
  display.
- **Google Calendar OAuth state** → device Keychain. Per-device.
- **Preferences** (theme, daily-brief time, notifications enabled,
  default mirror calendar) → `@AppStorage` on the device.

## Signing out

Settings → **Account** → **Sign Out**. Local-only:
- Apple credential removed from Keychain.
- Onboarding flag stays — testers don't re-see the pager unless they
  reinstall.
- iCloud-synced tasks/lists are untouched. Signing back in with the
  same Apple ID restores everything within seconds.

## One-time setup (already done)

- Apple Developer Program enrollment for `tripp@mcinnis.net` (Team ID
  `756CM5YLW6`).
- App record created in App Store Connect: **Cadence**, bundle
  `net.mcinnis.cadence`, SKU `cadence-ios-001`.
- App icon (`Sources/Cadence/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`)
  — currently a placeholder violet "C". Swap out for a real designed icon
  before any public launch.
- `ITSAppUsesNonExemptEncryption = false` in Info.plist so export
  compliance is auto-answered.
- iOS 26 SDK downloaded via Xcode 26.5 (`/Applications/Xcode-26.5.0.app`).
  Apple requires Xcode 26+ for any new submission.
- Entitlements in `Sources/Cadence/Cadence.entitlements`:
  - `com.apple.developer.applesignin` (Default) — Sign in with Apple
  - `com.apple.security.application-groups` (`group.net.mcinnis.cadence`)
  - `com.apple.developer.icloud-container-identifiers` (`iCloud.net.mcinnis.cadence`)
  - `com.apple.developer.icloud-services` (CloudKit)
  - `aps-environment` (development) for CloudKit silent push

## Shipping a new TestFlight build

Every new build needs:

1. **Bump `CURRENT_PROJECT_VERSION`** (the build number) in `project.yml`.
   Apple rejects duplicate build numbers within the same `MARKETING_VERSION`.
   Keep `MARKETING_VERSION` at the current public version (e.g. `1.0.0`)
   and increment build (`5` → `6` → `7` …).
2. **Regenerate the Xcode project**:
   ```bash
   xcodegen generate
   ```
3. **Archive** with Xcode 26's developer dir:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
     xcodebuild archive \
       -project Cadence.xcodeproj \
       -scheme Cadence-iOS \
       -destination 'generic/platform=iOS' \
       -archivePath build/Cadence.xcarchive \
       -allowProvisioningUpdates \
       -configuration Release
   ```
4. **Export the IPA**:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
     xcodebuild -exportArchive \
       -archivePath build/Cadence.xcarchive \
       -exportPath build/ipa \
       -exportOptionsPlist build/ExportOptions.plist \
       -allowProvisioningUpdates
   ```
5. **Upload via Transporter** — open the Transporter Mac app, drag
   `build/ipa/Cadence.ipa` into the drop zone, click **Deliver**.
   Apple processes the build (~5–15 min); you'll get an email when it's
   available in TestFlight.

If something fails at the archive or export step, the most common
culprits are:
- **Code signing**: open Xcode → Cadence target → Signing & Capabilities
  → confirm the team is Tripp Carter (`756CM5YLW6`) and "Automatically
  manage signing" is on.
- **Missing iOS platform**: `DEVELOPER_DIR=... xcodebuild -downloadPlatform iOS`
  re-downloads it.
- **Build number conflict**: bump `CURRENT_PROJECT_VERSION` and retry.
- **SDK version rejected**: Apple has bumped the required SDK. Install
  the latest Xcode via `xcodes install --latest`, then re-archive.

## Inviting a tester (Phase 4 co-owner test)

Internal Testing accepts up to 100 people who are members of your
Apple Developer team. Each gets the full TestFlight experience: invite
email, install via TestFlight app, builds delivered automatically.

1. App Store Connect → **Users and Access** → **People** → **Invite User**.
   Set their email + role (**Developer** is enough; **Admin** also works).
   Apple emails them an invite to join your team — they accept and are
   now eligible for Internal Testing.
2. App Store Connect → **Apps** → **Cadence** → **TestFlight** tab.
3. Under **Internal Testing**, click your group (e.g. "Owners"). Add
   the new team member. They get an email link to install the
   TestFlight app and accept the invitation.

For your co-owner specifically: once they're a team member + added to
the Internal Testing group, they'll get every build you upload going
forward, without any extra approval steps. They'll sign in with their
own Apple ID — their data lives in their iCloud, not yours.

## Direct install to a connected iPhone (faster dev loop)

When you want a build on your phone without waiting on Apple's
processing pipeline, install the `Cadence.app` from inside the archive
directly via USB:

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcrun devicectl list devices
# Note the UDID of your phone.

DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
  xcrun devicectl device install app \
    --device <UDID> \
    build/Cadence.xcarchive/Products/Applications/Cadence.app
```

The phone needs to be plugged in via cable, unlocked, and trusting
this Mac for development. This skips App Store Connect entirely and
puts the app on your phone in ~10 seconds.

## Version bumping conventions

- `MARKETING_VERSION` (`1.0.0`, `1.1.0`, etc.) — what users see in
  the App Store. Bump when shipping a meaningful release.
- `CURRENT_PROJECT_VERSION` (`1`, `2`, `3`, …) — internal build counter.
  Bump *every* TestFlight upload, otherwise Apple rejects with
  "build number already exists".

Both live at the top of `project.yml` under `settings.base`.

## How sharing works under the hood (Phase 9)

Cadence uses CloudKit's standard CKShare pattern but has to bridge it
manually because SwiftData's automatic CloudKit sync only handles the
**default zone** of the Private DB, while CKShare requires a **custom
zone**.

- Each shared list gets a custom zone: `Cadence.SharedList.<list-UUID>`.
- A `CadenceList` root CKRecord lives in that zone (name, color, icon,
  owner display name, modifiedAt). The CKShare attaches to it.
- Every TaskItem on the list is also mirrored to a `CadenceTask`
  CKRecord in the same zone (id, title, dueDate, status, priority,
  rrule, parentTaskID, modifiedAt + a `listRef` reference to the root).
- `SharedListMirror.swift` is the chokepoint. On every local task
  mutation (Add, Complete, Edit, Delete, Snooze) it pushes the change
  into the shared zone if the task's list is shared. On every CloudKit
  silent-push notification (or app foreground), it pulls
  `CKFetchRecordZoneChanges` deltas and reconciles into SwiftData
  using last-writer-wins via `modifiedAt`.
- Owner-side: writes go to the Private DB. Recipient-side: writes go
  to the Shared DB. Either side reading observes the same zone via
  CloudKit's CKShare propagation.
- Server change tokens are persisted per-list on `TaskList.shareZoneChangeToken`
  so pulls are incremental, not full-fetch every time.

When the **owner taps "Stop Sharing"** in the CloudKit share sheet,
`stopSharing(list:)` deletes the zone — recipients lose access on the
next pull. Local SwiftData rows stay on both sides (the owner's are
private again; the recipient's become orphaned and the
`applyDeletion` codepath drops them).

## Limitations / future work

- Currently **Internal Testing only**. External Testing (10,000 testers
  outside your team) requires Beta App Review and a privacy policy
  URL. Phase 7 deliberately skipped both since we're solo.
- Submitting for App Store review (a real public launch) needs:
  - App icon designed properly (current is a placeholder)
  - Screenshots for every supported device class
  - Marketing copy + description
  - Privacy policy hosted publicly (currently a placeholder link in SignInView)
  - Apple's review process (typically 24–48 hours)
- Phase 9 sharing still has rough edges:
  - Conflict resolution is naive last-writer-wins. Concurrent edits on
    the same field will lose one side. Acceptable for two-person lists;
    will need vector-clock or 3-way-merge for larger groups.
  - No "presence" indication of who else is viewing a shared list.
  - Recurring task subtasks may not propagate parent references
    correctly across the zone boundary — single-level subtasks work.
