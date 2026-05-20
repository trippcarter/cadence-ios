#!/usr/bin/env bash
# Cadence build helper — single archive, dual export, no ambiguity.
#
# Outputs:
#   build/ipa-dev/Cadence-Dev.ipa             → direct install (devicectl)
#   build/ipa-testflight/Cadence-current.ipa → Transporter / TestFlight
#
# Usage:
#   ./build.sh archive       # archive only
#   ./build.sh testflight    # re-export TestFlight IPA from existing archive
#   ./build.sh dev           # re-export Dev IPA from existing archive
#   ./build.sh install       # devicectl install to iPhone
#   ./build.sh validate      # run altool --validate-app on the TestFlight IPA
#   ./build.sh all           # archive + both exports + install (default)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

XCODE_DEV_DIR="/Applications/Xcode-26.5.0.app/Contents/Developer"
ARCHIVE_PATH="$REPO_ROOT/build/Cadence.xcarchive"
TF_OUT="$REPO_ROOT/build/ipa-testflight"
DEV_OUT="$REPO_ROOT/build/ipa-dev"
TF_PLIST="$REPO_ROOT/ExportOptions-AppStore.plist"
DEV_PLIST="$REPO_ROOT/ExportOptions-Development.plist"
IPHONE_DEVICE_ID="BCA7B68E-DBB0-52B1-924D-A8E0DADF4BD3"  # Tripp's Current iPhone

export DEVELOPER_DIR="$XCODE_DEV_DIR"

# ── helpers ───────────────────────────────────────────────────────

build_number() {
  awk -F'"' '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$REPO_ROOT/project.yml"
}

