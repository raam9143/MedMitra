import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  bool recording = false;

  Future<String> startRecording() async {
    if (!await _recorder.hasPermission()) throw StateError('Microphone access denied');
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(base.path, 'private_voice'));
    await folder.create(recursive: true);
    final file = p.join(folder.path, '${const Uuid().v4()}.m4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: file);
    recording = true;
    return file;
  }

  Future<String?> stopRecording() async {
    final file = await _recorder.stop();
    recording = false;
    return file;
  }

  Future<void> play(Medication med) async {
    await _player.stop();
    await _tts.stop();
    if (med.audioPath != null && await File(med.audioPath!).exists()) {
      await _player.setFilePath(med.audioPath!);
      await _player.play();
      return;
    }
    final language = {'en': 'en-IN', 'te': 'te-IN', 'hi': 'hi-IN', 'ta': 'ta-IN'}[med.language] ?? 'en-IN';
    // A missing local language TTS engine should fail explicitly rather than
    // silently reading a medicine name in an unintended language.
    final available = await _tts.isLanguageAvailable(language);
    if (available != true && available != 1) {
      throw StateError('The $language voice is not installed on this device');
    }
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.43);
    await _tts.speak(_announcement(med));
  }

  String _announcement(Medication med) {
    final unit = switch (med.language) {
      'te' => switch (med.doseUnit.toLowerCase()) {
        'tablet' || 'tablets' => 'మాత్ర',
        'ml' => 'మిల్లీలీటర్లు',
        _ => med.doseUnit,
      },
      'hi' => switch (med.doseUnit.toLowerCase()) {
        'tablet' || 'tablets' => 'गोली',
        'ml' => 'मिलीलीटर',
        _ => med.doseUnit,
      },
      'ta' => switch (med.doseUnit.toLowerCase()) {
        'tablet' || 'tablets' => 'மாத்திரை',
        'ml' => 'மில்லிலிட்டர்',
        _ => med.doseUnit,
      },
      _ => med.doseUnit,
    };
    final dose = '${med.doseAmount} $unit';
    return switch (med.language) {
      'te' => '${med.timeLabel}. ${med.name} మందు తీసుకునే సమయం వచ్చింది. '
          'మోతాదు $dose. ${med.instructions}',
      'hi' => '${med.timeLabel}. ${med.name} दवाई लेने का समय है। '
          'खुराक $dose। ${med.instructions}',
      'ta' => '${med.timeLabel}. ${med.name} மருந்து எடுக்க வேண்டிய நேரம். '
          'அளவு $dose. ${med.instructions}',
      _ => 'It is ${med.timeLabel}. Time to take ${med.name}. '
          'Dose: $dose. ${med.instructions}',
    };
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
    await _tts.stop();
  }
}
