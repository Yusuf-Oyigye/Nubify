
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

import 'ea_models.dart';

//===================================================
// NUBIFY EGYPTIAN ARABIC — FIREBASE SERVICE
//===================================================

class EaLearningService {
  EaLearningService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get uid {
    final id = _auth.currentUser?.uid;

    if (id == null) {
      throw StateError(
        'Sign in to use Egyptian Arabic.',
      );
    }

    return id;
  }

  //===================================================
  // SHARED LIBRARY AND PERSONAL FIRESTORE COLLECTIONS
  //===================================================

  DocumentReference<Map<String, dynamic>>
  get _library =>
      _db
          .collection('egyptianArabicShared')
          .doc('library');

  CollectionReference<Map<String, dynamic>>
  get _decks =>
      _library.collection('decks');

  CollectionReference<Map<String, dynamic>>
  get _notes =>
      _library.collection('notes');

  CollectionReference<Map<String, dynamic>>
  get _cards =>
      _library.collection('cards');

  DocumentReference<Map<String, dynamic>>
  get _myProgress =>
      _db
          .collection('egyptianArabicProgress')
          .doc(uid);

  CollectionReference<Map<String, dynamic>>
  get _myCardStates =>
      _myProgress.collection('cards');

  CollectionReference<Map<String, dynamic>>
  get _myReviews =>
      _myProgress.collection('reviews');

  //===================================================
  // FSRS SCHEDULING
  //===================================================

  fsrs.Scheduler scheduler({
    double desiredRetention = 0.9,
  }) {
    return fsrs.Scheduler(
      desiredRetention: desiredRetention,
      learningSteps: const [
        Duration(minutes: 1),
        Duration(minutes: 10),
      ],
      relearningSteps: const [
        Duration(minutes: 10),
      ],
      enableFuzzing: false,
    );
  }

  int _stableFsrsId(String id) {
    var value = 7;

    for (final unit in id.codeUnits) {
      value = (value * 31 + unit) & 0x7FFFFFFF;
    }

    return value == 0 ? 1 : value;
  }

  Map<String, dynamic> _newSchedule(
      String cardId,
      ) {
    return fsrs.Card(
      cardId: _stableFsrsId(cardId),
    ).toMap();
  }

  //===================================================
  // WATCH SHARED DECKS
  //===================================================

  Stream<List<EaDeck>> watchDecks() {
    return _decks.snapshots().map((snapshot) {
      final decks = snapshot.docs
          .map(EaDeck.fromSnapshot)
          .toList();

      decks.sort(
            (a, b) => a.name.compareTo(b.name),
      );

      return decks;
    });
  }

  //===================================================
  // WATCH CARDS WITH INDIVIDUAL STUDENT PROGRESS
  //===================================================

  Stream<List<EaCard>> watchCards() {
    late StreamSubscription<
        QuerySnapshot<Map<String, dynamic>>>
    sharedSubscription;

    late StreamSubscription<
        QuerySnapshot<Map<String, dynamic>>>
    progressSubscription;

    QuerySnapshot<Map<String, dynamic>>?
    sharedSnapshot;

    QuerySnapshot<Map<String, dynamic>>?
    progressSnapshot;

    late final StreamController<List<EaCard>>
    controller;

    void emitCards() {
      if (controller.isClosed ||
          sharedSnapshot == null ||
          progressSnapshot == null) {
        return;
      }

      final personal =
      <String, Map<String, dynamic>>{
        for (final doc in progressSnapshot!.docs)
          doc.id: doc.data(),
      };

      final cards = <EaCard>[];

      for (final doc in sharedSnapshot!.docs) {
        final state = personal[doc.id] ??
            <String, dynamic>{};

        final combined = <String, dynamic>{
          ...doc.data(),
          'schedule': _newSchedule(doc.id),
          'dueAt': Timestamp.fromDate(
            DateTime.now().toUtc(),
          ),
          'reviewCount': 0,
          'lapses': 0,
          'suspended': false,
          ...state,
        };

        cards.add(
          EaCard.fromData(
            doc.id,
            combined,
          ),
        );
      }

      controller.add(cards);
    }

    controller = StreamController<List<EaCard>>(
      onListen: () {
        sharedSubscription =
            _cards.snapshots().listen(
                  (snapshot) {
                sharedSnapshot = snapshot;
                emitCards();
              },
              onError: controller.addError,
            );

        progressSubscription =
            _myCardStates.snapshots().listen(
                  (snapshot) {
                progressSnapshot = snapshot;
                emitCards();
              },
              onError: controller.addError,
            );
      },
      onCancel: () async {
        await sharedSubscription.cancel();
        await progressSubscription.cancel();
      },
    );

    return controller.stream;
  }

  //===================================================
  // PERSONAL REVIEW HISTORY
  //===================================================

