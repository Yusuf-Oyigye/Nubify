
"use strict";

const {onCall, HttpsError} =
  require("firebase-functions/v2/https");

const C = require("./nubi_core");

const {
  db, now, userId, sourceRef,
  callableOptions, stringValue,
  generateJson, grantXp, XP,
} = C;

const MAX_PLAYERS = 5;
const MAX_PER_PLAYER = 5;
const STEAL_WINDOW_MS = 7000;

function roomRef(roomId) {
  return db.doc(`mindrushRooms/${roomId}`);
}

function privateRoomRef(roomId) {
  return db.doc(`nubiPrivateMindrush/${roomId}`);
}

function requireRoom(doc, uid) {
  if (!doc.exists) {
    throw new HttpsError(
      "not-found",
      "MindRush room not found.",
    );
  }

  if (!(doc.data().players || []).includes(uid)) {
    throw new HttpsError(
      "permission-denied",
      "You are not in this room.",
    );
  }
}

function validateQuestions(input, required) {
  if (!Array.isArray(input) ||
      input.length !== required) {
    throw new HttpsError(
      "failed-precondition",
      "Insufficient valid battle questions.",
    );
  }

  return input.map((item) => {
    const answer = Number(item.correctIndex);
    if (!Array.isArray(item.options) ||
        item.options.length !== 4 ||
        !Number.isInteger(answer) ||
        answer < 0 || answer > 3) {
      throw new HttpsError(
        "failed-precondition",
        "Invalid battle question.",
      );
    }

    return {
      question: stringValue(item.question, 300),
      options: item.options.map((option) =>
        stringValue(option, 160),
      ),
      correctIndex: answer,
      explanation: stringValue(
        item.explanation, 350,
      ),
    };
  });
}

function visibleQuestion(question) {
  return {
    question: question.question,
    options: question.options,
  };
}

function nextRound(room, questions) {
  const next = (room.roundIndex || 0) + 1;

  if (next >= questions.length) {
    return {
      roundIndex: next,
      status: "finished",
      phase: "finished",
      deadline: 0,
      questionView: null,
      updatedAt: now(),
    };
  }

  const playerIndex = next % room.players.length;

  return {
    roundIndex: next,
    phase: "answer",
    turnUid: room.players[playerIndex],
    questionView: visibleQuestion(
      questions[next],
    ),
    deadline: Date.now() +
      room.answerSeconds * 1000,
    updatedAt: now(),
  };
}

// ===========================================
// CREATE ROOM
// ===========================================

exports.nubiCreateRoom = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const sourceId = stringValue(
      request.data.sourceId, 100,
    );

    const source =
      await sourceRef(uid, sourceId).get();

    if (!source.exists ||
        source.data().status !== "ready") {
      throw new HttpsError(
        "failed-precondition",
        "Choose a saved lecture first.",
      );
    }

    const perPlayer =
      Number(request.data.perPlayer || 5);
    const answerSeconds =
      Number(request.data.answerSeconds || 20);

    if (![3, 5].includes(perPlayer) ||
        ![15, 20, 30].includes(answerSeconds)) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported room settings.",
      );
    }

const mode = stringValue(
  request.data.mode || "classic", 30,
);

if (!["classic", "exam"].includes(mode)) {
  throw new HttpsError(
    "invalid-argument",
    "This game mode is not yet available.",
  );
}

    const ref = db.collection(
      "mindrushRooms",
    ).doc();

    await ref.create({
      ownerUid: uid,
      sourceId,
      status: "waiting",
      mode,
      players: [uid],
      perPlayer,
      answerSeconds,
      scores: {[uid]: 0},
      streaks: {[uid]: 0},
      roundIndex: -1,
      createdAt: now(),
    });

    return {roomId: ref.id};
  },
);

// ===========================================
// JOIN ROOM
// ===========================================

exports.nubiJoinRoom = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const roomId = stringValue(
      request.data.roomId, 100,
    );

    const ref = roomRef(roomId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);

      if (!snap.exists ||
          snap.data().status !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "Room is not accepting players.",
        );
      }

      const players = snap.data().players || [];

      if (players.includes(uid)) return;

      if (players.length >= MAX_PLAYERS) {
        throw new HttpsError(
          "resource-exhausted",
          "Room is full.",
        );
      }

      tx.update(ref, {
        players: [...players, uid],
        [`scores.${uid}`]: 0,
        [`streaks.${uid}`]: 0,
      });
    });

    return {joined: true};
  },
);

// ===========================================
// START CLASSIC BATTLE
// ===========================================

