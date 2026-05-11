import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

/** Must match app calendar + `index.ts` Google Calendar payloads. */
export const APP_CALENDAR_TIME_ZONE = "Asia/Bahrain";

const QUIZ_LOW_THRESHOLD = 0.6;
const EXAM_SOON_WINDOW_DAYS = 7;
const DEFAULT_DAILY_MINUTES = 120;
const MIN_DAILY_MINUTES = 30;
const MAX_DAILY_MINUTES = 360;
const ACTIVITY_WINDOW_DAYS = 14;
const DEFAULT_FALLBACK_EXAM_OFFSET_DAYS = 21;
const MAX_HORIZON_DAYS = 45;
const MIN_HORIZON_DAYS = 14;
const FIRST_SESSION_START_MINUTE = 17 * 60;
const SESSION_GAP_MINUTES = 10;

type SessionWrite = {
  calendarIso: string;
  topicId: string;
  durationMin: number;
  startMinute: number;
};

type TopicPerformanceInput = {
  topicId: string;
  topicTitle: string;
  subjectId: string;
  subjectTitle: string;
  examDate: Date;
  quizAccuracy: number;
  subjectDifficulty: number;
  lastStudiedAt: Date | null;
  missedSessions: number;
};

type ScoredTopic = {
  source: TopicPerformanceInput;
  score: number;
  reason: string;
};

function pad2(n: number): string {
  return n.toString().padStart(2, "0");
}

export function manamaTodayIso(): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: APP_CALENDAR_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === "year")?.value ?? "1970";
  const mo = parts.find((p) => p.type === "month")?.value ?? "01";
  const d = parts.find((p) => p.type === "day")?.value ?? "01";
  return `${y}-${mo}-${d}`;
}

export function addCalendarDaysIso(isoDate: string, days: number): string {
  const [y, mo, day] = isoDate.split("-").map(Number);
  const shifted = new Date(Date.UTC(y, mo - 1, day + days));
  return `${shifted.getUTCFullYear()}-${pad2(shifted.getUTCMonth() + 1)}-${pad2(shifted.getUTCDate())}`;
}

function examDateForSubject(examDateRaw: string, todayIso: string): Date {
  const trimmed = examDateRaw.trim();
  if (!trimmed) {
    return new Date(`${addCalendarDaysIso(todayIso, DEFAULT_FALLBACK_EXAM_OFFSET_DAYS)}T12:00:00+03:00`);
  }
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    return new Date(`${addCalendarDaysIso(todayIso, DEFAULT_FALLBACK_EXAM_OFFSET_DAYS)}T12:00:00+03:00`);
  }
  return parsed;
}

