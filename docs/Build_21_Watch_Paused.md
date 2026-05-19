# Build 21 (Apple Watch) — paused

Paused mid-session because the watchOS SDK + sim runtime download took
too long; pivoted to Build 22 (Imports + Share Sheet). Watch source
files remain on disk in `Sources/CadenceWatch/` so we can resume by
re-wiring the XcodeGen target and rebuilding.

## To resume

### 1. Verify watchOS platform is fully installed

```
xcrun simctl list runtimes | grep watch
```

Should show `watchOS 26.5 ... com.apple.CoreSimulator.SimRuntime.watchOS-26-5`.
If not present, run `xcrun simctl runtime scan-and-mount`. If still
missing, run `xcodebuild -downloadPlatform watchOS` (one-time, ~5GB).

### 2. Re-add the embed dependency on the iOS target

In `project.yml`, under `Cadence-iOS.dependencies`, add back:

```yaml
      - target: CadenceWatch
        embed: true
        codeSign: true
```

### 3. Re-add the CadenceWatch target block

At the end of `project.yml` (after Cadence-iOS / Cadence-macOS and before
CadenceWidget), restore:

```yaml
  CadenceWatch:
    type: application
    platform: watchOS
    deploymentTarget: "10.0"
    sources:
      - path: Sources/CadenceWatch
      - path: Sources/Cadence/Models/Models.swift
      - path: Sources/Cadence/Models/ListPalette.swift
      - path: Sources/Cadence/Models/CachedEvent.swift
      - path: Sources/Cadence/Models/CalendarConfig.swift
      - path: Sources/Cadence/Models/ConnectedAccount.swift
      - path: Sources/Cadence/Models/RecurrenceRule.swift
      - path: Sources/Cadence/Models/Activity.swift
      - path: Sources/Cadence/Models/Household.swift
      - path: Sources/Cadence/Models/FocusSession.swift
      - path: Sources/Cadence/Models/HabitCompletion.swift
      - path: Sources/Cadence/Models/DailyReview.swift
      - path: Sources/Cadence/Tokens.swift
      - path: Sources/Cadence/Util/SharedContainer.swift
      - path: Sources/Cadence/Util/Haptics.swift
    settings:
      base:
        PRODUCT_NAME: Cadence
        PRODUCT_BUNDLE_IDENTIFIER: net.mcinnis.cadence.watchkitapp
        TARGETED_DEVICE_FAMILY: "4"
        GENERATE_INFOPLIST_FILE: NO
        SKIP_INSTALL: NO
        CODE_SIGN_ENTITLEMENTS: Sources/CadenceWatch/CadenceWatch.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    info:
      path: Sources/CadenceWatch/Info.plist
      properties:
        CFBundleDisplayName: Cadence
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        WKApplication: true
        WKCompanionAppBundleIdentifier: net.mcinnis.cadence
        WKRunsIndependentlyOfCompanionApp: false
        UIBackgroundModes:
          - remote-notification
```

### 4. Regenerate + build

```
xcodegen generate
xcodebuild build -project Cadence.xcodeproj -scheme CadenceWatch \
  -destination 'generic/platform=watchOS' -allowProvisioningUpdates
```

If asset compilation complains about a missing watchOS simulator
runtime even though `simctl runtime list` shows it Ready, the disk
image isn't mounted. Try `xcrun simctl runtime scan-and-mount`.

### 5. Install to the Watch

Once the iOS app archive is built with Watch embedded, the Apple Watch
auto-installs via the iPhone's Watch.app pairing flow (Tripp may need
to tap "Install" inside Watch.app on iPhone). Direct devicectl install
to the Watch is also possible via `xcrun devicectl device list` →
filter for watch UDID → install the .app bundle from
`build/Cadence.xcarchive/Products/Applications/Cadence.app/Watch/Cadence.app`.

## What's already shipped (in `Sources/CadenceWatch/`)

- `CadenceWatchApp.swift` — @main entry with safe-failure container init
  (same pattern as iOS app, Build 19+ recovery view inline)
- `WatchTodayView.swift` — today's open tasks scroll, 3-card stat
  strip (today / carried / done), empty state
- `WatchTaskRow.swift` — compact row with tap-to-complete circle, list
  color dot, time chip
- `CadenceWatch.entitlements` — App Group + CloudKit + APS
- `Assets.xcassets` — placeholder icon (cloned from iOS) + AccentColor

## Deferred from Build 21 spec

These didn't ship in v1 of the Watch app even when the Watch resumes —
they're follow-up Watch builds:

- Voice add (SFSpeechRecognizer + microphone permission)
- Lists drill-down view
- Settings view on Watch
- Complications (3 sizes — needs a separate widget extension target)
- Custom notification UI with Complete action button
- Sync indicator with rotating Cadence "C" logo