exports.nubiStartRoom = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const roomId = stringValue(
      request.data.roomId, 100,
    );

    const ref = roomRef(roomId);

    const room = await db.runTransaction(
      async (tx) => {
        const snap = await tx.get(ref);

        if (!snap.exists ||
            snap.data().ownerUid !== uid) {
          throw new HttpsError(
            "permission-denied",
            "Only the host may start.",
          );
        }

        const data = snap.data();

        if (data.status !== "waiting" ||
            data.players.length < 2) {
          throw new HttpsError(
            "failed-precondition",
            "At least two players are required.",
          );
        }

        tx.update(ref, {
          status: "preparing",
          updatedAt: now(),
        });

        return data;
      },
    );

    try {
      const source = await sourceRef(
        uid,
        room.sourceId,
      ).get();

      if (!source.exists) {
        throw new Error("Source unavailable");
      }

      const total = Math.min(
        room.players.length * room.perPlayer,
        MAX_PLAYERS * MAX_PER_PLAYER,
      );

      const result = await generateJson(
        uid,
        `Generate exactly ${total}
distinct academic competition MCQs.
Use only these lecture briefs:
${JSON.stringify(source.data().sections)}
Return JSON:
{"questions":[
{"question":"string",
"options":["A","B","C","D"],
"correctIndex":0,
"explanation":"string"}]}
Each question must have four options,
one correct answer and clear reasoning.
No filler or invented content.`,
        6500,
      );

      const questions = validateQuestions(
        result.questions,
        total,
      );

      await privateRoomRef(roomId).create({
        questions,
        createdAt: now(),
      });

      await ref.update({
        status: "running",
        phase: "answer",
        roundIndex: 0,
        turnUid: room.players[0],
        questionView: visibleQuestion(
          questions[0],
        ),
        deadline: Date.now() +
          room.answerSeconds * 1000,
        updatedAt: now(),
      });

      return {started: true};
    } catch (error) {
      await ref.update({
        status: "waiting",
        updatedAt: now(),
      }).catch(() => {});
      throw error;
    }
  },
);

// ===========================================
// ANSWER / STEAL
// ===========================================

exports.nubiAnswerRoom = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const roomId = stringValue(
      request.data.roomId, 100,
    );
    const choice = Number(request.data.choice);

    if (!Number.isInteger(choice) ||
        choice < 0 || choice > 3) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid answer.",
      );
    }

    const ref = roomRef(roomId);
    const privateRef = privateRoomRef(roomId);

    const action = await db.runTransaction(
      async (tx) => {
        const [roomSnap, bankSnap] =
          await Promise.all([
            tx.get(ref),
            tx.get(privateRef),
          ]);

        requireRoom(roomSnap, uid);

        const room = roomSnap.data();

        if (room.status !== "running" ||
            !bankSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            "Battle is not active.",
          );
        }

        if (Date.now() > room.deadline) {
          throw new HttpsError(
            "deadline-exceeded",
            "The answer window ended.",
          );
        }

        const stealing = room.phase === "steal";

        if (stealing) {
          if (uid === room.turnUid) {
            throw new HttpsError(
              "permission-denied",
              "Current player cannot steal.",
            );
          }
        } else if (
          room.phase !== "answer" ||
          uid !== room.turnUid
        ) {
          throw new HttpsError(
            "permission-denied",
            "It is not your turn.",
          );
        }

        const question =
          bankSnap.data().questions[room.roundIndex];

        if (!question) {
          throw new HttpsError(
            "failed-precondition",
            "Question unavailable.",
          );
        }

        const correct =
          question.correctIndex === choice;

if (stealing) {
  const attemptRef = db.doc(
    `nubiStealAttempts/${roomId}/claims/${room.roundIndex}_${uid}`,
  );

  const previous = await tx.get(attemptRef);

  if (previous.exists) {
    throw new HttpsError(
      "already-exists",
      "You have already attempted this steal.",
    );
  }

  tx.create(attemptRef, {
    uid,
    roundIndex: room.roundIndex,
    createdAt: now(),
  });

  if (!correct) {
    return {
      correct: false,
      earned: 0,
      stealing: true,
    };
  }
}


if (!correct) {
  if (room.mode === "exam") {
    tx.update(
      ref,
      nextRound(
        room,
        bankSnap.data().questions,
      ),
    );

    return {
      correct: false,
      earned: 0,
      explanation: question.explanation,
    };
  }

  tx.update(ref, {
    phase: "steal",
    streaks: {
      ...room.streaks,
      [uid]: 0,
    },
    deadline: Date.now() + STEAL_WINDOW_MS,
    updatedAt: now(),
  });

  return {
    correct: false,
    earned: 0,
    explanation: question.explanation,
  };
}

        const scores = {
          ...room.scores,
        };
        const streaks = {
          ...room.streaks,
        };

        const award = stealing
          ? XP.steal
          : XP.mindrush;

        scores[uid] = (scores[uid] || 0) + award;
        streaks[uid] = stealing
          ? 0
          : (streaks[uid] || 0) + 1;

        const streak = streaks[uid];
        const bonus = !stealing && streak === 5
          ? XP.streak5
          : !stealing && streak === 3
              ? XP.streak3
              : 0;

        if (bonus) scores[uid] += bonus;

        tx.update(ref, {
          scores,
          streaks,
          ...nextRound(
            room,
            bankSnap.data().questions,
          ),
        });

        return {
          correct: true,
          award,
          bonus,
          streak,
          stealing,
          roundIndex: room.roundIndex,
          explanation: question.explanation,
        };
      },
    );

    if (action.correct) {
      const event =
        `${roomId}:${action.roundIndex}:${uid}`;

      const earned = await grantXp(
        uid,
        `mindrush:${event}`,
        action.stealing
          ? "steal"
          : "mindrush",
        action.award,
      );

      let bonusEarned = 0;

      if (action.bonus) {
        bonusEarned = await grantXp(
          uid,
          `streak:${event}`,
          "mindrushStreak",
          action.bonus,
        );
      }

      return {
        ...action,
        earned: earned + bonusEarned,
      };
    }

    return action;
  },
);

