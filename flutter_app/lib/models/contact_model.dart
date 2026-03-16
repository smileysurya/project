class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? avatarUrl;

  // Language preference (stored locally)
  String language;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.language = 'en',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'phone': phone,
    'email': email, 'language': language,
  };

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'],
    language: json['language'] ?? 'en',
  );
}

class SubtitleEntry {
  final String callId;
  final String senderId;
  final String speakerName;
  final String originalText;
  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final DateTime timestamp;
  final bool isSelf;

  SubtitleEntry({
    required this.callId,
    required this.senderId,
    required this.speakerName,
    required this.originalText,
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.timestamp,
    required this.isSelf,
  });
}
