/// Local MVP domain objects. A caregiver selected in this prototype is NOT
/// authenticated: production authorization must be server-verified.
class HouseholdMember {
  final String id;
  final String name;
  final String role;
  const HouseholdMember(this.id, this.name, this.role);
}

class Medication {
  final String id;
  final int notificationId;
  final String name;
  final String strength;
  final String doseAmount;
  final String doseUnit;
  final String instructions;
  final int hour;
  final int minute;
  final String language;
  final String? imagePath;
  final String? audioPath;
  final bool active;
  final int revision;
  final String updatedAt;

  const Medication({
    required this.id,
    required this.notificationId,
    required this.name,
    required this.strength,
    required this.doseAmount,
    required this.doseUnit,
    required this.instructions,
    required this.hour,
    required this.minute,
    required this.language,
    required this.imagePath,
    required this.audioPath,
    required this.active,
    required this.revision,
    required this.updatedAt,
  });

  factory Medication.fromRow(Map<String, Object?> row) => Medication(
    id: row['id'] as String,
    notificationId: row['notification_id'] as int,
    name: row['name'] as String,
    strength: row['strength'] as String,
    doseAmount: row['dose_amount'] as String,
    doseUnit: row['dose_unit'] as String,
    instructions: row['instructions'] as String,
    hour: row['hour'] as int,
    minute: row['minute'] as int,
    language: row['language'] as String,
    imagePath: row['image_path'] as String?,
    audioPath: row['audio_path'] as String?,
    active: (row['active'] as int) == 1,
    revision: row['revision'] as int,
    updatedAt: row['updated_at'] as String,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'notification_id': notificationId,
    'name': name,
    'strength': strength,
    'dose_amount': doseAmount,
    'dose_unit': doseUnit,
    'instructions': instructions,
    'hour': hour,
    'minute': minute,
    'language': language,
    'image_path': imagePath,
    'audio_path': audioPath,
    'active': active ? 1 : 0,
    'revision': revision,
    'updated_at': updatedAt,
  };

  Medication copyWith({
    String? name, String? strength, String? doseAmount, String? doseUnit,
    String? instructions, int? hour, int? minute, String? language,
    String? imagePath, String? audioPath, bool? active,
  }) => Medication(
    id: id, notificationId: notificationId, name: name ?? this.name,
    strength: strength ?? this.strength,
    doseAmount: doseAmount ?? this.doseAmount,
    doseUnit: doseUnit ?? this.doseUnit,
    instructions: instructions ?? this.instructions,
    hour: hour ?? this.hour, minute: minute ?? this.minute,
    language: language ?? this.language,
    imagePath: imagePath ?? this.imagePath, audioPath: audioPath ?? this.audioPath,
    active: active ?? this.active,
    revision: ((hour != null && hour != this.hour) ||
      (minute != null && minute != this.minute)) ? revision + 1 : revision,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
  );

  String get timeLabel {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Local calendar date is part of occurrence identity, never a UTC date.
/// A revised schedule has a new occurrence identity; history is preserved.
String localDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String occurrenceId(Medication medication, DateTime localDate) =>
    '${medication.id}:r${medication.revision}:${localDateKey(localDate)}:'
    '${medication.hour.toString().padLeft(2, '0')}:${medication.minute.toString().padLeft(2, '0')}';

class DoseEvent {
  final String id;
  final String occurrenceId;
  final String medicationId;
  final String actorId;
  final String actorName;
  final String action; // taken or reversed
  final String recordedAtUtc;
  final String deviceId;
  const DoseEvent({
    required this.id, required this.occurrenceId,
    required this.medicationId, required this.actorId,
    required this.actorName, required this.action,
    required this.recordedAtUtc, required this.deviceId,
  });

  factory DoseEvent.fromRow(Map<String, Object?> row) => DoseEvent(
    id: row['id'] as String,
    occurrenceId: row['occurrence_id'] as String,
    medicationId: row['medication_id'] as String,
    actorId: row['actor_id'] as String,
    actorName: row['actor_name'] as String,
    action: row['action'] as String,
    recordedAtUtc: row['recorded_at_utc'] as String,
    deviceId: row['device_id'] as String,
  );

  Map<String, Object?> toRow() => {
    'id': id, 'occurrence_id': occurrenceId,
    'medication_id': medicationId, 'actor_id': actorId,
    'actor_name': actorName, 'action': action,
    'recorded_at_utc': recordedAtUtc, 'device_id': deviceId,
  };
}
