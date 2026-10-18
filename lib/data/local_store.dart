import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';

const _uuid = Uuid();

class LocalStore {
  final Database db;
  const LocalStore(this.db);

  static Future<LocalStore> open() async {
    final base = await getDatabasesPath();
    final db = await openDatabase(
      p.join(base, 'medmitra_v1.sqlite'),
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE medications (
            id TEXT PRIMARY KEY, notification_id INTEGER NOT NULL UNIQUE,
            name TEXT NOT NULL, strength TEXT NOT NULL,
            dose_amount TEXT NOT NULL, dose_unit TEXT NOT NULL,
            instructions TEXT NOT NULL, hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23),
            minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59),
            language TEXT NOT NULL, image_path TEXT, audio_path TEXT,
            active INTEGER NOT NULL CHECK(active IN (0, 1)),
            revision INTEGER NOT NULL, updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE members (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE dose_events (
            id TEXT PRIMARY KEY, occurrence_id TEXT NOT NULL,
            medication_id TEXT NOT NULL, actor_id TEXT NOT NULL,
            actor_name TEXT NOT NULL, action TEXT NOT NULL
              CHECK(action IN ('taken', 'reversed')),
            recorded_at_utc TEXT NOT NULL, device_id TEXT NOT NULL
          )
        ''');
        await database.execute('CREATE INDEX idx_dose_occurrence ON dose_events(occurrence_id)');
        await database.execute('''
          CREATE TABLE outbox (
            operation_id TEXT PRIMARY KEY, event_type TEXT NOT NULL,
            payload_json TEXT NOT NULL, created_at_utc TEXT NOT NULL,
            state TEXT NOT NULL CHECK(state IN ('pending', 'synced')) DEFAULT 'pending'
          )
        ''');
        await database.execute('''
          CREATE TABLE device_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)
        ''');
        await database.insert('members', {'id': 'elder-local', 'name': 'Elder (this phone)', 'role': 'elder'});
        await database.insert('device_metadata', {'key': 'device_id', 'value': _uuid.v4()});
        await database.insert('device_metadata', {'key': 'next_notification_id', 'value': '100'});
      },
    );
    return LocalStore(db);
  }

  Future<String> deviceId() async =>
      (await db.query('device_metadata', where: 'key = ?', whereArgs: ['device_id']))
          .first['value'] as String;


  Future<String?> getSetting(String key) async {
    final rows = await db.query('device_metadata', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> putSetting(String key, String value) async {
    await db.insert('device_metadata', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Medication>> medicines({bool includeInactive = false}) async =>
      (await db.query('medications',
          where: includeInactive ? null : 'active = 1',
          orderBy: 'hour ASC, minute ASC, name COLLATE NOCASE ASC'))
          .map(Medication.fromRow).toList();

  Future<List<HouseholdMember>> members() async => (await db.query('members'))
      .map((row) => HouseholdMember(row['id'] as String,
          row['name'] as String, row['role'] as String)).toList();

  /// Prototype-only local member (no identity verification).
  Future<void> addLocalMember(String name) async {
    if (name.trim().isEmpty) throw ArgumentError('Member name is required');
    await db.insert('members', {'id': _uuid.v4(), 'name': name.trim(), 'role': 'caregiver'});
  }

  Future<int> allocateNotificationId() async => db.transaction((txn) async {
    final row = (await txn.query('device_metadata', where: 'key = ?',
      whereArgs: ['next_notification_id'])).first;
    final current = int.parse(row['value'] as String);
    await txn.update('device_metadata', {'value': '${current + 1}'},
      where: 'key = ?', whereArgs: ['next_notification_id']);
    return current;
  });

  Future<void> saveMedication(Medication medication) async {
    if (medication.name.trim().isEmpty || medication.doseAmount.trim().isEmpty ||
        medication.doseUnit.trim().isEmpty) {
      throw ArgumentError('Medication and dose details are required');
    }
    await db.transaction((txn) async {
      await txn.insert('medications', medication.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
      await _enqueue(txn, 'medication_upsert', medication.toRow());
    });
  }

  Future<Map<String, DoseEvent>> latestEvents(DateTime localDate) async {
    final rows = await db.rawQuery('''
      SELECT e.* FROM dose_events e
      INNER JOIN (
        SELECT occurrence_id, MAX(rowid) AS last_row
        FROM dose_events GROUP BY occurrence_id
      ) latest ON e.rowid = latest.last_row
      WHERE e.occurrence_id LIKE ?
    ''', ['%:${localDateKey(localDate)}:%']);
    return {for (final row in rows) row['occurrence_id'] as String: DoseEvent.fromRow(row)};
  }

  Future<List<DoseEvent>> recentEvents({int limit = 100}) async =>
      (await db.query('dose_events', orderBy: 'rowid DESC', limit: limit))
          .map(DoseEvent.fromRow).toList();

  /// The transaction serializes local writes. A second "Taken" becomes a no-op,
  /// while reversing requires a separate immutable event. A remote server must
  /// perform its OWN transaction and idempotency check after synchronization.
  Future<DoseEvent?> setDoseState({
    required Medication medication,
    required DateTime localDate,
    required HouseholdMember actor,
    required bool taken,
  }) async {
    final occurrence = occurrenceId(medication, localDate);
    final localDeviceId = await deviceId();
    return db.transaction((txn) async {
      final previous = await txn.query('dose_events',
          where: 'occurrence_id = ?', whereArgs: [occurrence],
          orderBy: 'rowid DESC', limit: 1);
      final wasTaken = previous.isNotEmpty && previous.first['action'] == 'taken';
      if (wasTaken == taken) return null;
      final event = DoseEvent(
        id: _uuid.v4(), occurrenceId: occurrence,
        medicationId: medication.id, actorId: actor.id, actorName: actor.name,
        action: taken ? 'taken' : 'reversed',
        recordedAtUtc: DateTime.now().toUtc().toIso8601String(),
        deviceId: localDeviceId,
      );
      await txn.insert('dose_events', event.toRow());
      await _enqueue(txn, 'dose_event', event.toRow(), operationId: event.id);
      return event;
    });
  }

  Future<int> pendingCount() async => Sqflite.firstIntValue(await db.rawQuery(
    "SELECT COUNT(*) FROM outbox WHERE state = 'pending'")) ?? 0;

  /// No fake "synced" operations: the outbox stays pending until a real
  /// authenticated backend acknowledges each operation ID.
  Future<void> _enqueue(Transaction txn, String type, Map<String, Object?> body,
      {String? operationId}) async {
    await txn.insert('outbox', {
      'operation_id': operationId ?? _uuid.v4(),
      'event_type': type, 'payload_json': jsonEncode(body),
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      'state': 'pending',
    });
  }
}
