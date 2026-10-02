#!/bin/zsh
set -euo pipefail

[[ $# -ge 2 && $# -le 3 ]] || {
  echo "Usage: $0 <project-directory> <physical-device-UDID> [derived-data-directory]" >&2
  exit 2
}

project_dir="${1:A}"
device_udid="$2"
derived_data="${3:-${TMPDIR:-/tmp}/CharacterCompanionMobile-DeviceDerivedData}"
project="$project_dir/CharacterCompanionMobile.xcodeproj"
app="$derived_data/Build/Products/Debug-iphoneos/CharacterCompanionMobile.app"

"${0:A:h}/validate_mobile_companion.sh" "$project_dir"

xcodebuild -quiet \
  -project "$project" \
  -scheme CharacterCompanionMobile \
  -configuration Debug \
  -destination "platform=iOS,id=$device_udid" \
  -derivedDataPath "$derived_data" \
  -allowProvisioningUpdates \
  build

[[ -d "$app" ]] || { echo "built app not found: $app" >&2; exit 1; }
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
xcrun devicectl device install app --device "$device_udid" "$app"
xcrun devicectl device process launch --device "$device_udid" --terminate-existing "$bundle_id"

echo "installed: $bundle_id"
echo "device: $device_udid"
echo "app: $app"
