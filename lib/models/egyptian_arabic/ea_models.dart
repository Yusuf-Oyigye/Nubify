
import 'package:cloud_firestore/cloud_firestore.dart';

//===================================================
// NUBIFY — EGYPTIAN ARABIC SHARED MODELS
//===================================================

class EaDeck {
  const EaDeck({
    required this.id,
    required this.name,
    this.parentDeckId,
    this.createdBy = '',
  });

  final String id;
  final String name;
  final String? parentDeckId;
  final String createdBy;

  factory EaDeck.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    return EaDeck(
      id: doc.id,
      name: (data['name'] ?? 'Untitled deck').toString(),
      parentDeckId: data['parentDeckId'] as String?,
      createdBy: (data['createdBy'] ?? '').toString(),
    );
  }
}

//===================================================
// SHARED CARD + PERSONAL STUDY STATE
//===================================================

class EaCard {
  const EaCard({
    required this.id,
    required this.noteId,
    required this.deckId,
    required this.front,
    required this.arabic,
    required this.transliteration,
    required this.exampleArabic,
    required this.exampleEnglish,
    required this.hint,
    required this.audioUrl,
    required this.reversed,
    required this.schedule,
    required this.dueAt,
    required this.reviewCount,
    required this.lapses,
    required this.suspended,
    this.createdBy = '',
  });

  final String id;
  final String noteId;
  final String deckId;

  final String front;
  final String arabic;
  final String transliteration;

  final String exampleArabic;
  final String exampleEnglish;
  final String hint;

  final String audioUrl;
  final String createdBy;
  final bool reversed;

  final Map<String, dynamic> schedule;
  final DateTime dueAt;
  final int reviewCount;
  final int lapses;
  final bool suspended;

  bool get isNew => reviewCount == 0;

  bool get isDue =>
      !suspended &&
          (isNew || !dueAt.isAfter(DateTime.now()));

  //===================================================
  // USER REQUESTED CARD DISPLAY
  //===================================================

  String get question => front;

  // Arabic script is deliberately not displayed.
  String get answer => transliteration;

  factory EaCard.fromData(
      String id,
      Map<String, dynamic> data,
      ) {
    final rawSchedule = data['schedule'];

    return EaCard(
      id: id,
      noteId: (data['noteId'] ?? '').toString(),
      deckId: (data['deckId'] ?? '').toString(),
      front: (data['front'] ?? '').toString(),
      arabic: (data['arabic'] ?? '').toString(),
      transliteration:
      (data['transliteration'] ?? '').toString(),
      exampleArabic:
      (data['exampleArabic'] ?? '').toString(),
      exampleEnglish:
      (data['exampleEnglish'] ?? '').toString(),
      hint: (data['hint'] ?? '').toString(),
      audioUrl: (data['audioUrl'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      reversed: data['reversed'] == true,
      schedule: rawSchedule is Map
          ? Map<String, dynamic>.from(rawSchedule)
          : <String, dynamic>{},
      dueAt: data['dueAt'] is Timestamp
          ? (data['dueAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      reviewCount:
      (data['reviewCount'] as num?)?.toInt() ?? 0,
      lapses: (data['lapses'] as num?)?.toInt() ?? 0,
      suspended: data['suspended'] == true,
    );
  }

  factory EaCard.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    return EaCard.fromData(
      doc.id,
      doc.data() ?? <String, dynamic>{},
    );
  }
}
