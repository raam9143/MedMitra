# Milestone 1 implementation report — 2026-10-18

## Delivered

- Android-first Flutter source: dashboard, daily medication entry and schedule.
- Photo capture, family voice recording and foreground playback.
- English/Telugu/Hindi/Tamil UI dictionaries and locale-specific TTS templates.
- Local daily notification scheduling with Android exact permission request and inexact fallback.
- SQLite persisted medicines, local member identity demo, immutable-in-app dose event history.
- Transactional outbox designed for eventual idempotent synchronization.
- Proposed normalized PostgreSQL schema for caregiver cloud backend.
- Test cases for domain identities and schedule revisions; GitHub Actions draft workflow.

## Executed checks

`python scripts/check_source.py`:
- Android XML parsed, expected permissions and receiver declared: PASS.
- SQLite schema executes and medicine, taken, correction and outbox sample inserts work: PASS.
- Required files/imports present: PASS.
- Python scripts compile: PASS.
- pubspec YAML parses: PASS.

## Not executed

- Flutter/Dart compilation, Flutter unit tests, Android APK compilation and on-device
  alarms/audio testing, because Flutter and Android SDK are unavailable in this
  execution environment and network downloads are disabled.

## Known limitations

- This source milestone **does not provide a working cloud service** or remote
  caregiver authorization. It is not suitable for production use or clinical
  dependence. Local actors are demo identities only.
- No background auto-playing of the personalized recording at alarm time.
- Does not include dose repetitions across multiple times, skip/snooze, treatment
  start/end limits, strong encrypted-at-rest storage or multi-device reconciliation.
- Device-specific notifications, TTS language availability and permission revocation
  still require physical-device testing before use.

## Recommended next milestone

1. Build/test/debug APK with real Android devices and Flutter stable.
2. Add signed caregiver enrollment, verified remote permissions and encrypted sync.
3. Add multiple daily dose schedules and sound-on-alarm playback with Android
   background-execution research and explicit battery/permission testing.
4. Implement secure storage, retention, privacy, and formal production hardening.
