import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../services/reminders.dart';
import '../services/voice.dart';
import 'models.dart';

class MedMitraController extends ChangeNotifier {
  final LocalStore store;
  final ReminderService reminders;
  final VoiceService voice;
  MedMitraController(this.store, this.reminders, this.voice);

  List<Medication> medications = [];
  List<HouseholdMember> family = [];
  List<DoseEvent> history = [];
  Map<String, DoseEvent> latest = {};
  String selectedActorId = 'elder-local';
  String language = 'en';
  int pending = 0;
  bool notificationAllowed = false;
  bool exactAllowed = false;

  HouseholdMember get actor => family.firstWhere(
    (member) => member.id == selectedActorId,
    orElse: () => family.first,
  );

  bool isTaken(Medication med) =>
      latest[occurrenceId(med, DateTime.now())]?.action == 'taken';

  Future<void> initialize() async {
    language = await store.getSetting('locale') ?? 'en';
    selectedActorId = await store.getSetting('member_id') ?? 'elder-local';
    await reminders.initialize();
    await reload();
    try {
      await reminders.rescheduleAll(medications);
    } catch (e) {
      debugPrint('Failed to reschedule some reminders: $e');
    }
    await refreshPermissions();
  }

  Future<void> reload() async {
    medications = await store.medicines(includeInactive: true);
    family = await store.members();
    history = await store.recentEvents();
    latest = await store.latestEvents(DateTime.now());
    pending = await store.pendingCount();
    if (!family.any((member) => member.id == selectedActorId)) {
      selectedActorId = family.first.id;
    }
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    language = code;
    await store.putSetting('locale', code);
    notifyListeners();
  }

  Future<void> selectActor(String id) async {
    if (!family.any((member) => member.id == id)) throw StateError('Unknown local member');
    selectedActorId = id;
    await store.putSetting('member_id', id);
    notifyListeners();
  }

  Future<void> addMember(String name) async {
    await store.addLocalMember(name);
    await reload();
  }

  Future<void> saveMedication(Medication med) async {
    await store.saveMedication(med);
    await reminders.schedule(med);
    await reload();
  }

  Future<void> confirm(Medication med) async {
    await store.setDoseState(medication: med, localDate: DateTime.now(),
      actor: actor, taken: true);
    await reload();
  }

  Future<void> reverse(Medication med) async {
    await store.setDoseState(medication: med, localDate: DateTime.now(),
      actor: actor, taken: false);
    await reload();
  }

  Future<void> refreshPermissions() async {
    notificationAllowed = await reminders.notificationsEnabled();
    exactAllowed = await reminders.canUseExact();
    notifyListeners();
  }

  Future<void> requestPermissions() async {
    await reminders.enableNotifications();
    await reminders.enableExactAlarms();
    await refreshPermissions();
    await reminders.rescheduleAll(medications);
  }

  Future<void> onResume() async {
    final wasExact = exactAllowed;
    await reload();
    await refreshPermissions();
    if (!wasExact && exactAllowed) {
      await reminders.rescheduleAll(medications);
    }
  }

  @override
  void dispose() {
    // VoiceService is owned by the app lifetime.
    super.dispose();
  }
}