// ===========================================
// ADVANCE EXPIRED ROUND
// No Firestore write every timer second.
// ===========================================

exports.nubiAdvanceRoom = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const roomId = stringValue(
      request.data.roomId, 100,
    );

    const ref = roomRef(roomId);

    return db.runTransaction(async (tx) => {
      const [roomSnap, bankSnap] =
        await Promise.all([
          tx.get(ref),
          tx.get(privateRoomRef(roomId)),
        ]);

      requireRoom(roomSnap, uid);

      const room = roomSnap.data();

      if (room.status !== "running" ||
          !bankSnap.exists) {
        return {advanced: false};
      }

      if (Date.now() <= room.deadline) {
        return {advanced: false};
      }


if (room.phase === "answer" &&
    room.mode !== "exam") {
        tx.update(ref, {
          phase: "steal",
          deadline:
            Date.now() + STEAL_WINDOW_MS,
          updatedAt: now(),
        });
      } else {
        tx.update(
          ref,
          nextRound(
            room,
            bankSnap.data().questions,
          ),
        );
      }

      return {advanced: true};
    });
  },
);

// ===========================================
// HINT AND EXTRA TIME
// ===========================================

exports.nubiUsePowerUp = onCall(
  callableOptions,
  async (request) => {
    const uid = userId(request);
    const roomId = stringValue(
      request.data.roomId, 100,
    );
    const power = stringValue(
      request.data.power, 30,
    );

    if (!["hint", "extraTime"].includes(power)) {
      throw new HttpsError(
        "invalid-argument",
        "Unsupported power-up.",
      );
    }

    const ref = roomRef(roomId);

    return db.runTransaction(async (tx) => {
      const [roomSnap, bankSnap] =
        await Promise.all([
          tx.get(ref),
          tx.get(privateRoomRef(roomId)),
        ]);

      requireRoom(roomSnap, uid);

      const room = roomSnap.data();

      if (room.mode === "exam") {
        throw new HttpsError(
          "failed-precondition",
          "Power-ups are disabled in Exam Mode.",
        );
      }

      if (room.phase !== "answer" ||
          room.turnUid !== uid ||
          Date.now() >= room.deadline) {
        throw new HttpsError(
          "failed-precondition",
          "Power-up unavailable now.",
        );
      }

      const used = room.usedPowers || {};
      const key = `${uid}_${power}`;

      if (used[key]) {
        throw new HttpsError(
          "failed-precondition",
          "Power-up already used.",
        );
      }

      used[key] = true;

      if (power === "extraTime") {
        tx.update(ref, {
          usedPowers: used,
          deadline: room.deadline + 10000,
        });

        return {extraSeconds: 10};
      }

      const question =
        bankSnap.data().questions[room.roundIndex];

      const wrongOption = [0, 1, 2, 3]
        .find((i) => i !== question.correctIndex);

      tx.update(ref, {
        usedPowers: used,
      });

      return {
        removeOption: wrongOption,
      };
    });
  },
);
