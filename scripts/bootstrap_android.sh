#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required: https://docs.flutter.dev/get-started/install' >&2
  exit 1
fi
# Generate standard Flutter Android Gradle, Kotlin and resource files.
# The provided manifest is retained; no placeholder platform stubs are shipped.
flutter create --platforms=android --project-name medmitra --org in.medmitra .
python3 scripts/configure_android.py
flutter pub get
flutter analyze
flutter test
printf '\nFlutter app prepared. Run: flutter run\n'
