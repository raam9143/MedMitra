import 'package:flutter_test/flutter_test.dart';
import 'package:medmitra/core/models.dart';

void main() {
  final medication = Medication(
    id: 'm-123', notificationId: 101, name: 'Example medicine',
    strength: '5 mg', doseAmount: '1', doseUnit: 'tablet',
    instructions: 'After food', hour: 8, minute: 5, language: 'en',
    imagePath: null, audioPath: null, active: true, revision: 1,
    updatedAt: '2026-10-18T00:00:00.000Z',
  );

  test('dose occurrence identity is stable for local calendar date', () {
    final id = occurrenceId(medication, DateTime(2026, 10, 18, 23, 59));
    expect(id, 'm-123:r1:2026-10-18:08:05');
    expect(occurrenceId(medication, DateTime(2026, 10, 18, 1)), id);
    expect(occurrenceId(medication, DateTime(2026, 10, 19)), isNot(id));
  });

  test('cosmetic edit preserves occurrence and audit linkage', () {
    final edit = medication.copyWith(name: 'Updated label', strength: '10 mg');
    expect(edit.revision, 1);
    expect(occurrenceId(edit, DateTime(2026, 10, 18)),
      occurrenceId(medication, DateTime(2026, 10, 18)));
  });

  test('schedule edit creates new occurrence identity', () {
    final edit = medication.copyWith(hour: 9);
    expect(edit.revision, 2);
    expect(occurrenceId(edit, DateTime(2026, 10, 18)), isNot(
      occurrenceId(medication, DateTime(2026, 10, 18))));
  });

  test('local time label includes AM/PM', () {
    expect(medication.timeLabel, '8:05 AM');
    expect(medication.copyWith(hour: 20).timeLabel, '8:05 PM');
  });

  test('roundtrip medication map', () {
    final from = Medication.fromRow(medication.toRow());
    expect(from.id, medication.id);
    expect(from.active, isTrue);
    expect(from.timeLabel, medication.timeLabel);
  });
}
