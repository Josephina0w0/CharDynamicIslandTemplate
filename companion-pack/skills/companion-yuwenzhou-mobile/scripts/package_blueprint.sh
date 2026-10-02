#!/bin/zsh
set -euo pipefail

[[ $# -ge 3 && $# -le 4 ]] || {
  echo "Usage: $0 <project-directory> <skill-directory> <output-directory> [built-iphoneos-app]" >&2
  exit 2
}

project_dir="${1:A}"
skill_dir="${2:A}"
output_dir="${3:A}"
device_app="${4:-}"
script_dir="${0:A:h}"

"$script_dir/validate_mobile_companion.sh" "$project_dir"
/bin/mkdir -p "$output_dir"

source_archive="$output_dir/陪伴版-喻文州-source.zip"
skill_archive="$output_dir/companion-yuwenzhou-mobile.skill.zip"
/bin/rm -f "$source_archive" "$skill_archive"

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/companion-blueprint.XXXXXX")"
trap '/bin/rm -rf "$temp_root"' EXIT

/usr/bin/rsync -a \
  --exclude '.DS_Store' \
  --exclude '.git' \
  --exclude '.build' \
  --exclude 'DerivedData' \
  --exclude 'xcuserdata' \
  --exclude '*.xcuserstate' \
  "$project_dir/" "$temp_root/CharacterCompanionMobile/"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$temp_root/CharacterCompanionMobile" "$source_archive"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$skill_dir" "$skill_archive"

if [[ -n "$device_app" ]]; then
  device_app="${device_app:A}"
  [[ -d "$device_app" ]] || { echo "device app not found: $device_app" >&2; exit 1; }
  build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$device_app/Info.plist")"
  device_archive="$output_dir/陪伴版-喻文州-build${build}-iphoneos.app.zip"
  /bin/rm -f "$device_archive"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$device_app" "$device_archive"
fi

(
  cd "$output_dir"
  /usr/bin/shasum -a 256 ./*.zip > SHA256SUMS
)

echo "packaged: $output_dir"
/bin/ls -lh "$output_dir"
