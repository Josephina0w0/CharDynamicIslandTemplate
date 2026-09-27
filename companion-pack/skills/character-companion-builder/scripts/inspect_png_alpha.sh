#!/bin/zsh
set -euo pipefail

[[ $# -ge 1 ]] || {
  echo "Usage: $0 <image.png> [...]" >&2
  exit 2
}

script_dir="$(cd "$(dirname "$0")" && pwd)"
sdk_path="${CHARACTER_ISLAND_SDK_PATH:-}"
if [[ -z "$sdk_path" ]]; then
  if [[ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]]; then
    sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
  else
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
  fi
fi

cache_dir="${TMPDIR:-/tmp}/character-companion-alpha-module-cache"
/bin/mkdir -p "$cache_dir"

swift \
  -sdk "$sdk_path" \
  -module-cache-path "$cache_dir" \
  "$script_dir/inspect_png_alpha.swift" \
  "$@"
