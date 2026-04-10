import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// Constants for validation rules.
const MAX_WPM = 300; // World record ~300 WPM.
const MIN_WPM = 5; // Minimum WPM to qualify for the leaderboard.
const MIN_ACCURACY = 0;
const MAX_ACCURACY = 100;
const DURATION_DIFF_TOLERANCE_SEC = 3;
const DURATION_OVERHEAD_FACTOR = 1.1;
const SUSPICIOUS_JUMP_MULTIPLIER = 1.5;
const SUSPICIOUS_TEST_COUNT_THRESHOLD = 10;
const CHARS_PER_WORD = 5;

interface ScoreData {
  userId: string;
  wpm: number;
  accuracy: number;
  keystrokeCount: number;
  durationSeconds: number;
  language: string;
  level: string;
  createdAt?: FirebaseFirestore.Timestamp;
}

interface ValidationResult {
  valid: boolean;
  reason?: string;
}

/**
 * Validates a single submitted score against a set of anti-cheat rules.
 * @param {ScoreData} score The score data submitted by the client.
 * @param {number} previousPersonalBest The user's best WPM so far for
 *     the matching language/level combination.
 * @param {number} previousTestCount The user's total test count so far.
 * @return {ValidationResult} Result describing whether the score is valid.
 */
function validateScoreData(
  score: ScoreData,
  previousPersonalBest: number,
  previousTestCount: number,
): ValidationResult {
  // Rule 1: WPM upper bound.
  if (typeof score.wpm !== "number" || score.wpm > MAX_WPM) {
    return {
      valid: false,
      reason: `WPM exceeds maximum allowed value of ${MAX_WPM}.`,
    };
  }

  // Rule 2: WPM minimum for leaderboard.
  if (score.wpm < MIN_WPM) {
    return {
      valid: false,
      reason: `WPM below minimum of ${MIN_WPM} for leaderboard.`,
    };
  }

  // Rule 3: Accuracy range.
  if (
    typeof score.accuracy !== "number" ||
    score.accuracy < MIN_ACCURACY ||
    score.accuracy > MAX_ACCURACY
  ) {
    return {
      valid: false,
      reason: `Accuracy must be between ${MIN_ACCURACY} and ${MAX_ACCURACY}.`,
    };
  }

  // Rule 4: Keystroke / duration sanity check.
  if (
    typeof score.keystrokeCount !== "number" ||
    score.keystrokeCount <= 0 ||
    typeof score.durationSeconds !== "number" ||
    score.durationSeconds <= 0
  ) {
    return {
      valid: false,
      reason: "Invalid keystroke count or duration.",
    };
  }

  // Expected duration in seconds based on reported WPM and keystrokes.
  // words = keystrokeCount / 5
  // minutes = words / wpm
  // expectedSeconds = minutes * 60 * overhead
  const words = score.keystrokeCount / CHARS_PER_WORD;
  const minutes = words / score.wpm;
  const expectedDuration = minutes * 60 * DURATION_OVERHEAD_FACTOR;
  const diff = Math.abs(expectedDuration - score.durationSeconds);

  if (diff > DURATION_DIFF_TOLERANCE_SEC) {
    return {
      valid: false,
      reason:
        `Duration mismatch. Expected ~${expectedDuration.toFixed(2)}s ` +
        `but got ${score.durationSeconds}s (diff ${diff.toFixed(2)}s).`,
    };
  }

  // Rule 5: Personal best jump check (suspiciously large improvement).
  if (
    previousTestCount > SUSPICIOUS_TEST_COUNT_THRESHOLD &&
    previousPersonalBest > 0 &&
    score.wpm > previousPersonalBest * SUSPICIOUS_JUMP_MULTIPLIER
  ) {
    return {
      valid: false,
      reason:
        `Suspicious jump: new WPM ${score.wpm} exceeds 1.5x previous ` +
        `personal best of ${previousPersonalBest}.`,
    };
  }

  return {valid: true};
}

export const validateScore = onDocumentCreated(
  "leaderboards/{leaderboardId}/scores/{scoreId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("No data associated with the event.");
      return;
    }

    const score = snapshot.data() as ScoreData;
    const {leaderboardId, scoreId} = event.params;

    logger.info("Validating score", {
      leaderboardId,
      scoreId,
      userId: score.userId,
      wpm: score.wpm,
    });

    if (!score.userId || !score.language || !score.level) {
      await snapshot.ref.update({
        verified: false,
        rejectReason: "Missing required fields (userId, language, level).",
        hiddenFromLeaderboard: true,
      });
      return;
    }

    const userRef = db.collection("users").doc(score.userId);

    try {
      const userSnap = await userRef.get();
      const userData = userSnap.exists ? userSnap.data() || {} : {};

      const personalBests =
        (userData.personalBests as Record<
          string,
          Record<string, number>
        >) || {};
      const testCounts =
        (userData.testCounts as Record<string, Record<string, number>>) ||
        {};

      const previousPersonalBest =
        personalBests?.[score.language]?.[score.level] || 0;
      const previousTestCount =
        testCounts?.[score.language]?.[score.level] || 0;

      const result = validateScoreData(
        score,
        previousPersonalBest,
        previousTestCount,
      );

      if (!result.valid) {
        logger.warn("Score rejected", {
          scoreId,
          reason: result.reason,
        });
        await snapshot.ref.update({
          verified: false,
          rejectReason: result.reason,
          hiddenFromLeaderboard: true,
          validatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Valid score: mark verified and update user stats atomically.
      const batch = db.batch();

      batch.update(snapshot.ref, {
        verified: true,
        hiddenFromLeaderboard: false,
        validatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const userUpdate: Record<string, unknown> = {
        [`testCounts.${score.language}.${score.level}`]:
          admin.firestore.FieldValue.increment(1),
      };

      if (score.wpm > previousPersonalBest) {
        userUpdate[`personalBests.${score.language}.${score.level}`] =
          score.wpm;
      }

      if (userSnap.exists) {
        batch.update(userRef, userUpdate);
      } else {
        batch.set(
          userRef,
          {
            personalBests: {
              [score.language]: {
                [score.level]:
                  score.wpm > previousPersonalBest ?
                    score.wpm :
                    previousPersonalBest,
              },
            },
            testCounts: {
              [score.language]: {
                [score.level]: 1,
              },
            },
          },
          {merge: true},
        );
      }

      await batch.commit();

      logger.info("Score verified", {
        scoreId,
        userId: score.userId,
        wpm: score.wpm,
        newPersonalBest: score.wpm > previousPersonalBest,
      });
    } catch (err) {
      logger.error("Error validating score", {
        scoreId,
        error: (err as Error).message,
      });
      await snapshot.ref.update({
        verified: false,
        rejectReason: "Internal validation error.",
        hiddenFromLeaderboard: true,
        validatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);
