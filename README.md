# MedMitra

**Android-first, offline-first medicine reminder app for Indian families.**

## Status: milestone 1 source implementation (NOT a production release)

This repository contains a Flutter application starter with functioning source
paths for medication CRUD, image capture, custom voice recording/preview, local
daily notification scheduling, family-local demo actor switching, dose taken /
correction event auditing, and an offline outbox for future network sync.

**Do not use this unvalidated starter as a primary or sole medication alert system.**
The project needs an Android device build and reliability testing; no APK is
included. Neither cloud sync nor secure remote caregiver authentication is
implemented yet. The actor selector is local/demo only.

## Quick start

Install the Flutter SDK and Android SDK on your development workstation.
Use current stable Flutter (3.32 or newer), Dart 3.8+ and Java 17.

```bash
unzip MedMitra-starter.zip
cd MedMitra
bash scripts/bootstrap_android.sh
flutter run
```

The script generates standard Flutter Android Gradle/Kotlin boilerplate with
`flutter create`, configures minSdk 23, compileSdk 36 and Java desugaring,
then runs `flutter analyze` and `flutter test`. The included Android manifest
adds recording/notification/boot/exact-alarm permissions. Test on a physical
Android device, not just an emulator.

## MVP capabilities

| Capability | Milestone 1 |
| --- | --- |
| Add/edit/pause a daily medicine with strength, dosage and instructions | Source implemented |
| Capture medicine photo | Source implemented |
| Record & preview custom family voice | Source implemented (foreground) |
| Listen to local TTS in en-IN, te-IN, hi-IN, ta-IN | Source implemented; device voices required |
| Persistent daily local notifications | Source implemented; requires Android device validation |
| Special exact-alarm permission handling | Source implemented; needs device testing |
| Elder/family dose confirmation on same phone | Demo implementation |
| Timestamp/actor/device audit event + correction | Source implemented locally |
| Transactional offline outbox | Source implemented; no server consumer yet |
| Real authenticated multi-phone caregiving | Not implemented |
| Automatic background playback of personal voice | Not implemented |
| 12-language UI and multiple daily reminders | Planned |

## Design notes

- Scheduled notifications remain local and do not depend on internet access.
- A `Taken` action requires explicit confirmation; being notified does not count.
- Same-phone local duplicate confirmations are no-ops; correction appends event.
- Manual medication data entry only. No dose inference, OCR or medical advice.
- Offline outbox is intentionally never labelled “synced” without server ACK.
- Uploaded photos/voice are stored locally, **not yet encrypted at rest**.

Review `docs/architecture.md`, `docs/quality-gates.md` and the proposed
`backend/sql/001_initial.sql` before expanding the app.
