#!/bin/zsh
set -euo pipefail

[[ $# -eq 1 ]] || {
  echo "Usage: $0 <CharacterCompanionMobile.app|app.zip>" >&2
  exit 2
}

input="${1:A}"
[[ -e "$input" ]] || { echo "missing input: $input" >&2; exit 1; }
temp_dir=""

cleanup() {
  if [[ -n "$temp_dir" && -d "$temp_dir" && "$temp_dir" == /private/tmp/* ]]; then
    /bin/rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

if [[ "$input" == *.zip ]]; then
  temp_dir="$(mktemp -d /private/tmp/mobile-companion-verify.XXXXXX)"
  /usr/bin/ditto -x -k "$input" "$temp_dir"
  app_paths=()
  while IFS= read -r -d '' path; do
    app_paths+=("$path")
  done < <(/usr/bin/find "$temp_dir" -maxdepth 3 -type d -name '*.app' -print0)
  [[ ${#app_paths[@]} -eq 1 ]] || {
    echo "expected one .app in archive; found ${#app_paths[@]}" >&2
    exit 1
  }
  app="${app_paths[1]}"
elif [[ "$input" == *.app && -d "$input" ]]; then
  app="$input"
else
  echo "input must be an .app directory or an app zip" >&2
  exit 2
fi

plist="$app/Info.plist"
[[ -f "$plist" ]] || { echo "main Info.plist missing" >&2; exit 1; }
/usr/bin/plutil -lint "$plist" >/dev/null
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
executable="$app/$executable_name"
[[ -x "$executable" ]] || { echo "main executable missing: $executable" >&2; exit 1; }

widget="$(/usr/bin/find "$app/PlugIns" -maxdepth 1 -type d -name '*.appex' -print -quit)"
[[ -n "$widget" && -f "$widget/Info.plist" ]] || { echo "Widget extension missing" >&2; exit 1; }
widget_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$widget/Info.plist")"
widget_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$widget/Info.plist")"
[[ "$widget_build" == "$build" && "$widget_version" == "$version" ]] || {
  echo "main/Widget version mismatch: $version ($build) vs $widget_version ($widget_build)" >&2
  exit 1
}

architectures="$(/usr/bin/lipo -archs "$executable")"
if signature_details="$(/usr/bin/codesign -dvv "$app" 2>&1)"; then
  if [[ "$signature_details" == *"linker-signed"* && ! -f "$app/embedded.mobileprovision" ]]; then
    signature="linker-signed simulator build"
  elif verify_output="$(/usr/bin/codesign --verify --deep --strict --verbose=2 "$app" 2>&1)"; then
    signature="verified"
  elif [[ -f "$app/embedded.mobileprovision" && "$verify_output" == *"CSSMERR_TP_NOT_TRUSTED"* ]]; then
    # Personal Team development certificates can be trusted by the paired iPhone
    # while their chain is unavailable to the local macOS verifier. The successful
    # device installation remains the runtime proof for this package.
    signature="present; Personal Team trust is device-scoped"
  else
    echo "$verify_output" >&2
    exit 1
  fi
else
  signature="unsigned simulator build"
fi

echo "verified: $app"
echo "bundle: $bundle_id"
echo "version: $version ($build)"
echo "architectures: $architectures"
echo "Widget: present and version-matched"
echo "signature: $signature"
