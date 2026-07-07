#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> SwiftLint"
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint
else
  echo "SwiftLint not found. Install with: brew install swiftlint" >&2
  exit 1
fi

echo "==> Periphery (unused code)"
if command -v periphery >/dev/null 2>&1; then
  if [[ ! -f HotBod.xcodeproj/project.pbxproj ]]; then
    echo "Generating Xcode project..."
    xcodegen generate
  fi
  periphery scan --project HotBod.xcodeproj --schemes HotBod --targets HotBod --quiet
else
  echo "Periphery not found. Install with: brew install peripheryapp/periphery/periphery" >&2
  exit 1
fi

echo "Lint complete."
