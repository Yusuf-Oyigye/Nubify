
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';

class NubiService {
  NubiService._();

  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  static final FirebaseFunctions functions =
  FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Please sign in to Nubify.');
    }
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>>
  get sources => db
      .collection('users')
      .doc(uid)
      .collection('learningSources');

  static CollectionReference<Map<String, dynamic>>
  get sessions => db
      .collection('users')
      .doc(uid)
      .collection('tutorSessions');

  static CollectionReference<Map<String, dynamic>>
  get quizzes => db
      .collection('users')
      .doc(uid)
      .collection('quizzes');

  static CollectionReference<Map<String, dynamic>>
  get decks => db
      .collection('users')
      .doc(uid)
      .collection('flashcardDecks');

  static DocumentReference<Map<String, dynamic>>
  get progress => db
      .collection('users')
      .doc(uid)
      .collection('xpSummary')
      .doc('current');

  static const int maxUploadBytes = 20 * 1024 * 1024;

  static Future<Map<String, dynamic>> call(
      String function,
      Map<String, dynamic> data, {
        Duration timeout = const Duration(seconds: 180),
      }) async {
    final result = await functions.httpsCallable(
      function,
      options: HttpsCallableOptions(
        timeout: timeout,
      ),
    ).call(data);

    if (result.data is! Map) {
      throw StateError(
        'Invalid response from $function',
      );
    }

    return Map<String, dynamic>.from(
      result.data as Map,
    );
  }

  static Future<Map<String, dynamic>> importFile(
      PlatformFile file,
      ) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw StateError('The file is empty.');
    }

    if (bytes.length > maxUploadBytes) {
      throw StateError(
        'The file exceeds the 20 MB limit.',
      );
    }

    final fingerprint =
    sha256.convert(bytes).toString();

    // Large uploads need longer than the default 180 seconds.
    return call(
      'nubiImport',
      {
        'filename': file.name,
        'sha256': fingerprint,
        'base64': base64Encode(bytes),
      },
      timeout: const Duration(minutes: 5),
    );
  }

  static Future<Map<String, dynamic>> ask({
    required String question,
    String? sourceId,
    int section = 0,
  }) {
    return call('nubiAsk', {
      'question': question,
      'sourceId': ?sourceId,
      'section': section,
    });
  }

  static Future<void> deleteSource(
      String sourceId,
      ) async {
    await call('nubiDeleteSource', {
      'sourceId': sourceId,
    });
  }

  static Future<Map<String, dynamic>>
  createQuiz(
      String sourceId,
      int count,
      ) {
    return call('nubiCreateQuiz', {
      'sourceId': sourceId,
      'count': count,
    });
  }

  static Future<Map<String, dynamic>>
  createFlashcards(String sourceId) {
    return call('nubiCreateFlashcards', {
      'sourceId': sourceId,
    });
  }

  static Future<Map<String, dynamic>>
  submitQuizAnswer(
      String quizId,
      int question,
      int choice,
      ) {
    return call('nubiQuizAnswer', {
      'quizId': quizId,
      'question': question,
      'choice': choice,
    });
  }

  static Future<Map<String, dynamic>>
  reviewFlashcard(
      String deckId,
      int cardIndex,
      String rating,
      ) {
    return call('nubiReviewCard', {
      'deckId': deckId,
      'cardIndex': cardIndex,
      'rating': rating,
    });
  }
}
