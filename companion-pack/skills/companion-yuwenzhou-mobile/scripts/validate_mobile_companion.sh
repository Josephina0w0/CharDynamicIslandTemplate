#!/bin/zsh
set -euo pipefail

[[ $# -eq 1 ]] || {
  echo "Usage: $0 <CharacterCompanionMobile-project-directory>" >&2
  exit 2
}

project_dir="${1:A}"
project_file="$project_dir/CharacterCompanionMobile.xcodeproj/project.pbxproj"
main_plist="$project_dir/Resources/Info.plist"
widget_plist="$project_dir/WidgetExtension/Info.plist"
main_entitlements="$project_dir/Resources/CharacterCompanionMobile.entitlements"
widget_entitlements="$project_dir/WidgetExtension/CharacterCompanionWidgetExtension.entitlements"
repository="$project_dir/Shared/SharedStateRepository.swift"
widget_source="$project_dir/WidgetExtension/CharacterCompanionWidgets.swift"

required_files=(
  "$project_file"
  "$main_plist"
  "$widget_plist"
  "$main_entitlements"
  "$widget_entitlements"
  "$repository"
  "$widget_source"
  "$project_dir/Shared/CompanionProfile.swift"
  "$project_dir/Shared/SharedModels.swift"
  "$project_dir/Shared/CompanionActions.swift"
  "$project_dir/Sources/TrackerModels.swift"
  "$project_dir/Sources/RecordsAnalytics.swift"
)

for path in "${required_files[@]}"; do
  [[ -f "$path" ]] || { echo "missing: $path" >&2; exit 1; }
done

/usr/bin/plutil -lint "$main_plist" "$widget_plist" "$main_entitlements" "$widget_entitlements" >/dev/null

main_group="$(/usr/libexec/PlistBuddy -c "Print :'com.apple.security.application-groups':0" "$main_entitlements")"
widget_group="$(/usr/libexec/PlistBuddy -c "Print :'com.apple.security.application-groups':0" "$widget_entitlements")"
[[ "$main_group" == "$widget_group" ]] || {
  echo "App Group mismatch: app=$main_group widget=$widget_group" >&2
  exit 1
}
/usr/bin/grep -Fq "\"$main_group\"" "$repository" || {
  echo "SharedStateRepository does not use entitlement App Group: $main_group" >&2
  exit 1
}

build_values="$(/usr/bin/grep 'CURRENT_PROJECT_VERSION = ' "$project_file" | /usr/bin/sed -E 's/.*= ([^;]+);/\1/' | /usr/bin/sort -u)"
build_count="$(echo "$build_values" | /usr/bin/grep -c . | /usr/bin/tr -d ' ')"
[[ "$build_count" == "1" ]] || {
  echo "main app and Widget build numbers differ: $build_values" >&2
  exit 1
}

required_assets=(
  AppIcon working break water working-compact break-compact water-compact
  home tracker records reminder-first reminder-second reminder-third reminder-fourth
)
for name in "${required_assets[@]}"; do
  suffix="imageset"
  [[ "$name" == "AppIcon" ]] && suffix="appiconset"
  asset="$project_dir/Resources/Assets.xcassets/$name.$suffix/Contents.json"
  [[ -f "$asset" ]] || { echo "missing asset set: $name" >&2; exit 1; }
done

/usr/bin/grep -Fq 'Text(' "$widget_source"
/usr/bin/grep -Fq 'timerInterval:' "$widget_source" || {
  echo "Widget timer must use timerInterval to remain live" >&2
  exit 1
}
/usr/bin/grep -Fq 'recoveryRefreshInterval' "$widget_source" || {
  echo "Widget recovery refresh is missing" >&2
  exit 1
}

if command -v rg >/dev/null 2>&1; then
  if rg -n '/Users/.*/Downloads|/var/folders|/private/tmp' "$project_dir" --glob '*.swift' --glob '*.plist' --glob '*.pbxproj'; then
    echo "runtime source contains temporary or user-download paths" >&2
    exit 1
  fi
fi

display_name="$(/usr/bin/plutil -extract CFBundleDisplayName raw "$main_plist")"
version_values="$(/usr/bin/grep 'MARKETING_VERSION = ' "$project_file" | /usr/bin/sed -E 's/.*= ([^;]+);/\1/' | /usr/bin/sort -u)"

echo "validated: $project_dir"
echo "display name: $display_name"
echo "version: $version_values ($build_values)"
echo "App Group: $main_group"
echo "Widget timer: dynamic with recovery refresh"
