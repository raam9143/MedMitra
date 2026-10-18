# MedMitra — Architecture and feature boundaries

## Current implementation: milestone 1

- Single-device, offline-first Flutter mobile source project.
- SQLite medication store, local actors for demonstration, immutable *application-level* event log, and transactional local outbox.
- One daily reminder time per medicine using system notifications; reschedules on boot through plugin receiver.
- Android exact alarms where user grants permission; otherwise inexact reminders with visible warning.
- Camera image capture, stored in app-private documents; complete custom voice recording and foreground playback.
- Multilingual core UI strings: English/Telugu/Hindi/Tamil; TTS voice availability depends on installed voices.

## Not yet implemented / do not advertise as operational

- Remote accounts, signed identity, multi-device authorization and live synchronization.
- Offline *other-device* synchronization, multi-device conflict resolution and secured pairing.
- Voice automatically speaking in the background when alarm rings; currently system notification sounds, tap to open then press Play.
- Encrypted SQLite and encrypted file-at-rest keys, retention/export and deletion workflows, consent screens.
- Schedules for multiple doses per day, selected weekdays, start/end dates, timezone-change remediation, snooze/escalation.
- Refill, prescription OCR, remote caregiver alerts, hospital/provider integrations.
- Public release hardening and medical-device / health-app compliance review.

## Contract for server synchronization

1. Trusted authentication verifies the person and household membership server-side. Local selector is a demo only.
2. Each device creates a random operation UUID, persists it in `outbox` in the SAME transaction as medication/dose change.
3. Re-send until server commits the operation and acknowledges the exact operation UUID. Mark synced only after acknowledgement.
4. On server, authenticate every request, authorize household & elder, verify medicine belongs to that elder.
5. For medication edits, require expected version and do explicit 409 conflict handling. Keep original and proposed edits visible.
6. For dose confirmations, server transaction locks occurrence, enforces idempotency and records every attempt. Parallel taken confirmations result in one effective dose state, with other attempts shown as conflicts.
7. Keep event time and receipt time separately; never treat an offline phone's timestamp as definitive proof of ingestion.
8. When a schedule changes, elder's phone acknowledges local alarm reprogramming; until that ACK caregiver sees “pending delivery”.
9. Membership revocation applies immediately online; previously authorized offline devices require short-lived local authorization leases or expiring offline rights.
10. If a medicine or dose cannot reconcile, display a conflict and avoid taking a second dose based on sync state.

## Important safety rules

- Information is supplied and verified by user; app makes no dosage recommendations.
- Strength and administered quantity are distinct fields.
- `Taken` requires intentional button confirmation, including actor identity and UTC timestamp.
- Corrections append `reversed` event; never mutate/delete previously recorded dose event via app.
- No automatic double-dose logic; missed/unconfirmed is not “skipped” or “taken”.
- Records with same schedule but changed medicine name preserve confirmation identity; changed schedule generates revision identity.
- Time zone and DST transitions need explicit test and design before public release.

## Security milestones

Production requires server-enforced family identity and roles, encrypted local data, Android Keystore key management, authenticated enrollment, privacy notices, meaningful consent, account deletion, backup policy, threat modeling and security testing.
