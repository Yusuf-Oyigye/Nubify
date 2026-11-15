
"use strict";

const {onCall, HttpsError} =
  require("firebase-functions/v2/https");

const C = require("./nubi_core");

const {
  db, now, userId, sourceRef,
  callableOptions, stringValue,
  hash, generateText, generateJson,
  extractDocument, grantXp, XP,
} = C;

function fail(message) {
  throw new HttpsError(
    "failed-precondition",
    message,
  );
}

async function requireSource(uid, sourceId) {
  const ref = sourceRef(uid, sourceId);
  const snap = await ref.get();

  if (!snap.exists ||
      snap.data().status !== "ready") {
    fail("Lecture not found or not ready.");
  }
  return {ref, data: snap.data()};
}

function sectionOf(source, index) {
  const sections = source.sections || [];
  if (!Number.isInteger(index) ||
      index < 0 || index >= sections.length) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid lesson section.",
    );
  }
  return sections[index];
}

function normalizeQuestions(items, max) {
  if (!Array.isArray(items)) fail("No questions generated.");

  const questions = items.slice(0, max).map((item) => {
    const options = item.options;
    const answer = Number(item.correctIndex);

    if (!Array.isArray(options) ||
        options.length !== 4 ||
        !Number.isInteger(answer) ||
        answer < 0 || answer > 3) {
      fail("Invalid question structure.");
    }

    return {
      question: stringValue(item.question, 350),
      options: options.map((o) =>
        stringValue(o, 200),
      ),
      correctIndex: answer,
      explanation: stringValue(
        item.explanation, 450,
      ),
      topic: stringValue(item.topic, 100),
    };
  });

  if (questions.length === 0 ||
      questions.some((q) =>
        !q.question || q.options.some((o) => !o),
      )) {
    fail("Question validation failed.");
  }

  return questions;
}

exports.nubiImport = onCall(
  // Uploads of up to 20 MB need longer than the default 180 seconds.
  {...callableOptions, timeoutSeconds: 300},
  async (request) => {
    const uid = userId(request);
    const filename = stringValue(
      request.data.filename, 160,
    );
    const base64 = request.data.base64;

    if (!filename ||
        typeof base64 !== "string" ||
        base64.length > 28_000_000) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid file upload.",
      );
    }

    const buffer = Buffer.from(base64, "base64");
    const fingerprint = hash(buffer);

    if (fingerprint !== request.data.sha256) {
      throw new HttpsError(
        "invalid-argument",
        "File fingerprint mismatch.",
      );
    }

    const ref = sourceRef(uid, fingerprint);

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);

      if (existing.exists) {
        throw new HttpsError(
          "already-exists",
          "This lecture already exists.",
        );
      }

      tx.create(ref, {
        title: filename,
        sha256: fingerprint,
        status: "processing",
        createdAt: now(),
      });
    });

    try {
      const extracted = await extractDocument(
        filename,
        buffer,
      );

      const structure = await generateJson(
        uid,
        `You are NUBi, a medical university tutor.
Read the following lecture carefully.
Return JSON with:
{
 "subject": "string",
 "sections": [
   {"title":"string","brief":"string"}
 ]
}
Provide 4 to 12 ordered, source-grounded
sections, depending on content.
Include essential definitions, classifications,
mechanisms and clinically important facts.
Do not invent information.
Write concise briefs.
SOURCE:
${extracted.text}`,
        3500,
      );

      if (!Array.isArray(structure.sections) ||
          structure.sections.length === 0) {
        fail("Could not extract learning sections.");
      }

      const sections = structure.sections
        .slice(0, 12)
        .map((section, index) => ({
          id: index,
          title: stringValue(
            section.title, 120,
          ),
          brief: stringValue(
            section.brief, 1800,
          ),
        }));

      if (sections.some((s) =>
        !s.title || !s.brief,
      )) {
        fail("Incomplete learning structure.");
      }

      await ref.update({
        subject: stringValue(
          structure.subject, 120,
        ),
        sections,
        totalSections: sections.length,
        completedSections: [],
        currentSection: 0,
        status: "ready",
        sourcePages: extracted.pages,
        contextWarning:
          "Original file is not retained. "
          + "Briefs may omit original details.",
        updatedAt: now(),
      });

      return {
        sourceId: fingerprint,
        title: filename,
        sections: sections.length,
      };
    } catch (error) {
      await ref.delete().catch(() => {});
      throw error;
    }
  },
);

