import * as admin from "firebase-admin";

type Firestore = admin.firestore.Firestore;

export type RecommendationsInsight = {
  weakAreas: string[];
  strengths: string[];
  confidenceByTopic: Record<string, number>;
  recommendationText: string;
  generatedAt: string;
  quizSampleSize: number;
};

function normalizeTopicKey(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, " ");
}

function displayForKey(
  displayByKey: Map<string, string>,
  key: string,
  raw: string
): string {
  const trimmed = raw.trim();
  if (!trimmed) return "";
  if (!displayByKey.has(key)) {
    displayByKey.set(key, trimmed);
  }
  return displayByKey.get(key) ?? trimmed;
}

function parseScoreFraction(data: Record<string, unknown>): number | null {
  const sf = data.scoreFraction;
  if (typeof sf === "number" && Number.isFinite(sf)) {
    return Math.min(1, Math.max(0, sf));
  }
  const correct = data.correctCount;
  const total = data.totalCount;
  if (typeof correct === "number" && typeof total === "number" && total > 0) {
    return Math.min(1, Math.max(0, correct / total));
  }
  return null;
}

function toMillis(completedAt: unknown): number {
  if (completedAt instanceof admin.firestore.Timestamp) {
    return completedAt.toMillis();
  }
  if (
    completedAt &&
    typeof completedAt === "object" &&
    "_seconds" in completedAt &&
    typeof (completedAt as {_seconds: unknown})._seconds === "number"
  ) {
    return (completedAt as {_seconds: number})._seconds * 1000;
  }
  if (typeof completedAt === "string" && completedAt.trim()) {
    const t = Date.parse(completedAt);
    if (!Number.isNaN(t)) return t;
  }
  return 0;
}

/**
 * Aggregates quiz performance from quizHistory (client-written) and legacy
 * quiz attempt subcollections under users/{uid}/quizzes.
 */
export async function buildRecommendationsInsight(
  db: Firestore,
  userId: string
): Promise<RecommendationsInsight> {
  const now = new Date().toISOString();
  const displayByKey = new Map<string, string>();
  const weakHits = new Map<string, number>();
  const linkedExposure = new Map<string, number>();
  const scores: number[] = [];
  const scoreMillis: {score: number; ms: number}[] = [];

  const historySnap = await db
    .collection("users")
    .doc(userId)
    .collection("quizHistory")
    .orderBy("completedAt", "desc")
    .limit(40)
    .get();

  for (const doc of historySnap.docs) {
    const data = doc.data() as Record<string, unknown>;
    const ms = toMillis(data.completedAt);
    const sf = parseScoreFraction(data);
    if (sf != null) {
      scores.push(sf);
      scoreMillis.push({score: sf, ms});
    }

    const weakRaw = data.weakTopicTitles;
    if (Array.isArray(weakRaw)) {
      for (const item of weakRaw) {
        if (typeof item !== "string") continue;
        const key = normalizeTopicKey(item);
        if (!key) continue;
        displayForKey(displayByKey, key, item);
        weakHits.set(key, (weakHits.get(key) ?? 0) + 1);
      }
    }

    const linkedRaw = data.linkedTopicTitles;
    if (Array.isArray(linkedRaw)) {
      for (const item of linkedRaw) {
        if (typeof item !== "string") continue;
        const key = normalizeTopicKey(item);
        if (!key) continue;
        displayForKey(displayByKey, key, item);
        linkedExposure.set(key, (linkedExposure.get(key) ?? 0) + 1);
      }
    }
  }

  const quizzesSnap = await db
    .collection("users")
    .doc(userId)
    .collection("quizzes")
    .limit(16)
    .get();

  for (const quizDoc of quizzesSnap.docs) {
    const attemptsSnap = await quizDoc.ref
      .collection("attempts")
      .orderBy("completedAt", "desc")
      .limit(6)
      .get();

    for (const attempt of attemptsSnap.docs) {
      const data = attempt.data() as Record<string, unknown>;
      const ms = toMillis(data.completedAt);
      const rawScore = data.score;
      if (typeof rawScore === "number" && Number.isFinite(rawScore)) {
        const sf = Math.min(1, Math.max(0, rawScore));
        scores.push(sf);
        scoreMillis.push({score: sf, ms});
      }
      const weakTags = data.weakTags;
      if (Array.isArray(weakTags)) {
        for (const item of weakTags) {
          if (typeof item !== "string") continue;
          const key = normalizeTopicKey(item);
          if (!key) continue;
          displayForKey(displayByKey, key, item);
          weakHits.set(key, (weakHits.get(key) ?? 0) + 1);
        }
      }
    }
  }

  const allKeys = new Set<string>([
    ...weakHits.keys(),
    ...linkedExposure.keys(),
  ]);

  const exposureByKey = new Map<string, number>();
  for (const key of allKeys) {
    const w = weakHits.get(key) ?? 0;
    const l = linkedExposure.get(key) ?? 0;
    exposureByKey.set(key, Math.max(l, w, w > 0 ? w : 0));
  }

  const confidenceByTopic: Record<string, number> = {};
  const rankedByExposure = [...exposureByKey.entries()].sort(
    (a, b) => b[1] - a[1]
  );
  for (const [key, exp] of rankedByExposure.slice(0, 14)) {
    const w = weakHits.get(key) ?? 0;
    const conf =
      exp <= 0 ? 0.5 : Math.min(1, Math.max(0, 1 - w / exp));
    const label = displayByKey.get(key) ?? key;
    confidenceByTopic[label] = Math.round(conf * 100) / 100;
  }

  const weakRanked = [...weakHits.entries()]
    .filter(([, c]) => c > 0)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([k]) => displayByKey.get(k) ?? k);

  const strengthCandidates = [...allKeys]
    .map((key) => {
      const exp = exposureByKey.get(key) ?? 0;
      const w = weakHits.get(key) ?? 0;
      const conf = exp <= 0 ? 0 : 1 - w / exp;
      return {key, exp, w, conf};
    })
    .filter((x) => x.exp >= 2 && x.w === 0)
    .sort((a, b) => b.conf - a.conf)
    .slice(0, 4)
    .map((x) => displayByKey.get(x.key) ?? x.key);

  let strengths = strengthCandidates;
  if (strengths.length === 0) {
    strengths = [...allKeys]
      .map((key) => {
        const exp = exposureByKey.get(key) ?? 0;
        const w = weakHits.get(key) ?? 0;
        const conf = exp <= 0 ? 0 : 1 - w / exp;
        return {key, exp, conf};
      })
      .filter((x) => x.exp >= 1 && x.conf >= 0.65)
      .sort((a, b) => b.conf - a.conf)
      .slice(0, 3)
      .map((x) => displayByKey.get(x.key) ?? x.key);
  }

  const recommendationText = buildRecommendationText({
    scores,
    scoreMillis,
    weakRanked,
    strengths,
    avgScore:
      scores.length === 0
        ? null
        : scores.reduce((a, b) => a + b, 0) / scores.length,
  });

  return {
    weakAreas: weakRanked,
    strengths,
    confidenceByTopic,
    recommendationText,
    generatedAt: now,
    quizSampleSize: scores.length,
  };
}

