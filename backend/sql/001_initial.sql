-- FUTURE multi-user backend schema; NOT YET DEPLOYED OR CONNECTED.
-- Expected server database: PostgreSQL 16+. Use authenticated APIs with
-- household-scoped authorization, not direct client database access.
BEGIN;
CREATE TABLE app_users (
  id UUID PRIMARY KEY,
  phone_e164 TEXT UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE households (
  id UUID PRIMARY KEY,
  display_name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES app_users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE household_members (
  household_id UUID NOT NULL REFERENCES households(id),
  user_id UUID NOT NULL REFERENCES app_users(id),
  role TEXT NOT NULL CHECK(role IN ('owner','caregiver','elder')),
  membership_status TEXT NOT NULL CHECK(membership_status IN ('invited','active','revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (household_id, user_id)
);
CREATE TABLE elder_profiles (
  id UUID PRIMARY KEY,
  household_id UUID NOT NULL REFERENCES households(id),
  display_name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (id, household_id)
);
CREATE TABLE medications (
  id UUID PRIMARY KEY,
  elder_id UUID NOT NULL REFERENCES elder_profiles(id),
  name TEXT NOT NULL,
  strength TEXT NOT NULL,
  dose_amount TEXT NOT NULL,
  dose_unit TEXT NOT NULL,
  instructions TEXT NOT NULL,
  language TEXT NOT NULL,
  schedule_json JSONB NOT NULL,
  photo_object_key TEXT,
  voice_object_key TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  version BIGINT NOT NULL DEFAULT 1,
  edited_by UUID NOT NULL REFERENCES app_users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE dose_occurrences (
  id TEXT PRIMARY KEY,
  medication_id UUID NOT NULL REFERENCES medications(id),
  elder_local_date DATE NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','taken','reversed','skipped')) DEFAULT 'pending',
  version BIGINT NOT NULL DEFAULT 0,
  UNIQUE(medication_id, elder_local_date, scheduled_at)
);
CREATE TABLE dose_events (
  id UUID PRIMARY KEY,
  occurrence_id TEXT NOT NULL REFERENCES dose_occurrences(id),
  actor_id UUID NOT NULL REFERENCES app_users(id),
  action TEXT NOT NULL CHECK(action IN ('taken','reversed','skipped')),
  client_recorded_at TIMESTAMPTZ NOT NULL,
  server_received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  originating_device_id UUID NOT NULL,
  operation_id UUID NOT NULL UNIQUE,
  previous_version BIGINT NOT NULL,
  -- Version conflicts are recorded, not silently merged.
  reconciliation_status TEXT NOT NULL CHECK(reconciliation_status IN ('accepted','conflict'))
);
CREATE INDEX idx_dose_events_occurrence ON dose_events(occurrence_id, server_received_at);
CREATE TABLE sync_operations (
  operation_id UUID PRIMARY KEY,
  actor_id UUID NOT NULL REFERENCES app_users(id),
  household_id UUID NOT NULL REFERENCES households(id),
  operation_type TEXT NOT NULL,
  request_json JSONB NOT NULL,
  response_json JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE audit_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  household_id UUID NOT NULL REFERENCES households(id),
  actor_id UUID NOT NULL REFERENCES app_users(id),
  action TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);
COMMIT;