exports.nubiAsk = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const question = stringValue(
      request.data.question, 1200,
    );
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );
    const sectionIndex =
      Number(request.data.section || 0);

    if (!question) {
      throw new HttpsError(
        "invalid-argument",
        "Question is required.",
      );
    }

    let context = "";

    if (sourceId) {
      const {data} =
        await requireSource(uid, sourceId);
      const section =
        sectionOf(data, sectionIndex);

      context = `Lecture: ${data.title}
Section: ${section.title}
Saved brief: ${section.brief}`;
    }

    const answer = await generateText(
      uid,
      `You are NUBi, an accurate university
learning assistant. Be clear, concise,
interactive, and helpful.
For questions about a supplied lecture,
use only its saved brief. If it is missing
the answer, say that the saved context
is incomplete. Do not fabricate citations.
${context}
Student question: ${question}`,
      1100,
    );

    const requestedId = stringValue(
      request.data.sessionId, 100,
    );

    const sessions = db.collection(
      `users/${uid}/tutorSessions`,
    );

    const sessionRef = requestedId
      ? sessions.doc(requestedId)
      : sessions.doc();

    if (requestedId) {
      const existing = await sessionRef.get();
      if (!existing.exists ||
          existing.data().sourceId !== sourceId) {
        fail("Invalid tutoring session.");
      }
    } else {
      await sessionRef.set({
        sourceId,
        title: sourceId
          ? "Lecture tutoring"
          : "NUBi conversation",
        createdAt: now(),
      });
    }

    const messages = sessionRef.collection("messages");
    const batch = db.batch();

    batch.create(messages.doc(), {
      role: "user",
      text: question,
      createdAt: now(),
    });

    batch.create(messages.doc(), {
      role: "assistant",
      text: answer,
      createdAt: now(),
    });

    batch.set(sessionRef, {
      lastActivity: now(),
      lastAnswer: answer.slice(0, 300),
      sectionIndex,
    }, {merge: true});

    await batch.commit();

    return {
      answer,
      sessionId: sessionRef.id,
    };
  },
);

exports.nubiCheckpoint = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );
    const index = Number(request.data.section);

    const {data} =
      await requireSource(uid, sourceId);

    const section = sectionOf(data, index);
    const id = hash(
      `${uid}:${sourceId}:${index}`,
    );

    const ref = db.doc(
      `nubiPrivateCheckpoints/${id}`,
    );

    let snap = await ref.get();
    let question;

    if (snap.exists) {
      question = snap.data();
    } else {
      const generated = await generateJson(
        uid,
        `Create ONE university MCQ from
this saved lecture section.
Return JSON:
{
 "question":"string",
 "options":["A","B","C","D"],
 "correctIndex":0,
 "explanation":"string",
 "topic":"string"
}
Exactly 4 answer options, one correct.
Section: ${section.title}
Brief: ${section.brief}`,
        700,
      );

      question =
        normalizeQuestions([generated], 1)[0];

      try {
        await ref.create({
          uid,
          sourceId,
          section: index,
          ...question,
        });
      } catch (error) {
        if (error.code !== 6) throw error;
        snap = await ref.get();
        question = snap.data();
      }
    }

    return {
      question: question.question,
      options: question.options,
      section: index,
    };
  },
);