function buildRecommendationText(args: {
  scores: number[];
  scoreMillis: {score: number; ms: number}[];
  weakRanked: string[];
  strengths: string[];
  avgScore: number | null;
}): string {
  const {weakRanked, strengths, avgScore} = args;

  if (
    args.scores.length === 0 &&
    weakRanked.length === 0 &&
    strengths.length === 0
  ) {
    return "Complete a few quizzes to unlock personalized weak areas, strengths, and tailored study tips based on your real attempts.";
  }

  const parts: string[] = [];
  if (avgScore != null) {
    parts.push(
      `Across your recent quizzes, you're averaging ${Math.round(avgScore * 100)}%.`
    );
  }

  if (weakRanked.length > 0) {
    const listed =
      weakRanked.length === 1
        ? weakRanked[0]
        : weakRanked.length === 2
          ? `${weakRanked[0]} and ${weakRanked[1]}`
          : `${weakRanked.slice(0, -1).join(", ")}, and ${weakRanked[weakRanked.length - 1]}`;
    parts.push(
      `You most often miss questions on ${listed}. Schedule short review sessions on those topics before adding new material.`
    );
  } else if (avgScore != null && avgScore < 0.75) {
    parts.push(
      "Scores have room to improve—try smaller quizzes more often to pinpoint where mistakes cluster."
    );
  }

  if (strengths.length > 0) {
    parts.push(
      `You're relatively strong on ${strengths.slice(0, 2).join(" and ")}—use that confidence to tackle harder mixed-review quizzes.`
    );
  }

  const trend = trendFromScores(args.scoreMillis);
  if (trend) {
    parts.push(trend);
  }

  return parts.join(" ");
}

function trendFromScores(
  scoreMillis: {score: number; ms: number}[]
): string | null {
  if (scoreMillis.length < 6) return null;
  const sorted = [...scoreMillis].sort((a, b) => b.ms - a.ms);
  const n = sorted.length;
  const half = Math.ceil(n / 2);
  const recent = sorted.slice(0, half);
  const older = sorted.slice(half);
  const rAvg =
    recent.reduce((s, x) => s + x.score, 0) / Math.max(1, recent.length);
  const oAvg =
    older.reduce((s, x) => s + x.score, 0) / Math.max(1, older.length);
  if (rAvg > oAvg + 0.06) {
    return "Your latest attempts are trending upward compared with earlier ones—keep the same rhythm.";
  }
  if (rAvg < oAvg - 0.06) {
    return "Recent scores dipped versus earlier attempts—consider a focused review pass before the next quiz.";
  }
  return null;
}
