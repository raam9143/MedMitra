import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/localization.dart';
import 'core/models.dart';
import 'data/local_store.dart';
import 'features/medication_editor.dart';
import 'services/reminders.dart';
import 'services/voice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final controller = MedMitraController(store, ReminderService(), VoiceService());
  await controller.initialize();
  runApp(MedMitraApp(controller: controller));
}

class MedMitraApp extends StatelessWidget {
  final MedMitraController controller;
  const MedMitraApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) => MaterialApp(
      title: 'MedMitra', debugShowCheckedModeBanner: false,
      locale: Locale(controller.language),
      theme: ThemeData(
        useMaterial3: true, colorSchemeSeed: const Color(0xFF087E7B),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF6F8FA)),
        cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6),
          elevation: 0, shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFDCE5E9)))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52), textStyle: const TextStyle(fontSize: 17))),
      ),
      home: MedMitraHome(controller: controller),
    ),
  );
}

class MedMitraHome extends StatefulWidget {
  final MedMitraController controller;
  const MedMitraHome({super.key, required this.controller});
  @override
  State<MedMitraHome> createState() => _MedMitraHomeState();
}

class _MedMitraHomeState extends State<MedMitraHome> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _timer;
  MedMitraController get controller => widget.controller;
  MedStrings get t => MedStrings(controller.language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => controller.reload());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.onResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _message(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _edit([Medication? med]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => MedicationEditor(controller: controller, initial: med),
    ));
  }

  Future<void> _confirm(Medication med) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm medication taken'),
        content: Text('Record that ${med.name} (${med.doseAmount} ${med.doseUnit}) '
            'was actually taken?\n\nConfirming as ${controller.actor.name}. '
            'Never confirm an uncertain dose.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm taken')),
        ],
      ),
    );
    if (approved != true) return;
    try { await controller.confirm(med); }
    catch (e) { _message(e); }
  }

  Future<void> _reverse(Medication med) async {
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Correct previous confirmation?'),
      content: Text('This adds an auditable correction for ${med.name}. '
          'It does not delete the earlier record.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Correct record')),
      ],
    ));
    if (approved != true) return;
    try { await controller.reverse(med); }
    catch (e) { _message(e); }
  }

  Future<void> _play(Medication med) async {
    try { await controller.voice.play(med); }
    catch (e) { _message(e); }
  }

  Future<void> _setActive(Medication med) async {
    try { await controller.saveMedication(med.copyWith(active: !med.active)); }
    catch (e) { _message(e); }
  }

  Widget _medImage(Medication medication) {
    final image = medication.imagePath;
    return Container(
      width: 82, height: 82,
      decoration: BoxDecoration(color: const Color(0xFFE9F3F2),
          borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: image != null && File(image).existsSync()
          ? Image.file(File(image), fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const Icon(Icons.medication, size: 42))
          : const Icon(Icons.medication_outlined, color: Color(0xFF087E7B), size: 42),
    );
  }

  Widget _medicineCard(Medication med, {bool management = false}) {
    final taken = controller.isTaken(med);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _medImage(med), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(med.timeLabel, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 21, color: Color(0xFF087E7B))),
            Text(med.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21)),
            if (med.strength.isNotEmpty) Text(med.strength,
              style: const TextStyle(color: Color(0xFF52636C))),
            Text('${t.t('dose')}: ${med.doseAmount} ${med.doseUnit}',
              style: const TextStyle(fontSize: 17)),
            if (med.instructions.isNotEmpty) Text(med.instructions,
              style: const TextStyle(fontSize: 15)),
            if (!med.active) const Text('Paused', style: TextStyle(color: Colors.orange)),
          ])),
        ]),
        const SizedBox(height: 10),
        if (management) Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: () => _edit(med),
            icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
          OutlinedButton.icon(onPressed: () => _setActive(med),
            icon: Icon(med.active ? Icons.pause_circle_outline : Icons.play_circle_outline),
            label: Text(t.t(med.active ? 'stop' : 'start'))),
        ])
        else Row(children: [
          Expanded(child: taken
            ? OutlinedButton.icon(onPressed: () => _reverse(med),
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: Text(t.t('taken'), style: const TextStyle(fontSize: 16)))
            : FilledButton.icon(onPressed: () => _confirm(med),
                icon: const Icon(Icons.check), label: Text(t.t('mark_taken')))),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: t.t('preview'), iconSize: 28,
            onPressed: () => _play(med), icon: const Icon(Icons.volume_up)),
        ]),
        if (taken && !management) Align(alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => _reverse(med), child: Text(t.t('undo')))),
      ],
    )));
  }

  Widget _actorSelector() {
    return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        const Icon(Icons.account_circle_outlined), const SizedBox(width: 12),
        Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          isExpanded: true, value: controller.selectedActorId,
          items: controller.family.map((member) => DropdownMenuItem<String>(
            value: member.id, child: Text(member.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (id) { if (id != null) controller.selectActor(id); },
        ))),
      ]),
    ));
  }

  Widget _today() {
    final medicines = controller.medications.where((m) => m.active).toList();
    final totalTaken = medicines.where(controller.isTaken).length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Text(t.t('today'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('$totalTaken of ${medicines.length} scheduled doses confirmed today',
          style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 8),
      _actorSelector(),
      if (!controller.notificationAllowed || !controller.exactAllowed)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8), Expanded(child: Text('Reminder permissions need attention',
                  style: TextStyle(fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 6),
            Text(!controller.notificationAllowed
              ? 'Notifications are not enabled; alarms may be invisible.'
              : 'Exact timing not enabled; reminders may arrive late.'),
            TextButton(onPressed: () async {
              try { await controller.requestPermissions(); } catch (e) { _message(e); }
            }, child: Text(t.t('permission'))),
          ],
        ))),
      const SizedBox(height: 10),
      if (medicines.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Icon(Icons.medication_liquid_outlined, size: 64),
          const SizedBox(height: 16), Text(t.t('empty'), textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => _edit(),
            icon: const Icon(Icons.add), label: Text(t.t('add'))),
        ])))
      else ...medicines.map(_medicineCard),
      const SizedBox(height: 10),
      Text('Only confirm medication that was actually taken. '
          'Do not double a missed dose without medical instructions.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _management() => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
    FilledButton.icon(onPressed: () => _edit(),
        icon: const Icon(Icons.add), label: Text(t.t('add'))),
    const SizedBox(height: 12),
    ...controller.medications.map((m) => _medicineCard(m, management: true)),
  ]);

  Widget _history() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Dose audit trail', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 6),
    const Text('Past confirmations and corrections are retained; records are never edited in place.'),
    const SizedBox(height: 14),
    if (controller.history.isEmpty)
      const Card(child: Padding(padding: EdgeInsets.all(24),
        child: Text('No dose confirmations recorded yet.'))),
    ...controller.history.map((event) {
      final medicine = controller.medications.where((m) => m.id == event.medicationId);
      final localStamp = DateTime.tryParse(event.recordedAtUtc)?.toLocal();
      return Card(child: ListTile(
        isThreeLine: true,
        leading: Icon(event.action == 'taken' ? Icons.check_circle : Icons.history,
          color: event.action == 'taken' ? Colors.green : Colors.orange),
        title: Text('${medicine.isNotEmpty ? medicine.first.name : 'Medicine'} • '
            '${event.action == 'taken' ? 'Taken' : 'Corrected'}'),
        subtitle: Text('${event.actorName}\n${localStamp ?? event.recordedAtUtc} (device time)'),
      ));
    }),
  ]);

  Future<void> _addMember() async {
    final text = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add local caregiver (prototype)'),
      content: TextField(controller: text, autofocus: true,
        decoration: const InputDecoration(labelText: 'Caregiver display name')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, text.text.trim()),
          child: const Text('Add'))],
    ));
    text.dispose();
    if (value == null || value.isEmpty) return;
    try { await controller.addMember(value); } catch (e) { _message(e); }
  }

  Widget _family() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Family & accessibility', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LOCAL PROTOTYPE — NOT REMOTE AUTHORIZED ACCESS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 6),
        const Text('Names here are demo identities on this phone only. '
          'Production caregiver sign-in, invitations and remote sync are not built yet.'),
        const SizedBox(height: 8),
        Text('${controller.pending} ${t.t('pending').toLowerCase()}'),
        Text(t.t('offline'), style: Theme.of(context).textTheme.bodySmall),
      ],
    ))),
    const SizedBox(height: 8),
    ...controller.family.map((member) => Card(child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(member.name), subtitle: Text(member.role),
      trailing: member.id == controller.selectedActorId ? const Icon(Icons.check_circle) : null,
      onTap: () => controller.selectActor(member.id),
    ))),
    OutlinedButton.icon(onPressed: _addMember,
      icon: const Icon(Icons.person_add_alt_1), label: const Text('Add local caregiver')),
    const SizedBox(height: 18),
    Text('App language', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6),
    DropdownButtonFormField<String>(
      initialValue: controller.language,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: MedStrings.locales.entries.map((entry) => DropdownMenuItem(
        value: entry.key, child: Text(entry.value))).toList(),
      onChanged: (code) { if (code != null) controller.setLanguage(code); },
    ),
    const SizedBox(height: 18),
    const Text('Medicine records and voice recordings are stored on this device. '
      'Do not use shared or unlocked phones for private medical information.'),
  ]);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (ctx, _) {
    final headings = [t.t('today'), t.t('manage'), t.t('history'), t.t('settings')];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.favorite_outline), SizedBox(width: 10),
          Text('MedMitra', style: TextStyle(fontWeight: FontWeight.bold))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 12),
          child: Center(child: Text(headings[_tab], style: const TextStyle(fontSize: 14))))],
      ),
      body: IndexedStack(index: _tab, children: [_today(), _management(), _history(), _family()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today), label: t.t('today')),
          NavigationDestination(icon: const Icon(Icons.medication_outlined),
            selectedIcon: const Icon(Icons.medication), label: t.t('manage')),
          NavigationDestination(icon: const Icon(Icons.history), label: t.t('history')),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), label: t.t('settings')),
        ],
      ),
    );
  });
}
