# Acceptance and release checklist

## Can be evaluated in development

- `flutter analyze` and `flutter test` pass under a supported Flutter SDK.
- Medication create/update/pause persists after force-stop/restart.
- Local notification is scheduled on Android 12-16 with permissions granted, and an explicit warning appears without exact access.
- Notifications persist or reschedule correctly after reboot and package upgrade.
- Confirmed dose shows actor name and timestamp in history; correction adds second row.
- Repeated tap on Taken never produces multiple *effective* local confirmations.
- Device airplane mode: adding medicine, photo/voice and confirmation work locally; outbox counts pending.
- Localized UI and TTS correctly handle Telugu/Hindi/Tamil supported voices, plus a missing-language fallback message.
- Dark mode, 200% font scaling, TalkBack, 320dp layouts and accessibility labels are manually verified.

## Blockers to production release

- Compile and run on physical Android phones (this package was authored without an installed Flutter SDK or Android toolchain).
- Independently test alarm delivery with app closed, Android Doze and manufacturer battery restrictions.
- Implement & validate server authentication, authorization and family synchronization.
- Secure at-rest health data, media and recordings; implement export/deletion and consent flows.
- Model start/end dates, multiple daily doses, timezone changes, concurrent caregivers and medication replacement.
- Do not promise speech playback at scheduled time in background: that capability is not implemented here.
- Perform threat modeling, privacy review and app-store health declarations.
