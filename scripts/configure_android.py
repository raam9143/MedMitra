"""Idempotent Android build configuration for flutter_local_notifications.

Flutter creates a Gradle build file according to the installed Flutter SDK;
we require the current Kotlin DSL build variant and fail closed on changes.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
file = root / 'android' / 'app' / 'build.gradle.kts'
if not file.exists():
    raise SystemExit('Expected android/app/build.gradle.kts from modern flutter create')
s = file.read_text()
if 'compileSdk = flutter.compileSdkVersion' in s:
    s = s.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
elif 'compileSdk = 36' not in s:
    raise SystemExit('Unknown compileSdk Gradle layout: update manually')
if 'minSdk = flutter.minSdkVersion' in s:
    s = s.replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
elif 'minSdk = 23' not in s:
    raise SystemExit('Unknown minSdk Gradle layout: update manually')
if 'isCoreLibraryDesugaringEnabled' not in s:
    m = re.search(r'compileOptions\s*\{', s)
    if not m:
        raise SystemExit('compileOptions section missing')
    at = m.end()
    s = s[:at] + '\n        isCoreLibraryDesugaringEnabled = true' + s[at:]
if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:' not in s:
    s += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n}\n'
file.write_text(s)
print('Configured compileSdk=36, minSdk=23, Java desugaring')
