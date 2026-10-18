#!/usr/bin/env python3
"""Local structural checks in environments without a Flutter SDK.

This does NOT replace `flutter analyze`, `flutter test`, Android runtime tests,
or security tests.
"""
from __future__ import annotations
import re
import sqlite3
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]

required = [
    'pubspec.yaml', 'lib/main.dart', 'lib/core/models.dart',
    'lib/core/app_controller.dart', 'lib/core/localization.dart',
    'lib/data/local_store.dart', 'lib/services/reminders.dart',
    'lib/services/voice.dart', 'lib/features/medication_editor.dart',
    'test/domain_test.dart', 'docs/architecture.md',
    'backend/sql/001_initial.sql',
]
for name in required:
    assert (ROOT / name).is_file(), f'missing {name}'

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
parsed = ElementTree.parse(manifest)
root = parsed.getroot()
assert root.tag == 'manifest'
assert root.find('queries') is not None, 'Android TTS queries must be under manifest'
assert root.find('application/queries') is None
ns = '{http://schemas.android.com/apk/res/android}'
perms = {n.attrib[ns + 'name'] for n in root.findall('uses-permission')}
for permission in ['android.permission.SCHEDULE_EXACT_ALARM',
                   'android.permission.RECORD_AUDIO',
                   'android.permission.POST_NOTIFICATIONS',
                   'android.permission.RECEIVE_BOOT_COMPLETED']:
    assert permission in perms, permission
assert root.find('application/receiver') is not None
print('PASS: Android manifest parses and expected permissions/receivers exist')

sql = (ROOT / 'lib/data/local_store.dart').read_text()
statements = re.findall(r"(?:await database.execute\()\s*(?:'''(.*?)'''|'([^']+)')", sql, re.S)
db = sqlite3.connect(':memory:')
for multi, single in statements:
    statement = multi or single
    if not statement.strip():
        continue
    db.execute(statement)
for table in ['medications', 'dose_events', 'outbox', 'members', 'device_metadata']:
    assert db.execute('SELECT count(*) FROM sqlite_master WHERE type="table" AND name=?',
                      [table]).fetchone()[0] == 1, table

db.execute('''INSERT INTO medications VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
  ('med1', 101, 'Sample', '5 mg', '1', 'tablet', 'After meals', 8, 0, 'en', None, None, 1, 1, '2026-10-18T10:00:00Z'))
db.execute('''INSERT INTO dose_events VALUES (?,?,?,?,?,?,?,?)''',
  ('ev1','med1:r1:2026-10-18:08:00','med1','elder-local','Elder','taken','2026-10-18T08:00:00Z','device1'))
db.execute('''INSERT INTO outbox VALUES (?,?,?,?,?)''',
  ('ev1','dose_event','{}','2026-10-18T08:00:00Z','pending'))
assert db.execute('SELECT count(*) FROM outbox WHERE state="pending"').fetchone()[0] == 1
assert db.execute('SELECT action FROM dose_events WHERE occurrence_id=?',
                  ['med1:r1:2026-10-18:08:00']).fetchone()[0] == 'taken'
db.execute('''INSERT INTO dose_events VALUES (?,?,?,?,?,?,?,?)''',
  ('ev2','med1:r1:2026-10-18:08:00','med1','caregiver1','Caregiver','reversed','2026-10-18T08:20:00Z','device1'))
assert db.execute('SELECT count(*) FROM dose_events').fetchone()[0] == 2
print('PASS: Local SQLite schema executes; medication, event, correction and outbox inserts work')

files = [p for p in (ROOT / 'lib').rglob('*.dart')]
assert len(files) >= 6
for file in files:
    content = file.read_text()
    assert '\t' not in content, f'tab in {file}'
    assert 'TODO(' not in content, f'untracked TODO in {file}'
    for imp in re.findall(r"^import '\.\./([^']+)'", content, re.M):
        path = (file.parent / '..' / imp).resolve()
        assert path.exists(), f'broken import: {file}: {imp}'
print(f'PASS: {len(files)} Dart source files and relative imports inspected')
print('WARNING: Flutter/Dart compiler unavailable: no compile, runtime or device validation performed')