human_size() {
  # macOS-friendly file size in KB/MB.
  local bytes="$1"
  if [[ $bytes -gt 1048576 ]]; then
    printf "%.1f MB" "$(echo "scale=1; $bytes/1048576" | bc)"
  elif [[ $bytes -gt 1024 ]]; then
    printf "%.0f KB" "$(echo "scale=0; $bytes/1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

cmd_regenerate() {
  /opt/homebrew/bin/xcodegen generate > /dev/null
  echo "✓ Xcode project regenerated"
}

# ── archive ───────────────────────────────────────────────────────

cmd_archive() {
  cmd_regenerate
  rm -rf "$ARCHIVE_PATH"
  echo "→ Archiving (this is the slow step)…"
  xcodebuild archive \
    -project "$REPO_ROOT/Cadence.xcodeproj" \
    -scheme Cadence-iOS \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -configuration Release \
    -quiet
  echo "✓ Build $(build_number) archived"
}

# ── exports ───────────────────────────────────────────────────────

cmd_testflight() {
  rm -rf "$TF_OUT"
  echo "→ Exporting TestFlight IPA (Apple Distribution signing)…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$TF_PLIST" \
    -exportPath "$TF_OUT" \
    -allowProvisioningUpdates \
    -quiet
  mv "$TF_OUT/Cadence.ipa" "$TF_OUT/Cadence-current.ipa"
  local size
  size=$(stat -f%z "$TF_OUT/Cadence-current.ipa")
  echo "✓ Cadence-current.ipa exported to $TF_OUT/ ($(human_size $size))"
}

cmd_dev() {
  rm -rf "$DEV_OUT"
  echo "→ Exporting Dev IPA (Apple Development signing)…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$DEV_PLIST" \
    -exportPath "$DEV_OUT" \
    -allowProvisioningUpdates \
    -quiet
  mv "$DEV_OUT/Cadence.ipa" "$DEV_OUT/Cadence-Dev.ipa"
  local size
  size=$(stat -f%z "$DEV_OUT/Cadence-Dev.ipa")
  echo "✓ Cadence-Dev.ipa exported to $DEV_OUT/ ($(human_size $size))"
}

# ── install / validate ────────────────────────────────────────────

cmd_install() {
  if [[ ! -d "$ARCHIVE_PATH/Products/Applications/Cadence.app" ]]; then
    echo "✗ No archive found — run ./build.sh archive first." >&2
    exit 1
  fi
  echo "→ Installing to iPhone via devicectl…"
  xcrun devicectl device install app \
    --device "$IPHONE_DEVICE_ID" \
    "$ARCHIVE_PATH/Products/Applications/Cadence.app" > /dev/null
  echo "✓ Direct install of Cadence-Dev.ipa to iPhone (Tripp's Current iPhone)"
}

cmd_validate() {
  local ipa="$TF_OUT/Cadence-current.ipa"
  if [[ ! -f "$ipa" ]]; then
    echo "✗ No TestFlight IPA found at ${ipa} — run ./build.sh testflight first." >&2
    exit 1
  fi
  echo "→ Running local signing check on ${ipa}…"
  local_validate "$ipa"

  # Try cloud-side altool validate if credentials are configured.
  if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
    echo "→ Running xcrun altool --validate-app (App Store Connect API)…"
    xcrun altool --validate-app \
      --type ios \
      --file "$ipa" \
      --apiKey "$ASC_API_KEY_ID" \
      --apiIssuer "$ASC_API_ISSUER_ID"
    echo "✓ Cloud validation passed"
  elif [[ -n "${ASC_USERNAME:-}" && -n "${ASC_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "→ Running xcrun altool --validate-app (username + app-specific password)…"
    xcrun altool --validate-app \
      --type ios \
      --file "$ipa" \
      --username "$ASC_USERNAME" \
      --password "$ASC_APP_SPECIFIC_PASSWORD"
    echo "✓ Cloud validation passed"
  else
    echo "ℹ Skipping cloud validation — no ASC credentials in environment."
    echo "  Set ASC_API_KEY_ID + ASC_API_ISSUER_ID, or"
    echo "  ASC_USERNAME + ASC_APP_SPECIFIC_PASSWORD, then re-run."
  fi
}

# Lightweight local validation — catches the things that have actually
# burned us so far (development signing, missing Distribution profile,
# top-level Watch app duplicate).
local_validate() {
  # `grep -m1` closes the pipe early and macOS codesign reports SIGPIPE
  # via the pipeline exit code — under `set -o pipefail` that would
  # abort the whole script. Relax strict mode for this function only.
  set +o pipefail
  local ipa="$1"
  local tmp
  tmp=$(mktemp -d)
  unzip -q "$ipa" -d "$tmp"

  # Signing identity must be Apple Distribution, not Apple Development.
  local auth
  auth=$(codesign --display --verbose=4 "$tmp/Payload/Cadence.app" 2>&1 | grep -m1 "^Authority=Apple")
  if [[ "$auth" != *"Apple Distribution"* ]]; then
    echo "  ✗ Wrong signing identity: $auth" >&2
    echo "    Expected: Apple Distribution …" >&2
    rm -rf "$tmp"
    exit 2
  fi
  echo "  ✓ Signed by: $auth"

  # Provisioning profile must NOT be a development profile.
  local profile_plist="$tmp/profile.plist"
  security cms -D -i "$tmp/Payload/Cadence.app/embedded.mobileprovision" \
    > "$profile_plist" 2>/dev/null
  local profile_name
  profile_name=$(/usr/libexec/PlistBuddy -c "Print :Name" "$profile_plist" 2>/dev/null \
    || echo "<missing>")
  if [[ "$profile_name" == *"Development"* || "$profile_name" == *"Ad Hoc"* ]]; then
    echo "  ✗ Wrong provisioning profile: $profile_name" >&2
    rm -rf "$tmp"
    exit 2
  fi
  echo "  ✓ Profile: $profile_name"

  # Build number sanity.
  local build_in_ipa
  build_in_ipa=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
    "$tmp/Payload/Cadence.app/Info.plist" 2>/dev/null)
  echo "  ✓ Build number in IPA: $build_in_ipa"

  # Watch app embedded, not duplicated at top level.
  local watch_app="$tmp/Payload/Cadence.app/Watch/CadenceWatchApp.app"
  if [[ -d "$watch_app" ]]; then
    echo "  ✓ Watch app embedded inside Cadence.app/Watch/"
  fi
  if [[ -d "$tmp/Payload/CadenceWatchApp.app" ]]; then
    echo "  ✗ Watch app ALSO at IPA top level — would fail validation" >&2
    rm -rf "$tmp"
    exit 2
  fi

  # Watch icons compiled into Assets.car. This is the bug that bit us
  # in iterations 3 and 4: Contents.json declared the icon as
  # idiom=universal, so the watchOS asset compiler dropped it silently
  # and the IPA shipped to App Store with zero icons → 409 rejection.
  if [[ -d "$watch_app" ]]; then
    local watch_icon_count
    watch_icon_count=$(/usr/bin/assetutil --info "$watch_app/Assets.car" 2>/dev/null \
      | grep -c '"Idiom" : "watch"' || true)
    if [[ "$watch_icon_count" -lt 4 ]]; then
      echo "  ✗ Watch Assets.car has only $watch_icon_count watch-idiom entries — App Store will reject with 'Missing Icons'" >&2
      rm -rf "$tmp"
      exit 2
    fi
    echo "  ✓ Watch Assets.car has $watch_icon_count watch-idiom icon entries"
    # Belt-and-suspenders: CFBundleIcons in Watch Info.plist
    local watch_icons
    watch_icons=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" \
      "$watch_app/Info.plist" 2>/dev/null || echo "")
    if [[ "$watch_icons" == "AppIcon" ]]; then
      echo "  ✓ Watch Info.plist CFBundleIcons → AppIcon"
    else
      echo "  ⚠ Watch Info.plist missing CFBundleIcons (asset catalog still drives icons)" >&2
    fi
  fi

  rm -rf "$tmp"
  set -o pipefail
  echo "✓ Local validation passed"
}

# ── all ───────────────────────────────────────────────────────────

cmd_all() {
  local build
  cmd_archive
  build="$(build_number)"
  cmd_dev
  cmd_testflight
  cmd_install

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "✓ Build $build archived"
  echo "✓ Cadence-Dev.ipa exported to $DEV_OUT/ ($(human_size "$(stat -f%z "$DEV_OUT/Cadence-Dev.ipa")"))"
  echo "✓ Cadence-current.ipa exported to $TF_OUT/ ($(human_size "$(stat -f%z "$TF_OUT/Cadence-current.ipa")"))"
  echo "✓ Direct install of Cadence-Dev.ipa to iPhone (Tripp's Current iPhone)"
  echo "→ To upload to TestFlight: drag $TF_OUT/Cadence-current.ipa into Transporter"
  echo "═══════════════════════════════════════════════════════════"
}

case "${1:-all}" in
  archive)     cmd_archive ;;
  testflight)  cmd_testflight ;;
  dev)         cmd_dev ;;
  install)     cmd_install ;;
  validate)    cmd_validate ;;
  all)         cmd_all ;;
  *)
    echo "Usage: $0 [archive|testflight|dev|install|validate|all]"
    exit 1
    ;;
esac