exports.nubiCheckpointAnswer = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );
    const index = Number(request.data.section);
    const choice = Number(request.data.choice);

    const {ref, data} =
      await requireSource(uid, sourceId);
    sectionOf(data, index);

    if (!Number.isInteger(choice) ||
        choice < 0 || choice > 3) {
      fail("Invalid choice.");
    }

    const questionRef = db.doc(
      `nubiPrivateCheckpoints/${hash(
        `${uid}:${sourceId}:${index}`,
      )}`,
    );
    const questionSnap = await questionRef.get();

    if (!questionSnap.exists) {
      fail("Start this checkpoint first.");
    }

    const question = questionSnap.data();
    const correct =
      choice === question.correctIndex;

    const answerRef = db.doc(
      `users/${uid}/checkpointAnswers/${hash(
        `${sourceId}:${index}`,
      )}`,
    );

    const firstAttempt = await db.runTransaction(
      async (tx) => {
        const existing = await tx.get(answerRef);
        if (existing.exists) return false;

        tx.create(answerRef, {
          sourceId,
          section: index,
          choice,
          correct,
          createdAt: now(),
        });

        if (correct) {
          tx.update(ref, {
            completedSections:
              C.admin.firestore.FieldValue
                .arrayUnion(index),
            currentSection: Math.min(
              index + 1,
              data.sections.length - 1,
            ),
            updatedAt: now(),
          });
        }
        return true;
      },
    );

    let earned = 0;

    if (firstAttempt && correct) {
      earned += await grantXp(
        uid,
        `checkpoint:${sourceId}:${index}`,
        "checkpoint",
        XP.checkpoint,
      );
      earned += await grantXp(
        uid,
        `section:${sourceId}:${index}`,
        "tutorSection",
        XP.tutorSection,
      );
    }

    return {
      correct,
      correctIndex: question.correctIndex,
      explanation: question.explanation,
      earned,
      firstAttempt,
    };
  },
);

exports.nubiCreateQuiz = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );

    const count = Number(request.data.count);

    if (![5, 7, 10, 12, 15].includes(count)) {
      throw new HttpsError(
        "invalid-argument",
        "Choose 5, 7, 10, 12 or 15.",
      );
    }

    const {data} =
      await requireSource(uid, sourceId);

    const generated = await generateJson(
      uid,
      `Create exactly ${count} distinct
university-level MCQs grounded in these
lecture briefs. No filler.
Return JSON {"questions":[
{"question":"string",
"options":["A","B","C","D"],
"correctIndex":0,
"explanation":"string",
"topic":"string"}]}.
Cover important topics with varied
difficulty. Do not invent source facts.
BRIEFS:
${JSON.stringify(data.sections)}`,
      5500,
    );

    const questions = normalizeQuestions(
      generated.questions,
      count,
    );

    if (questions.length !== count) {
      fail("Not enough valid questions. Retry.");
    }

    const quizRef = db.collection(
      `users/${uid}/quizzes`,
    ).doc();

    const privateRef = db.doc(
      `nubiPrivateQuizzes/${quizRef.id}`,
    );

    const publicQuestions = questions.map((q) => ({
      question: q.question,
      options: q.options,
      topic: q.topic,
    }));

    const batch = db.batch();

    batch.create(quizRef, {
      sourceId,
      title: data.title,
      count,
      questions: publicQuestions,
      mode: "practice",
      createdAt: now(),
    });

    batch.create(privateRef, {
      uid,
      sourceId,
      questions,
    });

    await batch.commit();

    return {quizId: quizRef.id, count};
  },
);

exports.nubiQuizAnswer = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const quizId = stringValue(
      request.data.quizId, 100,
    );
    const index = Number(request.data.question);
    const choice = Number(request.data.choice);

    const quizRef = db.doc(
      `users/${uid}/quizzes/${quizId}`,
    );
    const secretRef = db.doc(
      `nubiPrivateQuizzes/${quizId}`,
    );

    const [quiz, secretQuiz] = await Promise.all([
      quizRef.get(),
      secretRef.get(),
    ]);

    if (!quiz.exists ||
        !secretQuiz.exists ||
        secretQuiz.data().uid !== uid) {
      fail("Quiz not found.");
    }

    const question =
      secretQuiz.data().questions[index];

    if (!question ||
        !Number.isInteger(choice) ||
        choice < 0 || choice > 3) {
      fail("Invalid question or choice.");
    }

    const attemptRef = quizRef
      .collection("answers")
      .doc(String(index));

    const created = await db.runTransaction(
      async (tx) => {
        const old = await tx.get(attemptRef);
        if (old.exists) return false;

        tx.create(attemptRef, {
          choice,
          correct:
            choice === question.correctIndex,
          createdAt: now(),
        });
        return true;
      },
    );

    let earned = 0;
    const correct =
      choice === question.correctIndex;

    if (created && correct) {
      earned = await grantXp(
        uid,
        `quiz:${quizId}:${index}`,
        "mcq",
        XP.mcq,
      );
    }

    return {
      correct,
      correctIndex: question.correctIndex,
      explanation: question.explanation,
      earned,
      firstAttempt: created,
    };
  },
);

