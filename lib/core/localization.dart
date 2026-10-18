import 'package:flutter/widgets.dart';

/// Core UI strings. Clinical medication details are user-entered and NEVER
/// translated automatically in this initial release.
class MedStrings {
  static const locales = {
    'en': 'English', 'te': 'తెలుగు', 'hi': 'हिन्दी', 'ta': 'தமிழ்',
  };
  static const _dictionary = <String, Map<String, String>>{
    'en': {
      'today': 'Today’s medicines', 'medicine': 'Medicine', 'add': 'Add medicine',
      'taken': 'Taken', 'mark_taken': 'I took this', 'undo': 'Correct entry',
      'manage': 'Manage', 'history': 'History', 'settings': 'Settings',
      'empty': 'No medicines yet. Add a medicine from a prescription.',
      'dose': 'Dose', 'time': 'Time', 'instructions': 'Instructions',
      'member': 'Confirming as', 'preview': 'Play voice reminder',
      'pending': 'Offline changes waiting for sync', 'offline': 'Offline on this phone',
      'save': 'Save', 'cancel': 'Cancel', 'name': 'Medicine name',
      'voice': 'Family voice', 'photo': 'Medicine photo',
      'permission': 'Enable accurate reminders',
      'stop': 'Pause medication', 'start': 'Resume medication',
    },
    'te': {
      'today': 'నేటి మందులు', 'medicine': 'మందు', 'add': 'మందు జోడించండి',
      'taken': 'తీసుకున్నారు', 'mark_taken': 'మందు తీసుకున్నాను', 'undo': 'నమోదు సరిచేయి',
      'manage': 'నిర్వహణ', 'history': 'చరిత్ర', 'settings': 'సెట్టింగ్స్',
      'empty': 'ఇంకా మందులు లేవు. ప్రిస్క్రిప్షన్ ఆధారంగా మందు జోడించండి.',
      'dose': 'మోతాదు', 'time': 'సమయం', 'instructions': 'సూచనలు',
      'member': 'నమోదు చేస్తున్న వ్యక్తి', 'preview': 'వాయిస్ వినండి',
      'pending': 'సింక్ కావాల్సిన ఆఫ్‌లైన్ మార్పులు', 'offline': 'ఈ ఫోన్‌లో ఆఫ్‌లైన్',
      'save': 'సేవ్', 'cancel': 'రద్దు', 'name': 'మందు పేరు',
      'voice': 'కుటుంబ సభ్యుడి వాయిస్', 'photo': 'మందు ఫోటో',
      'permission': 'సమయానుకూల రిమైండర్‌లను ప్రారంభించండి',
      'stop': 'మందును తాత్కాలికంగా ఆపండి', 'start': 'మందు తిరిగి ప్రారంభించండి',
    },
    'hi': {
      'today': 'आज की दवाइयाँ', 'medicine': 'दवाई', 'add': 'दवाई जोड़ें',
      'taken': 'ले ली', 'mark_taken': 'दवाई ले ली', 'undo': 'रिकॉर्ड सुधारें',
      'manage': 'प्रबंधन', 'history': 'इतिहास', 'settings': 'सेटिंग्स',
      'empty': 'अभी कोई दवाई नहीं। पर्चे के अनुसार दवाई जोड़ें।',
      'dose': 'खुराक', 'time': 'समय', 'instructions': 'निर्देश',
      'member': 'पुष्टि करने वाला', 'preview': 'आवाज़ सुनें',
      'pending': 'ऑफ़लाइन बदलाव सिंक होना बाकी', 'offline': 'इस फ़ोन पर ऑफ़लाइन',
      'save': 'सहेजें', 'cancel': 'रद्द करें', 'name': 'दवाई का नाम',
      'voice': 'परिवार की आवाज़', 'photo': 'दवाई की तस्वीर',
      'permission': 'समय पर अलार्म की अनुमति दें',
      'stop': 'दवाई रोकें', 'start': 'दवाई फिर शुरू करें',
    },
    'ta': {
      'today': 'இன்றைய மருந்துகள்', 'medicine': 'மருந்து', 'add': 'மருந்து சேர்',
      'taken': 'எடுத்துக்கொண்டார்', 'mark_taken': 'மருந்து எடுத்தேன்',
      'undo': 'பதிவைத் திருத்து', 'manage': 'நிர்வகி',
      'history': 'வரலாறு', 'settings': 'அமைப்புகள்',
      'empty': 'மருந்துகள் இல்லை. மருந்துச் சீட்டைப் பார்த்துச் சேர்க்கவும்.',
      'dose': 'அளவு', 'time': 'நேரம்', 'instructions': 'வழிமுறைகள்',
      'member': 'உறுதிப்படுத்துபவர்', 'preview': 'குரலைக் கேள்',
      'pending': 'இணைக்கப்படாத மாற்றங்கள்', 'offline': 'இந்த மொபைலில் ஆஃப்லைன்',
      'save': 'சேமி', 'cancel': 'ரத்து', 'name': 'மருந்தின் பெயர்',
      'voice': 'குடும்பக் குரல்', 'photo': 'மருந்து படம்',
      'permission': 'சரியான நேர நினைவூட்டலை இயக்கவும்',
      'stop': 'மருந்தை நிறுத்து', 'start': 'மருந்தை மீண்டும் தொடங்கு',
    },
  };
  final String code;
  const MedStrings(this.code);
  String t(String key) => _dictionary[code]?[key] ?? _dictionary['en']![key] ?? key;
  Locale get locale => Locale(code);
}