function calendarIsoInManama(instant: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: APP_CALENDAR_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

function bahrainNoonInstant(calendarIso: string): Date {
  return new Date(`${calendarIso}T12:00:00+03:00`);
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

function daysUntilExam(now: Date, exam: Date): number {
  return (exam.getTime() - now.getTime()) / (24 * 3600 * 1000);
}

function deadlineUrgency(now: Date, exam: Date): number {
  const d = daysUntilExam(now, exam);
  if (d <= 0) return 1;
  return clamp01((30 - d) / 30);
}

function lowQuizBoost(quizAccuracy: number, threshold: number): number {
  if (quizAccuracy >= threshold) return 0;
  const span = threshold <= 0 ? 1 : threshold;
  return clamp01((threshold - quizAccuracy) / span) * 0.9;
}

function examSoonBoost(now: Date, examDate: Date, soonWindowDays: number): number {
  if (soonWindowDays <= 0) return 0;
  const d = daysUntilExam(now, examDate);
  if (d > soonWindowDays) return 0;
  if (d <= 0) return 0.9;
  return clamp01((soonWindowDays - d) / soonWindowDays) * 0.9;
}

function missedSessionsBoost(missedSessions: number): number {
  if (missedSessions <= 0) return 0;
  return clamp01(missedSessions / 3) * 0.8;
}

function timeSinceLastStudied(now: Date, lastStudied: Date | null): number {
  if (!lastStudied) return 1;
  const days = (now.getTime() - lastStudied.getTime()) / (24 * 3600 * 1000);
  if (days <= 0) return 0;
  return clamp01(days / 14);
}

function normalizeTitle(value: string): string {
  return value.trim().toLowerCase().replaceAll("_", " ");
}

type QuizSignals = {globalScore: number; byWeakTitle: Map<string, number>};

async function loadQuizSignals(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<QuizSignals> {
  let snap: admin.firestore.QuerySnapshot;
  try {
    snap = await db
      .collection("users")
      .doc(uid)
      .collection("quizHistory")
      .orderBy("completedAt", "desc")
      .limit(30)
      .get();
  } catch {
    snap = await db
      .collection("users")
      .doc(uid)
      .collection("quizHistory")
      .limit(30)
      .get();
  }

  const scores: number[] = [];
  const weakCounts = new Map<string, number>();
  for (const doc of snap.docs) {
    const data = doc.data();
    const rawScore = data["scoreFraction"];
    if (typeof rawScore === "number") {
      scores.push(clamp01(rawScore));
    }
    const weakRaw = data["weakTopicTitles"];
    if (Array.isArray(weakRaw)) {
      for (const weak of weakRaw) {
        if (typeof weak !== "string") continue;
        const normalized = normalizeTitle(weak);
        if (!normalized) continue;
        weakCounts.set(normalized, (weakCounts.get(normalized) ?? 0) + 1);
      }
    }
  }

  const globalScore =
    scores.length === 0 ? 0.5 : clamp01(scores.reduce((a, b) => a + b, 0) / scores.length);

  return {globalScore, byWeakTitle: weakCounts};
}

function resolveQuizAccuracy(topicTitle: string, fallback: number, signals: Map<string, number>): number {
  const normalizedTopic = normalizeTitle(topicTitle);
  if (!normalizedTopic) return fallback;
  let weakHits = 0;
  signals.forEach((count, weakTitle) => {
    if (weakTitle.includes(normalizedTopic) || normalizedTopic.includes(weakTitle)) {
      weakHits += count;
    }
  });
  if (weakHits <= 0) return fallback;
  const penalty = Math.min(0.45, weakHits * 0.12);
  return clamp01(fallback - penalty);
}

function sessionDocIsDeleted(data: admin.firestore.DocumentData): boolean {
  const v = data["deletedAt"];
  if (v == null) return false;
  if (v instanceof admin.firestore.Timestamp) return true;
  if (typeof v === "string" && v.length > 0) return true;
  return false;
}

type TopicActivity = {lastStudiedAt: Date | null; missedSessions: number};

function aggregateActivity(
  todayIso: string,
  docs: admin.firestore.DocumentData[],
): Map<string, TopicActivity> {
  const [ty, tm, td] = todayIso.split("-").map((x) => Number.parseInt(x, 10));
  const todayStart = Date.UTC(ty, tm - 1, td);
  const lastByTopic = new Map<string, Date>();
  const missedByTopic = new Map<string, number>();

  for (const data of docs) {
    if (sessionDocIsDeleted(data)) continue;
    const topicId = String(data["topicId"] ?? "").trim();
    if (!topicId) continue;
    const dateIso = String(data["date"] ?? "").trim();
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateIso);
    if (!m) continue;
    const y = Number(m[1]);
    const mo = Number(m[2]);
    const d = Number(m[3]);
    const sessionDay = Date.UTC(y, mo - 1, d);
    const isPast = sessionDay < todayStart;
    const completed = data["completed"] === true;

    if (completed) {
      const existing = lastByTopic.get(topicId);
      const asDate = new Date(sessionDay);
      if (!existing || asDate.getTime() > existing.getTime()) {
        lastByTopic.set(topicId, asDate);
      }
    } else if (isPast) {
      missedByTopic.set(topicId, (missedByTopic.get(topicId) ?? 0) + 1);
    }
  }

  const keys = new Set<string>([...lastByTopic.keys(), ...missedByTopic.keys()]);
  const out = new Map<string, TopicActivity>();
  for (const k of keys) {
    out.set(k, {
      lastStudiedAt: lastByTopic.get(k) ?? null,
      missedSessions: missedByTopic.get(k) ?? 0,
    });
  }
  return out;
}

async function loadTopicActivityFromActivePlan(
  db: admin.firestore.Firestore,
  uid: string,
  todayIso: string,
): Promise<Map<string, TopicActivity>> {
  const activeSnap = await db
    .collection("users")
    .doc(uid)
    .collection("studyPlans")
    .where("status", "==", "active")
    .limit(1)
    .get();
  if (activeSnap.empty) return new Map();
  const sinceIso = addCalendarDaysIso(todayIso, -ACTIVITY_WINDOW_DAYS);
  const sessSnap = await activeSnap.docs[0].ref
    .collection("sessions")
    .where("date", ">=", sinceIso)
    .get();
  return aggregateActivity(
    todayIso,
    sessSnap.docs.map((d) => d.data()),
  );
}

async function loadDailyStudyMinutes(db: admin.firestore.Firestore, uid: string): Promise<number> {
  const userSnap = await db.collection("users").doc(uid).get();
  const raw = userSnap.data()?.["dailyStudyMinutes"];
  if (typeof raw !== "number" || !Number.isFinite(raw)) {
    return DEFAULT_DAILY_MINUTES;
  }
  return Math.min(MAX_DAILY_MINUTES, Math.max(MIN_DAILY_MINUTES, Math.floor(raw)));
}

async function filterExistingSubjectIds(
  db: admin.firestore.Firestore,
  uid: string,
  ids: string[],
): Promise<string[]> {
  if (ids.length === 0) {
    return [];
  }
  const snaps = await Promise.all(
    ids.map((id) => db.collection("users").doc(uid).collection("subjects").doc(id).get()),
  );
  return ids.filter((_, i) => snaps[i].exists);
}

async function resolveSubjectIdsForPlanDoc(
  db: admin.firestore.Firestore,
  uid: string,
  planData: admin.firestore.DocumentData,
): Promise<string[]> {
  const raw = planData["subjectIds"];
  if (Array.isArray(raw)) {
    const ids = [...new Set(raw.map((s) => String(s).trim()).filter((s) => s.length > 0))];
    if (ids.length > 0) {
      const existing = await filterExistingSubjectIds(db, uid, ids);
      if (existing.length > 0) {
        return existing;
      }
    }
  }
  const subsSnap = await db.collection("users").doc(uid).collection("subjects").get();
  return subsSnap.docs.map((d) => d.id);
}

/**
 * Builds day-by-day session allocations from current subject exams/topics, quizHistory
 * weak-topic signals, missed/completed activity on the active plan, and daily minutes.
 */
async function computeSessionWritesForUserSubjects(
  db: admin.firestore.Firestore,
  userId: string,
  subjectIds: string[],
): Promise<{
  sessionWrites: SessionWrite[];
  horizon: number;
  dailyMinutes: number;
  todayIso: string;
  uniqSubjects: string[];
}> {
  const uniqSubjects = [...new Set(subjectIds.map((s) => s.trim()).filter((s) => s.length > 0))];
  if (uniqSubjects.length === 0) {
    throw new HttpsError("invalid-argument", "subjectIds are required");
  }

  const todayIso = manamaTodayIso();
  const [signals, dailyMinutes, activity] = await Promise.all([
    loadQuizSignals(db, userId),
    loadDailyStudyMinutes(db, userId),
    loadTopicActivityFromActivePlan(db, userId, todayIso),
  ]);

  const baseTopics = await buildTopicsForUser(db, userId, uniqSubjects, todayIso, activity, signals);
  if (baseTopics.length === 0) {
    throw new HttpsError("failed-precondition", "No topics found for the selected subjects.");
  }

  const horizon = computeHorizonDays(todayIso, baseTopics);
  const virtualLastStudied = new Map<string, Date | null>();
  const virtualMissed = new Map<string, number>();
  for (const t of baseTopics) {
    virtualLastStudied.set(t.topicId, t.lastStudiedAt);
    virtualMissed.set(t.topicId, t.missedSessions);
  }

  const sessionWrites: SessionWrite[] = [];

  for (let offset = 0; offset < horizon; offset++) {
    const dayIso = addCalendarDaysIso(todayIso, offset);
    const dayInstant = bahrainNoonInstant(dayIso);
    const topicsForDay = baseTopics.map((t) =>
      cloneTopicWithOverrides(t, {
        lastStudiedAt: virtualLastStudied.get(t.topicId) ?? null,
        missedSessions: virtualMissed.get(t.topicId) ?? 0,
      }),
    );

    const minutesByTopic = buildDayPlan(topicsForDay, dailyMinutes, dayInstant);
    const ordered = [...minutesByTopic.entries()]
      .filter(([, m]) => m > 0)
      .sort((a, b) => b[1] - a[1]);

    let cursor = FIRST_SESSION_START_MINUTE;
    for (const [topicId, rawMinutes] of ordered) {
      const durationMin = Math.max(5, Math.min(240, rawMinutes));
      if (cursor + durationMin > 1440) {
        break;
      }
      sessionWrites.push({
        calendarIso: dayIso,
        topicId,
        durationMin,
        startMinute: cursor,
      });
      cursor += durationMin + SESSION_GAP_MINUTES;
      virtualLastStudied.set(topicId, dayInstant);
      virtualMissed.set(topicId, 0);
    }
  }

  return {sessionWrites, horizon, dailyMinutes, todayIso, uniqSubjects};
}

async function buildTopicsForUser(
  db: admin.firestore.Firestore,
  uid: string,
  subjectIds: string[],
  todayIso: string,
  activity: Map<string, TopicActivity>,
  signals: QuizSignals,
): Promise<TopicPerformanceInput[]> {
  const topics: TopicPerformanceInput[] = [];
  const seenSubject = new Set<string>();

  for (const subjectId of subjectIds) {
    const subSnap = await db
      .collection("users")
      .doc(uid)
      .collection("subjects")
      .doc(subjectId)
      .get();
    if (!subSnap.exists) continue;
    seenSubject.add(subjectId);
    const data = subSnap.data() ?? {};
    const name = String(data["name"] ?? "").trim();
    const examRaw = String(data["examDate"] ?? "");
    const examDate = examDateForSubject(examRaw, todayIso);

    const topicsSnap = await subSnap.ref.collection("topics").get();
    if (topicsSnap.empty) {
      if (name.length > 0) {
        const topicId = `subject_${subjectId}_overview`;
        const act = activity.get(topicId);
        topics.push({
          topicId,
          topicTitle: name,
          subjectId,
          subjectTitle: name,
          examDate,
          quizAccuracy: resolveQuizAccuracy(name, signals.globalScore, signals.byWeakTitle),
          subjectDifficulty: 0.5,
          lastStudiedAt: act?.lastStudiedAt ?? null,
          missedSessions: act?.missedSessions ?? 0,
        });
      }
      continue;
    }

    for (const t of topicsSnap.docs) {
      const td = t.data();
      const title =
        String(td["title"] ?? "").trim().length > 0 ? String(td["title"] ?? "").trim() : "Topic";
      const diffRaw = td["difficultyEstimate"];
      const difficulty =
        typeof diffRaw === "number" && Number.isFinite(diffRaw)
          ? clamp01(diffRaw)
          : 0.5;
      const act = activity.get(t.id);
      topics.push({
        topicId: t.id,
        topicTitle: title,
        subjectId,
        subjectTitle: name,
        examDate,
        quizAccuracy: resolveQuizAccuracy(title, signals.globalScore, signals.byWeakTitle),
        subjectDifficulty: difficulty,
        lastStudiedAt: act?.lastStudiedAt ?? null,
        missedSessions: act?.missedSessions ?? 0,
      });
    }
  }

  if (seenSubject.size === 0 && subjectIds.length > 0) {
    throw new HttpsError("invalid-argument", "No matching subjects for the given subjectIds.");
  }

  return topics;
}

function reasonForTopic(topic: TopicPerformanceInput, now: Date): string {
  if (topic.quizAccuracy < QUIZ_LOW_THRESHOLD) {
    return "low quiz performance";
  }
  const d = daysUntilExam(now, topic.examDate);
  if (d <= EXAM_SOON_WINDOW_DAYS) {
    return "upcoming exam";
  }
  if (topic.missedSessions > 0) {
    return "missed sessions";
  }
  const last = topic.lastStudiedAt;
  if (!last || (now.getTime() - last.getTime()) / (24 * 3600 * 1000) >= 7) {
    return "long time since last study";
  }
  return "baseline personalization";
}

function scoreTopics(topics: TopicPerformanceInput[], now: Date): ScoredTopic[] {
  const soonSubjects = new Set(
    topics
      .filter((t) => daysUntilExam(now, t.examDate) <= EXAM_SOON_WINDOW_DAYS)
      .map((t) => t.subjectId),
  );

  return topics.map((topic) => {
    const deadline = deadlineUrgency(now, topic.examDate);
    const weakness = clamp01(1 - topic.quizAccuracy);
    const difficulty = clamp01(topic.subjectDifficulty);
    const timeSince = timeSinceLastStudied(now, topic.lastStudiedAt);
    const lowQ = lowQuizBoost(topic.quizAccuracy, QUIZ_LOW_THRESHOLD);
    const examSoon = examSoonBoost(now, topic.examDate, EXAM_SOON_WINDOW_DAYS);
    const subjectSoonBoost = soonSubjects.has(topic.subjectId) ? 0.25 : 0;
    const missed = missedSessionsBoost(topic.missedSessions);
    const score =
      deadline +
      weakness +
      difficulty +
      timeSince +
      lowQ +
      examSoon +
      subjectSoonBoost +
      missed;
    return {
      source: topic,
      score,
      reason: reasonForTopic(topic, now),
    };
  });
}

function minSessionMinutes(totalMinutes: number): number {
  if (totalMinutes <= 30) return totalMinutes;
  if (totalMinutes <= 60) return 20;
  return 25;
}

function allocateMinutes(sortedByPriority: ScoredTopic[], totalMinutes: number): Map<string, number> {
  if (sortedByPriority.length === 0 || totalMinutes <= 0) return new Map();

  const minSession = minSessionMinutes(totalMinutes);
  const maxTopics = Math.max(1, Math.min(sortedByPriority.length, Math.floor(totalMinutes / minSession)));
  const selected = sortedByPriority.slice(0, maxTopics);

  const result = new Map<string, number>();
  for (const t of sortedByPriority) {
    result.set(t.source.topicId, 0);
  }

  const sum = selected.reduce((acc, t) => acc + t.score, 0);
  if (sum <= 0) {
    const even = Math.floor(totalMinutes / selected.length);
    for (const t of selected) {
      result.set(t.source.topicId, even);
    }
    let leftover = totalMinutes - even * selected.length;
    for (const t of selected) {
      if (leftover <= 0) break;
      result.set(t.source.topicId, (result.get(t.source.topicId) ?? 0) + 1);
      leftover -= 1;
    }
    return result;
  }

  let remaining = totalMinutes;
  for (const t of selected) {
    result.set(t.source.topicId, minSession);
    remaining -= minSession;
  }
  if (remaining < 0) {
    let deficit = -remaining;
    for (const t of [...selected].reverse()) {
      if (deficit <= 0) break;
      const current = result.get(t.source.topicId) ?? 0;
      if (current <= 0) continue;
      const take = Math.min(current, deficit);
      result.set(t.source.topicId, current - take);
      deficit -= take;
    }
    return result;
  }

  if (remaining === 0) return result;

  for (const t of selected) {
    const share = (t.score / sum) * remaining;
    const extra = Math.floor(share);
    result.set(t.source.topicId, (result.get(t.source.topicId) ?? 0) + extra);
  }
  let used = [...result.values()].reduce((a, b) => a + b, 0);
  let leftover = totalMinutes - used;
  let i = 0;
  while (leftover > 0 && selected.length > 0) {
    const topic = selected[i % selected.length];
    result.set(topic.source.topicId, (result.get(topic.source.topicId) ?? 0) + 1);
    leftover -= 1;
    i += 1;
  }

  return result;
}

function redistributeForMissedSessions(
  sortedByPriority: ScoredTopic[],
  allocated: Map<string, number>,
  totalMinutes: number,
): Map<string, number> {
  if (sortedByPriority.length === 0) return allocated;
  const result = new Map(allocated);
  const missedTopics = sortedByPriority.filter((t) => t.source.missedSessions > 0);
  if (missedTopics.length === 0) return result;

  const minSession = minSessionMinutes(totalMinutes);
  const donorFloor = Math.round(minSession * 1.5);
  const perMissedBonus = Math.round(Math.min(25, Math.max(5, totalMinutes / 12)));

  for (const missed of missedTopics) {
    let bonus = Math.min(
      Math.floor(totalMinutes / 2),
      missed.source.missedSessions * perMissedBonus,
    );
    while (bonus > 0) {
      let donor: ScoredTopic | undefined;
      for (const candidate of [...sortedByPriority].reverse()) {
        if (candidate.source.topicId === missed.source.topicId) continue;
        if ((result.get(candidate.source.topicId) ?? 0) > donorFloor) {
          donor = candidate;
          break;
        }
      }
      if (!donor) break;
      result.set(donor.source.topicId, (result.get(donor.source.topicId) ?? 0) - 1);
      result.set(missed.source.topicId, (result.get(missed.source.topicId) ?? 0) + 1);
      bonus -= 1;
    }
  }
  return result;
}

function buildDayPlan(
  topics: TopicPerformanceInput[],
  availableStudyMinutes: number,
  dayInstant: Date,
): Map<string, number> {
  if (topics.length === 0 || availableStudyMinutes <= 0) return new Map();
  const scored = scoreTopics(topics, dayInstant);
  scored.sort((a, b) => b.score - a.score);
  let allocated = allocateMinutes(scored, availableStudyMinutes);
  allocated = redistributeForMissedSessions(scored, allocated, availableStudyMinutes);
  return allocated;
}

function computeHorizonDays(todayIso: string, topics: TopicPerformanceInput[]): number {
  let maxExamOffset = 0;
  const todayMs = bahrainNoonInstant(todayIso).getTime();
  for (const t of topics) {
    const examIso = calendarIsoInManama(t.examDate);
    const examMs = bahrainNoonInstant(examIso).getTime();
    const diffDays = Math.ceil((examMs - todayMs) / (24 * 3600 * 1000));
    if (diffDays > maxExamOffset) maxExamOffset = diffDays;
  }
  const fromExams = Math.min(MAX_HORIZON_DAYS, Math.max(MIN_HORIZON_DAYS, maxExamOffset + 2));
  return fromExams;
}

function cloneTopicWithOverrides(
  t: TopicPerformanceInput,
  overrides: {lastStudiedAt: Date | null; missedSessions: number},
): TopicPerformanceInput {
  return {
    ...t,
    lastStudiedAt: overrides.lastStudiedAt,
    missedSessions: overrides.missedSessions,
  };
}

export async function runGenerateStudyPlan(
  db: admin.firestore.Firestore,
  userId: string,
  subjectIds: string[],
): Promise<{planId: string; generatedAt: string; sessionCount: number}> {
  const {sessionWrites, horizon, dailyMinutes, todayIso, uniqSubjects} =
    await computeSessionWritesForUserSubjects(db, userId, subjectIds);

  const activeSnap = await db
    .collection("users")
    .doc(userId)
    .collection("studyPlans")
    .where("status", "==", "active")
    .get();

  const planRef = db.collection("users").doc(userId).collection("studyPlans").doc();
  const generatedAt = new Date().toISOString();
  const firstIso = sessionWrites.length > 0 ? sessionWrites[0].calendarIso : todayIso;
  const lastIso = sessionWrites.length > 0 ? sessionWrites[sessionWrites.length - 1].calendarIso : todayIso;

  let batch = db.batch();
  let ops = 0;

  for (const doc of activeSnap.docs) {
    batch.update(doc.ref, {
      status: "superseded",
      supersededAt: generatedAt,
    });
    ops += 1;
    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  batch.set(planRef, {
    startDate: `${firstIso}T08:00:00.000Z`,
    endDate: `${lastIso}T20:00:00.000Z`,
    generatedAt,
    status: "active",
    generatedBy: "ai",
    lastAdjustedAt: generatedAt,
    subjectIds: uniqSubjects,
    horizonDays: horizon,
    dailyStudyMinutes: dailyMinutes,
  });
  ops += 1;

  for (const s of sessionWrites) {
    const sessionRef = planRef.collection("sessions").doc();
    batch.set(sessionRef, {
      date: s.calendarIso,
      topicId: s.topicId,
      durationMin: s.durationMin,
      startMinute: s.startMinute,
      completed: false,
    });
    ops += 1;
    if (ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  await batch.commit();

  return {planId: planRef.id, generatedAt, sessionCount: sessionWrites.length};
}

const FIRESTORE_BATCH_MAX_OPS = 450;

/**
 * Recomputes future (today onward) sessions on the active plan using the same
 * personalization as generate (exam proximity, quiz weak topics, missed sessions),
 * without creating a new plan document.
 */
export async function runRebalanceStudyPlan(
  db: admin.firestore.Firestore,
  userId: string,
): Promise<{
  updated: boolean;
  reason?: string;
  planId?: string;
  supersededIncompleteSessions?: number;
  sessionCount?: number;
}> {
  const planQuery = await db
    .collection("users")
    .doc(userId)
    .collection("studyPlans")
    .where("status", "==", "active")
    .limit(1)
    .get();

  if (planQuery.empty) {
    return {updated: false, reason: "no_active_plan"};
  }

  const planRef = planQuery.docs[0].ref;
  const planData = planQuery.docs[0].data();
  const subjectIds = await resolveSubjectIdsForPlanDoc(db, userId, planData);
  if (subjectIds.length === 0) {
    return {updated: false, reason: "no_subjects_on_plan"};
  }

  let computed: Awaited<ReturnType<typeof computeSessionWritesForUserSubjects>>;
  try {
    computed = await computeSessionWritesForUserSubjects(db, userId, subjectIds);
  } catch (err) {
    if (err instanceof HttpsError) {
      return {updated: false, reason: err.message};
    }
    throw err;
  }

  const {sessionWrites, horizon, dailyMinutes, todayIso, uniqSubjects} = computed;
  const lastIso =
    sessionWrites.length > 0 ? sessionWrites[sessionWrites.length - 1].calendarIso : todayIso;

  const futureSnap = await planRef.collection("sessions").where("date", ">=", todayIso).get();

  let batch = db.batch();
  let ops = 0;
  const deletedAt = new Date().toISOString();
  let supersededIncompleteSessions = 0;

  for (const doc of futureSnap.docs) {
    const data = doc.data();
    if (sessionDocIsDeleted(data)) {
      continue;
    }
    if (data["completed"] === true) {
      continue;
    }
    batch.update(doc.ref, {deletedAt});
    ops += 1;
    supersededIncompleteSessions += 1;
    if (ops >= FIRESTORE_BATCH_MAX_OPS) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) {
    await batch.commit();
  }

  const adjustedAt = new Date().toISOString();
  batch = db.batch();
  ops = 0;

  batch.update(planRef, {
    endDate: `${lastIso}T20:00:00.000Z`,
    lastAdjustedAt: adjustedAt,
    horizonDays: horizon,
    dailyStudyMinutes: dailyMinutes,
    subjectIds: uniqSubjects,
  });
  ops += 1;

  for (const s of sessionWrites) {
    const sessionRef = planRef.collection("sessions").doc();
    batch.set(sessionRef, {
      date: s.calendarIso,
      topicId: s.topicId,
      durationMin: s.durationMin,
      startMinute: s.startMinute,
      completed: false,
    });
    ops += 1;
    if (ops >= FIRESTORE_BATCH_MAX_OPS) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  await batch.commit();

  return {
    updated: true,
    planId: planRef.id,
    supersededIncompleteSessions,
    sessionCount: sessionWrites.length,
  };
}
