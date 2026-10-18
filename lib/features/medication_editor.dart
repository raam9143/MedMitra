import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_controller.dart';
import '../core/localization.dart';
import '../core/models.dart';

class MedicationEditor extends StatefulWidget {
  final MedMitraController controller;
  final Medication? initial;
  const MedicationEditor({super.key, required this.controller, this.initial});

  @override
  State<MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<MedicationEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _strength;
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _instructions;
  late TimeOfDay _time;
  late String _language;
  String? _image;
  String? _audio;
  bool _recording = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final med = widget.initial;
    _name = TextEditingController(text: med?.name ?? '');
    _strength = TextEditingController(text: med?.strength ?? '');
    _amount = TextEditingController(text: med?.doseAmount ?? '1');
    _unit = TextEditingController(text: med?.doseUnit ?? 'tablet');
    _instructions = TextEditingController(text: med?.instructions ?? '');
    _time = TimeOfDay(hour: med?.hour ?? 8, minute: med?.minute ?? 0);
    _language = med?.language ?? widget.controller.language;
    _image = med?.imagePath;
    _audio = med?.audioPath;
  }

  @override
  void dispose() {
    _name.dispose(); _strength.dispose(); _amount.dispose();
    _unit.dispose(); _instructions.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera,
          imageQuality: 78, maxWidth: 1200);
      if (image == null) return;
      final root = await getApplicationDocumentsDirectory();
      final dest = Directory(p.join(root.path, 'medicine_photos'));
      await dest.create(recursive: true);
      final file = await File(image.path).copy(p.join(dest.path, '${const Uuid().v4()}.jpg'));
      setState(() => _image = file.path);
    } catch (e) { _error(e); }
  }

  Future<void> _recordToggle() async {
    try {
      if (_recording) {
        final file = await widget.controller.voice.stopRecording();
        if (mounted) setState(() { _recording = false; _audio = file; });
      } else {
        await widget.controller.voice.startRecording();
        if (mounted) setState(() => _recording = true);
      }
    } catch (e) { _error(e); }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_recording) { _error('Stop recording before saving'); return; }
    setState(() => _busy = true);
    try {
      final previous = widget.initial;
      final medication = previous == null
          ? Medication(
              id: const Uuid().v4(),
              notificationId: await widget.controller.store.allocateNotificationId(),
              name: _name.text.trim(), strength: _strength.text.trim(),
              doseAmount: _amount.text.trim(), doseUnit: _unit.text.trim(),
              instructions: _instructions.text.trim(),
              hour: _time.hour, minute: _time.minute,
              language: _language, imagePath: _image, audioPath: _audio,
              active: true, revision: 1,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            )
          : previous.copyWith(
              name: _name.text.trim(), strength: _strength.text.trim(),
              doseAmount: _amount.text.trim(), doseUnit: _unit.text.trim(),
              instructions: _instructions.text.trim(), hour: _time.hour,
              minute: _time.minute, language: _language,
              imagePath: _image, audioPath: _audio,
            );
      await widget.controller.saveMedication(medication);
      if (mounted) Navigator.of(context).pop();
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = MedStrings(widget.controller.language);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? t.t('add') : 'Edit medicine')),
      body: SafeArea(child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Enter exactly as prescribed',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(controller: _name, decoration: InputDecoration(
              labelText: '${t.t('name')} *', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _strength, decoration: const InputDecoration(
              labelText: 'Strength on label (e.g. 5 mg)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _amount,
              decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
              validator: (v) {
                final amount = double.tryParse((v ?? '').trim());
                return amount == null || amount <= 0 ? 'Enter positive quantity' : null;
              })),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit (tablet / mL) *',
                border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _instructions, maxLines: 2,
              decoration: InputDecoration(labelText: t.t('instructions'),
                hintText: 'As directed by prescriber', border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          Card(child: ListTile(
            leading: const Icon(Icons.schedule, size: 30),
            title: Text(t.t('time')),
            subtitle: Text(_time.format(context), style: const TextStyle(fontSize: 22)),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: _time);
              if (time != null) setState(() => _time = time);
            },
          )),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Voice language', border: OutlineInputBorder()),
            items: MedStrings.locales.entries.map((entry) => DropdownMenuItem(
              value: entry.key, child: Text(entry.value))).toList(),
            onChanged: (value) { if (value != null) setState(() => _language = value); },
          ),
          const SizedBox(height: 12),
          Card(child: ListTile(
            leading: _image != null && File(_image!).existsSync()
                ? Image.file(File(_image!), width: 58, height: 58, fit: BoxFit.cover)
                : const Icon(Icons.camera_alt_outlined, size: 32),
            title: Text(t.t('photo')),
            subtitle: Text(_image != null ? 'Photo selected' : 'Capture medicine package'),
            trailing: const Icon(Icons.add_a_photo_outlined), onTap: _pickImage,
          )),
          Card(child: ListTile(
            leading: Icon(_recording ? Icons.stop_circle : Icons.mic, size: 32),
            title: Text(t.t('voice')),
            subtitle: Text(_recording ? 'Recording… tap to stop' :
                _audio == null ? 'Record a complete reminder' : 'Recording saved locally'),
            onTap: _recordToggle,
          )),
          const SizedBox(height: 12),
          Text('Daily reminders only in this first milestone. No automated medication advice.',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Padding(padding: const EdgeInsets.all(12), child: Text(t.t('save')))),
        ]),
      )),
    );
  }
}