exports.nubiCreateFlashcards = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );
    const {data} =
      await requireSource(uid, sourceId);

    const generated = await generateJson(
      uid,
      `Generate 10 high-yield recall cards
from these lecture briefs.
Return JSON:
{"cards":[
{"front":"question","back":"answer",
"type":"basic"}]}
Types may be basic, cloze, clinical.
Keep answers accurate and concise.
BRIEFS:
${JSON.stringify(data.sections)}`,
      2200,
    );

    if (!Array.isArray(generated.cards) ||
        generated.cards.length < 5) {
      fail("Could not generate flashcards.");
    }

    const cards = generated.cards
      .slice(0, 15)
      .map((card) => ({
        front: stringValue(card.front, 250),
        back: stringValue(card.back, 350),
        type: stringValue(card.type, 20),
        intervalDays: 0,
        nextDueAt: 0,
        reviewed: 0,
      }));

    if (cards.some((c) => !c.front || !c.back)) {
      fail("Incomplete flashcard.");
    }

    const deck = db.collection(
      `users/${uid}/flashcardDecks`,
    ).doc();

    await deck.create({
      sourceId,
      title: data.title,
      cards,
      createdAt: now(),
      updatedAt: now(),
    });

    return {deckId: deck.id};
  },
);

exports.nubiReviewCard = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const deckId = stringValue(
      request.data.deckId, 100,
    );
    const index = Number(request.data.cardIndex);
    const rating = stringValue(
      request.data.rating, 10,
    );

    if (!["again", "hard", "good", "easy"]
        .includes(rating)) {
      fail("Invalid review rating.");
    }

    const ref = db.doc(
      `users/${uid}/flashcardDecks/${deckId}`,
    );

    const result = await db.runTransaction(
      async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) fail("Deck not found.");

        const cards = snap.data().cards || [];
        const card = cards[index];

        if (!card) fail("Card not found.");

        const current = Date.now();

        if ((card.nextDueAt || 0) > current) {
          fail("This card is not due for review.");
        }

        const previous = card.intervalDays || 0;
        const intervals = {
          again: 0,
          hard: Math.max(1, previous),
          good: Math.max(2, previous * 2 || 2),
          easy: Math.max(4, previous * 3 || 4),
        };

        const nextDays = intervals[rating];

        cards[index] = {
          ...card,
          reviewed: (card.reviewed || 0) + 1,
          intervalDays: nextDays,
          nextDueAt: current +
            (rating === "again"
              ? 10 * 60 * 1000
              : nextDays * 86400000),
          lastRating: rating,
        };

        tx.update(ref, {
          cards,
          updatedAt: now(),
        });

        return {
          reviewNumber: cards[index].reviewed,
          nextDueAt: cards[index].nextDueAt,
        };
      },
    );

    let earned = 0;

    if (rating === "good" || rating === "easy") {
      earned = await grantXp(
        uid,
        `card:${deckId}:${index}:${
          result.reviewNumber
        }`,
        "flashcard",
        XP.flashcard,
      );
    }

    return {...result, earned};
  },
);

exports.nubiDeleteSource = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );

    const ref = sourceRef(uid, sourceId);
    const existing = await ref.get();

    if (!existing.exists) {
      fail("Source not found.");
    }

    const dependentCollections = [
      "quizzes",
      "flashcardDecks",
      "tutorSessions",
    ];

    for (const collection of dependentCollections) {
      const query = await db.collection(
        `users/${uid}/${collection}`,
      ).where(
        "sourceId", "==", sourceId,
      ).get();

      for (const doc of query.docs) {
        await db.recursiveDelete(doc.ref);
      }
    }

    await db.recursiveDelete(ref);

    return {
      deleted: true,
      message:
        "Associated generated records deleted. "
        + "Previously earned XP is retained.",
    };
  },
);

exports.nubiSetRankingOptIn = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const enabled = request.data.enabled === true;

    await db.doc(
      `users/${uid}/nubiSettings/current`,
    ).set({
      leaderboardOptIn: enabled,
      updatedAt: now(),
    }, {merge: true});

    // Existing ranking records must be hidden or
    // removed when the student opts out.
    if (!enabled) {
      for (const period of C.periods()) {
        await db.doc(
          `nubiRankings/${period}/players/${uid}`,
        ).delete();
      }
    }

    return {enabled};
  },
);
