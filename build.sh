#!/usr/bin/env bash
# Cadence build helper — single archive, dual export.
#
# Why this script exists:
#   Pre-Build-30 the pipeline produced ONE IPA by manually zipping the
#   archive's Cadence.app folder. That .app was always Apple Development
#   signed, which Transporter rejects with a 409 "Invalid Provisioning
#   Profile" error when uploading to App Store Connect.
#
#   Now we archive once and run xcodebuild -exportArchive twice — once
#   with an App Store options plist (Apple Distribution signing for
#   TestFlight/ASC) and once with a Development options plist (for
#   direct installs to a plugged-in iPhone via devicectl).
#
# Outputs:
#   build/ipa-appstore/Cadence.ipa     — for Transporter / TestFlight
#   build/ipa-development/Cadence.ipa  — for `devicectl device install`
#
# Usage:
#   ./build.sh archive       # full archive + both exports
#   ./build.sh appstore      # re-export App Store from existing archive
#   ./build.sh development   # re-export Development from existing archive
#   ./build.sh install       # direct-install Development IPA to iPhone
#   ./build.sh all           # archive + exports + install (default)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

XCODE_DEV_DIR="/Applications/Xcode-26.5.0.app/Contents/Developer"
ARCHIVE_PATH="$REPO_ROOT/build/Cadence.xcarchive"
APPSTORE_OUT="$REPO_ROOT/build/ipa-appstore"
DEV_OUT="$REPO_ROOT/build/ipa-development"
APPSTORE_PLIST="$REPO_ROOT/ExportOptions-AppStore.plist"
DEV_PLIST="$REPO_ROOT/ExportOptions-Development.plist"
IPHONE_DEVICE_ID="BCA7B68E-DBB0-52B1-924D-A8E0DADF4BD3"  # Tripp's Current iPhone

export DEVELOPER_DIR="$XCODE_DEV_DIR"

cmd_regenerate() {
  /opt/homebrew/bin/xcodegen generate > /dev/null
  echo "✓ Xcode project regenerated"
}

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
  echo "✓ Archive at $ARCHIVE_PATH"
}

build_number() {
  # Read CURRENT_PROJECT_VERSION from project.yml so the renamed IPAs
  # match whichever build we just archived.
  awk -F'"' '/CURRENT_PROJECT_VERSION:/ { print $2; exit }' "$REPO_ROOT/project.yml"
}

cmd_appstore() {
  rm -rf "$APPSTORE_OUT"
  echo "→ Exporting App Store IPA…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$APPSTORE_PLIST" \
    -exportPath "$APPSTORE_OUT" \
    -allowProvisioningUpdates \
    -quiet
  local build
  build="$(build_number)"
  local final="$APPSTORE_OUT/Cadence-${build}-AppStore.ipa"
  mv "$APPSTORE_OUT/Cadence.ipa" "$final"
  echo "✓ App Store IPA at $final"
  echo "  → drop this one in Transporter, or run:"
  echo "    xcrun altool --upload-app --type ios --file $final \\"
  echo "      --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
}

cmd_development() {
  rm -rf "$DEV_OUT"
  echo "→ Exporting Development IPA…"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$DEV_PLIST" \
    -exportPath "$DEV_OUT" \
    -allowProvisioningUpdates \
    -quiet
  local build
  build="$(build_number)"
  local final="$DEV_OUT/Cadence-${build}-Development.ipa"
  mv "$DEV_OUT/Cadence.ipa" "$final"
  echo "✓ Development IPA at $final"
}

cmd_install() {
  if [[ ! -d "$ARCHIVE_PATH/Products/Applications/Cadence.app" ]]; then
    echo "✗ No archive found — run ./build.sh archive first." >&2
    exit 1
  fi
  echo "→ Installing to iPhone via devicectl…"
  xcrun devicectl device install app \
    --device "$IPHONE_DEVICE_ID" \
    "$ARCHIVE_PATH/Products/Applications/Cadence.app"
}

cmd_all() {
  cmd_archive
  cmd_appstore
  cmd_development
  cmd_install
  local build
  build="$(build_number)"
  echo ""
  echo "═══════════════════════════════════════"
  echo "✓ Build $build complete"
  echo "  Direct install:   ./build.sh install   (already done)"
  echo "  Transporter:      $APPSTORE_OUT/Cadence-${build}-AppStore.ipa"
  echo "═══════════════════════════════════════"
}

case "${1:-all}" in
  archive)     cmd_archive ;;
  appstore)    cmd_appstore ;;
  development) cmd_development ;;
  install)     cmd_install ;;
  all)         cmd_all ;;
  *)
    echo "Usage: $0 [archive|appstore|development|install|all]"
    exit 1
    ;;
esac