  Stream<List<Map<String, dynamic>>>
  watchTodayReviews() {
    final now = DateTime.now();

    final midnight = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return _myReviews
        .where(
      'reviewedAt',
      isGreaterThanOrEqualTo:
      Timestamp.fromDate(midnight),
    )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => <String, dynamic>{
          'id': doc.id,
          ...doc.data(),
        },
      )
          .where(
            (review) =>
        review['undone'] != true,
      )
          .toList();
    });
  }

  //===================================================
  // SHARED DECK MANAGEMENT
  //===================================================

  Future<String> createDeck(
      String name, {
        String? parentDeckId,
      }) async {
    final clean = name.trim();

    if (clean.isEmpty || clean.length > 80) {
      throw StateError(
        'Deck name must be 1–80 characters.',
      );
    }

    if (parentDeckId != null) {
      final parent =
      await _decks.doc(parentDeckId).get();

      if (!parent.exists) {
        throw StateError(
          'Parent deck not found.',
        );
      }
    }

    final ref = _decks.doc();

    await ref.set({
      'name': clean,
      'parentDeckId': parentDeckId,
      'createdBy': uid,
      'createdAt':
      FieldValue.serverTimestamp(),
      'updatedAt':
      FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> renameDeck(
      String deckId,
      String newName,
      ) async {
    final clean = newName.trim();

    if (clean.isEmpty || clean.length > 80) {
      throw StateError(
        'Deck name must be 1–80 characters.',
      );
    }

    final ref = _decks.doc(deckId);
    final snapshot = await ref.get();

    if (!snapshot.exists ||
        snapshot.data()?['createdBy'] != uid) {
      throw StateError(
        'Only the creator can rename this deck.',
      );
    }

    await ref.update({
      'name': clean,
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  //===================================================
  // CREATE SHARED FLASHCARDS
  // ENGLISH FRONT / LATIN PRONUNCIATION BACK
  //===================================================

  Future<void> addNote({
    required String deckId,
    required String front,
    String arabic = '',
    String transliteration = '',
    String exampleArabic = '',
    String exampleEnglish = '',
    String hint = '',
    String audioUrl = '',
    bool addReverse = false,
  }) async {
    final english = front.trim();
    final latin = transliteration.trim();

    if (english.isEmpty) {
      throw StateError(
        'Enter the English word or phrase.',
      );
    }

    if (latin.isEmpty) {
      throw StateError(
        'Enter the Latin pronunciation.',
      );
    }

    final deck =
    await _decks.doc(deckId).get();

    if (!deck.exists) {
      throw StateError(
        'Selected deck no longer exists.',
      );
    }

    final note = _notes.doc();
    final batch = _db.batch();

    final fields = <String, dynamic>{
      'noteId': note.id,
      'deckId': deckId,
      'front': english,
      'arabic': arabic.trim(),
      'transliteration': latin,
      'exampleArabic':
      exampleArabic.trim(),
      'exampleEnglish':
      exampleEnglish.trim(),
      'hint': hint.trim(),
      'audioUrl': audioUrl.trim(),
      'createdBy': uid,
    };

    batch.set(note, {
      ...fields,
      'createdAt':
      FieldValue.serverTimestamp(),
      'updatedAt':
      FieldValue.serverTimestamp(),
    });

    for (
    var i = 0;
    i < (addReverse ? 2 : 1);
    i++
    ) {
      final card = _cards.doc();

      batch.set(card, {
        ...fields,
        'reversed': i == 1,
        'createdAt':
        FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  //===================================================
  // PREVIEW FSRS AGAIN / HARD / GOOD / EASY INTERVALS
  //===================================================

  Map<fsrs.Rating, DateTime> preview(
      EaCard card, {
        double desiredRetention = 0.9,
      }) {
    final engine = scheduler(
      desiredRetention: desiredRetention,
    );

    final now = DateTime.now().toUtc();

    return {
      for (final rating in fsrs.Rating.values)
        rating: engine
            .reviewCard(
          fsrs.Card.fromMap(
            Map<String, dynamic>.from(
              card.schedule,
            ),
          ),
          rating,
          reviewDateTime: now,
        )
            .card
            .due,
    };
  }

  //===================================================
  // GRADE CARD AND UPDATE PERSONAL FSRS PROGRESS
  //===================================================

  Future<void> grade(
      EaCard card,
      fsrs.Rating rating, {
        double desiredRetention = 0.9,
      }) async {
    final sharedRef = _cards.doc(card.id);

    final progressRef =
    _myCardStates.doc(card.id);

    final reviewRef = _myReviews.doc();

    final now = DateTime.now().toUtc();

    final engine = scheduler(
      desiredRetention: desiredRetention,
    );

    await _db.runTransaction(
          (transaction) async {
        final shared =
        await transaction.get(sharedRef);

        final progress =
        await transaction.get(progressRef);

        if (!shared.exists) {
          throw StateError(
            'Shared flashcard not found.',
          );
        }

        final old = progress.data() ??
            <String, dynamic>{};

        if (old['suspended'] == true) {
          throw StateError(
            'This card is suspended.',
          );
        }

        final before = old['schedule'] is Map
            ? Map<String, dynamic>.from(
          old['schedule'] as Map,
        )
            : _newSchedule(card.id);

        final result = engine.reviewCard(
          fsrs.Card.fromMap(before),
          rating,
          reviewDateTime: now,
        );

        final priorCount =
            (old['reviewCount'] as num?)
                ?.toInt() ??
                0;

        final priorLapses =
            (old['lapses'] as num?)
                ?.toInt() ??
                0;

        final newLapses = priorLapses +
            (priorCount > 0 &&
                rating ==
                    fsrs.Rating.again
                ? 1
                : 0);

        transaction.set(progressRef, {
          'cardId': card.id,
          'deckId':
          shared.data()?['deckId'] ??
              card.deckId,
          'schedule':
          result.card.toMap(),
          'dueAt': Timestamp.fromDate(
            result.card.due.toUtc(),
          ),
          'reviewCount': priorCount + 1,
          'lapses': newLapses,
          'suspended': false,
          'lastReviewId': reviewRef.id,
          'updatedAt':
          FieldValue.serverTimestamp(),
        });

        transaction.set(reviewRef, {
          'cardId': card.id,
          'noteId':
          shared.data()?['noteId'] ??
              card.noteId,
          'deckId':
          shared.data()?['deckId'] ??
              card.deckId,
          'rating': rating.name,
          'wasNew': priorCount == 0,
          'before': before,
          'beforeDueAt': old['dueAt'],
          'beforeReviewCount':
          priorCount,
          'beforeLapses': priorLapses,
          'previousReviewId':
          old['lastReviewId'],
          'after': result.card.toMap(),
          'fsrsLog':
          result.reviewLog.toMap(),
          'reviewedAt':
          Timestamp.fromDate(now),
          'undone': false,
        });
      },
    );
  }

  //===================================================
  // UNDO LAST REVIEW
  //===================================================

  Future<void> undoLatest(
      String cardId,
      ) async {
    final progressRef =
    _myCardStates.doc(cardId);

    await _db.runTransaction(
          (transaction) async {
        final progress =
        await transaction.get(progressRef);

        if (!progress.exists) {
          throw StateError(
            'No review to undo.',
          );
        }

        final reviewId =
        progress.data()?['lastReviewId']
        as String?;

        if (reviewId == null) {
          throw StateError(
            'Nothing to undo.',
          );
        }

        final reviewRef =
        _myReviews.doc(reviewId);

        final review =
        await transaction.get(reviewRef);

        if (!review.exists ||
            review.data()?['undone'] == true) {
          throw StateError(
            'The last review cannot be undone.',
          );
        }

        final previous = review.data()!;

        transaction.set(
          progressRef,
          {
            'schedule':
            previous['before'],
            'dueAt':
            previous['beforeDueAt'],
            'reviewCount':
            previous['beforeReviewCount'],
            'lapses':
            previous['beforeLapses'],
            'lastReviewId':
            previous['previousReviewId'],
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );

        transaction.update(reviewRef, {
          'undone': true,
        });
      },
    );
  }

  //===================================================
  // SUSPEND CARDS AND DELETE SHARED NOTES
  //===================================================

  Future<void> setSuspended(
      EaCard card,
      bool suspended,
      ) {
    return _myCardStates.doc(card.id).set(
      {
        'suspended': suspended,
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  Future<void> deleteNote(
      EaCard card,
      ) async {
    final noteRef =
    _notes.doc(card.noteId);

    final note = await noteRef.get();

    if (!note.exists ||
        note.data()?['createdBy'] != uid) {
      throw StateError(
        'Only the uploader can delete this flashcard.',
      );
    }

    final siblings = await _cards
        .where(
      'noteId',
      isEqualTo: card.noteId,
    )
        .get();

    final batch = _db.batch();

    for (final sibling in siblings.docs) {
      batch.delete(
        sibling.reference,
      );
    }

    batch.delete(noteRef);

    await batch.commit();
  }

  //===================================================
  // FIREBASE STORAGE — PRONUNCIATION AUDIO UPLOAD
  //===================================================

  Future<String> uploadAudio(
      String filePath,
      ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      throw StateError(
        'Audio file not found.',
      );
    }

    const maxAudioBytes =
        12 * 1024 * 1024;

    if (await file.length() >
        maxAudioBytes) {
      throw StateError(
        'Audio must be smaller than 12 MB.',
      );
    }

    final extension = filePath
        .split('.')
        .last
        .toLowerCase();

    const mimeTypes = <String, String>{
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
    };

    if (!mimeTypes.containsKey(
      extension,
    )) {
      throw StateError(
        'Choose MP3, M4A, AAC, WAV, OGG or FLAC.',
      );
    }

    final path =
        'egyptianArabicShared/$uid/audio/'
        '${DateTime.now().microsecondsSinceEpoch}'
        '.$extension';

    final reference =
    _storage.ref(path);

    final result =
    await reference.putFile(
      file,
      SettableMetadata(
        contentType:
        mimeTypes[extension],
      ),
    );

    return result.ref.getDownloadURL();
  }
}
