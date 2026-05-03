import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

admin.initializeApp();

/** Study sessions use calendar dates in this zone (Manama / Bahrain). */
const APP_CALENDAR_TIME_ZONE = "Asia/Bahrain";

type GeneratePlanRequest = {
  subjectIds: string[];
};

export const generateStudyPlan = onCall<GeneratePlanRequest>(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const {subjectIds} = request.data;
  if (!subjectIds || subjectIds.length === 0) {
    throw new Error("subjectIds are required");
  }

  const userId = request.auth.uid;
  const planRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("studyPlans")
    .doc();

  const now = new Date().toISOString();
  await planRef.set({
    startDate: now,
    endDate: now,
    generatedAt: now,
    status: "active",
    generatedBy: "ai",
    lastAdjustedAt: now,
    subjectIds,
  });

  return {planId: planRef.id, generatedAt: now};
});

type GenerateQuizRequest = {
  topicIds: string[];
  notesText?: string;
  difficulty?: string;
  numberOfQuestions?: number;
};

export const generateQuiz = onCall<GenerateQuizRequest>(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const {topicIds, notesText} = request.data;
  const difficulty = normalizeDifficulty(request.data.difficulty);
  const numberOfQuestions = normalizeQuestionCount(request.data.numberOfQuestions);
  if ((!topicIds || topicIds.length === 0) && !notesText) {
    throw new Error("Provide topicIds or notesText");
  }

  const userId = request.auth.uid;
  const quizRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("quizzes")
    .doc();

  // AI integration flow:
  // 1) Validate auth/input
  // 2) Fetch context (topics/notes/history)
  // 3) Call external LLM provider
  // 4) Validate normalized response schema
  // 5) Persist quiz + questions
  const payload = {
    title: "Generated Quiz",
    questions: buildQuestions({
      topics: topicIds,
      notesText,
      difficulty,
      numberOfQuestions,
    }),
  };

  await quizRef.set({
    sourceType: notesText ? "mixed" : "topic",
    topicIds,
    generatedAt: new Date().toISOString(),
    questionCount: payload.questions.length,
  });

  return {quizId: quizRef.id, ...payload};
});

type GenerateQuizQuestionsRequest = {
  topics?: string[];
  notesText?: string;
  difficulty?: string;
  numberOfQuestions?: number;
};

export const generateQuizQuestions = onCall<GenerateQuizQuestionsRequest>(
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthenticated");
    }

    const topics = (request.data.topics ?? [])
      .map((topic) => topic.trim())
      .filter((topic) => topic.length > 0);
    const notesText = request.data.notesText?.trim();
    const difficulty = normalizeDifficulty(request.data.difficulty);
    const numberOfQuestions = normalizeQuestionCount(request.data.numberOfQuestions);

    if (topics.length === 0 && !notesText) {
      throw new Error("Provide topics or notesText");
    }

    const questions = buildQuestions({
      topics,
      notesText,
      difficulty,
      numberOfQuestions,
    });

    return {questions};
  }
);

function normalizeDifficulty(rawDifficulty?: string): "easy" | "medium" | "hard" {
  const lowered = rawDifficulty?.toLowerCase();
  if (lowered === "easy" || lowered === "hard") {
    return lowered;
  }
  return "medium";
}

function normalizeQuestionCount(rawCount?: number): number {
  const count = rawCount ?? 10;
  if (!Number.isFinite(count)) {
    return 10;
  }
  return Math.min(20, Math.max(1, Math.floor(count)));
}

type QuizQuestionShape = {
  id: string;
  topicId: string;
  topicTitle: string;
  prompt: string;
  options: string[];
  choices: string[];
  correctIndex: number;
  answerIndex: number;
  explanation: string;
};

function buildQuestions(input: {
  topics: string[];
  notesText?: string;
  difficulty: "easy" | "medium" | "hard";
  numberOfQuestions: number;
}): QuizQuestionShape[] {
  const sourceTopics = input.topics.length > 0 ? input.topics : ["General"];
  const notesSignal = !!input.notesText && input.notesText.length > 0;

  return Array.from({length: input.numberOfQuestions}, (_, index) => {
    const topicTitle = sourceTopics[index % sourceTopics.length];
    const topicId = slugify(topicTitle);
    const difficultyHint = difficultyLabel(input.difficulty);
    const prompt = promptFor({
      topicTitle,
      index,
      hasNotes: notesSignal,
      difficultyHint,
    });
    const correctStatement = correctStatementFor({
      topicTitle,
      difficultyHint,
      index,
    });
    const distractors = distractorsFor({topicTitle, index});
    const correctIndex = index % 4;
    const options = Array<string>(4).fill("");
    let distractorPointer = 0;
    for (let optionIndex = 0; optionIndex < 4; optionIndex++) {
      if (optionIndex === correctIndex) {
        options[optionIndex] = correctStatement;
      } else {
        options[optionIndex] = distractors[distractorPointer++];
      }
    }

    return {
      id: `ai_q_${index + 1}`,
      topicId,
      topicTitle,
      prompt,
      options,
      choices: options,
      correctIndex,
      answerIndex: correctIndex,
      explanation: `Fallback question tuned for ${input.difficulty} difficulty.`,
    };
  });
}

function promptFor(input: {
  topicTitle: string;
  index: number;
  hasNotes: boolean;
  difficultyHint: string;
}): string {
  const prompts = [
    `Which statement is most accurate about ${input.topicTitle}?`,
    `Which option best explains the key idea in ${input.topicTitle}?`,
    `Choose the most reliable summary of ${input.topicTitle}.`,
    `Which statement would be best to remember for ${input.topicTitle}?`,
    `Which choice correctly describes ${input.topicTitle} at a ${input.difficultyHint} level?`,
  ];
  const notesPrompts = [
    `Based on your notes, which statement best matches ${input.topicTitle}?`,
    `From your notes, what is the strongest summary of ${input.topicTitle}?`,
    `Using your notes, which option is most accurate for ${input.topicTitle}?`,
    `According to your notes, which statement correctly captures ${input.topicTitle}?`,
    `From your notes at a ${input.difficultyHint} level, which statement fits ${input.topicTitle}?`,
  ];
  const pool = input.hasNotes ? notesPrompts : prompts;
  return pool[input.index % pool.length];
}

function correctStatementFor(input: {
  topicTitle: string;
  difficultyHint: string;
  index: number;
}): string {
  const variants = [
    `${input.topicTitle} focuses on core principles and practical application (${input.difficultyHint}).`,
    `${input.topicTitle} builds understanding by connecting concepts step by step.`,
    `${input.topicTitle} is best learned by identifying patterns and testing examples.`,
    `${input.topicTitle} requires using definitions accurately before solving problems.`,
  ];
  return variants[input.index % variants.length];
}

function distractorsFor(input: {topicTitle: string; index: number}): string[] {
  const base = [
    `${input.topicTitle} is mainly about memorizing unrelated facts.`,
    `${input.topicTitle} never uses structured reasoning.`,
    `${input.topicTitle} can be solved by guessing without understanding.`,
    `${input.topicTitle} avoids using definitions and examples.`,
    `${input.topicTitle} is only relevant in one narrow scenario.`,
    `${input.topicTitle} has no link between theory and practice.`,
  ];
  return [
    base[input.index % base.length],
    base[(input.index + 2) % base.length],
    base[(input.index + 4) % base.length],
  ];
}

function slugify(value: string): string {
  return `topic_${value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "") || "general"}`;
}

function difficultyLabel(difficulty: "easy" | "medium" | "hard"): string {
  switch (difficulty) {
    case "easy":
      return "intro";
    case "hard":
      return "advanced";
    default:
      return "balanced";
  }
}

type SubmitQuizAttemptRequest = {
  quizId: string;
  score: number;
  weakTags: string[];
};

export const submitQuizAttempt = onCall<SubmitQuizAttemptRequest>(
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthenticated");
    }

    const {quizId, score, weakTags} = request.data;
    if (!quizId) {
      throw new Error("quizId is required");
    }

    const userId = request.auth.uid;
    const attemptRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("quizzes")
      .doc(quizId)
      .collection("attempts")
      .doc();

    await attemptRef.set({
      score,
      weakTags,
      completedAt: new Date().toISOString(),
    });

    return {attemptId: attemptRef.id};
  }
);

export const rebalanceStudyPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const userId = request.auth.uid;
  const planQuery = await admin
    .firestore()
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
  await planRef.update({
    lastAdjustedAt: new Date().toISOString(),
  });

  return {updated: true, planId: planRef.id};
});

export const generateRecommendations = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const userId = request.auth.uid;
  const insightRef = admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("insights")
    .doc();

  const now = new Date().toISOString();
  await insightRef.set({
    weakAreas: ["time_management", "revision_consistency"],
    strengths: ["short_quiz_accuracy"],
    confidenceByTopic: {"topicA": 0.62},
    recommendationText: "Prioritize daily review blocks before new content.",
    generatedAt: now,
  });

  return {insightId: insightRef.id, generatedAt: now};
});

type GoogleCalendarSyncAction = "create" | "update" | "delete";

type SyncStudySessionToGoogleCalendarRequest = {
  uid: string;
  planId: string;
  sessionId: string;
  action: GoogleCalendarSyncAction;
};

type ConnectGoogleCalendarWithAuthCodeRequest = {
  code: string;
  redirectUri: string;
  codeVerifier: string;
  clientId: string;
};

export const connectGoogleCalendarWithAuthCode = onCall<ConnectGoogleCalendarWithAuthCodeRequest>(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const code = request.data.code?.trim();
    const redirectUri = request.data.redirectUri?.trim();
    const codeVerifier = request.data.codeVerifier?.trim();
    const clientId = request.data.clientId?.trim();
    if (!code || !redirectUri || !codeVerifier || !clientId) {
      throw new HttpsError("invalid-argument", "code, redirectUri, codeVerifier and clientId are required.");
    }
    const tokenResult = await exchangeGoogleAuthCode({
      code,
      redirectUri,
      codeVerifier,
      clientId,
    });
    const email = await fetchGoogleEmail(tokenResult.accessToken);
    await admin
      .firestore()
      .collection("users")
      .doc(request.auth.uid)
      .collection("integrations")
      .doc("google_calendar")
      .set({
        provider: "google_calendar",
        connected: true,
        needsReconnect: false,
        email,
        accessToken: tokenResult.accessToken,
        refreshToken: tokenResult.refreshToken ?? null,
        oauthClientId: clientId,
        accessTokenExpiresAt: new Date(Date.now() + tokenResult.expiresIn * 1000).toISOString(),
        updatedAt: new Date().toISOString(),
      }, {merge: true});
    return {connected: true, email};
  }
);

export const getGoogleCalendarConnectionStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const integrationRef = admin
    .firestore()
    .collection("users")
    .doc(request.auth.uid)
    .collection("integrations")
    .doc("google_calendar");
  const snap = await integrationRef.get();
  if (!snap.exists) {
    return {connected: false};
  }
  const data = snap.data() ?? {};
  return {
    connected: data["connected"] === true,
    email: data["email"] ?? null,
    needsReconnect: data["needsReconnect"] === true,
    lastSyncedAt: data["lastSyncedAt"] ?? null,
  };
});

export const disconnectGoogleCalendar = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }
  const integrationRef = admin
    .firestore()
    .collection("users")
    .doc(request.auth.uid)
    .collection("integrations")
    .doc("google_calendar");
  await integrationRef.set({
    connected: false,
    needsReconnect: false,
    accessToken: admin.firestore.FieldValue.delete(),
    refreshToken: admin.firestore.FieldValue.delete(),
    accessTokenExpiresAt: admin.firestore.FieldValue.delete(),
    disconnectedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }, {merge: true});
  return {disconnected: true};
});

export const syncStudySessionToGoogleCalendar = onCall<SyncStudySessionToGoogleCalendarRequest>(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }
    const {uid, planId, sessionId, action} = request.data;
    if (uid !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Cannot sync another user.");
    }
    if (!planId || !sessionId || !action) {
      throw new HttpsError("invalid-argument", "uid, planId, sessionId and action are required.");
    }

    const db = admin.firestore();
    const integrationRef = db
      .collection("users")
      .doc(uid)
      .collection("integrations")
      .doc("google_calendar");
    const integrationSnap = await integrationRef.get();
    if (!integrationSnap.exists || integrationSnap.data()?.["connected"] !== true) {
      return {skipped: true, reason: "google_calendar_not_connected"};
    }
    const integrationData = integrationSnap.data() ?? {};
    const resolvedAccessToken = await ensureGoogleAccessToken({
      integrationRef,
      integrationData,
    });
    if (!resolvedAccessToken) {
      await integrationRef.set(
        {needsReconnect: true, connected: false, updatedAt: new Date().toISOString()},
        {merge: true}
      );
      return {skipped: true, reason: "reconnect_required"};
    }

    const linkRef = db
      .collection("users")
      .doc(uid)
      .collection("calendarLinks")
      .doc(`google_${planId}_${sessionId}`);

    if (action === "delete") {
      const existingLink = await linkRef.get();
      if (existingLink.exists) {
        const eventId = existingLink.data()?.["eventId"] as string | undefined;
        if (eventId && eventId.length > 0) {
          await deleteGoogleCalendarEvent(resolvedAccessToken, eventId);
        }
      }
      await linkRef.set({
        provider: "google_calendar",
        planId,
        sessionId,
        status: "deleted",
        updatedAt: new Date().toISOString(),
      }, {merge: true});
      return {synced: true, action};
    }

    const sessionRef = db
      .collection("users")
      .doc(uid)
      .collection("studyPlans")
      .doc(planId)
      .collection("sessions")
      .doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      return {skipped: true, reason: "session_not_found"};
    }
    const eventPayload = buildGoogleCalendarEventPayload(sessionSnap.data() ?? {});
    const existingLink = await linkRef.get();
    const existingEventId = existingLink.data()?.["eventId"] as string | undefined;

    if (action === "update" && existingEventId) {
      await patchGoogleCalendarEvent(resolvedAccessToken, existingEventId, eventPayload);
      await linkRef.set({
        provider: "google_calendar",
        eventId: existingEventId,
        planId,
        sessionId,
        status: "synced",
        updatedAt: new Date().toISOString(),
      }, {merge: true});
      return {synced: true, action, eventId: existingEventId};
    }

    if (existingEventId) {
      await patchGoogleCalendarEvent(resolvedAccessToken, existingEventId, eventPayload);
      await linkRef.set({
        provider: "google_calendar",
        eventId: existingEventId,
        planId,
        sessionId,
        status: "synced",
        updatedAt: new Date().toISOString(),
      }, {merge: true});
      return {synced: true, action: "update", eventId: existingEventId};
    }

    const createdEvent = await createGoogleCalendarEvent(resolvedAccessToken, eventPayload);
    await linkRef.set({
      provider: "google_calendar",
      eventId: createdEvent.id,
      planId,
      sessionId,
      status: "synced",
      updatedAt: new Date().toISOString(),
    }, {merge: true});
    await integrationRef.set({
      lastSyncedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    }, {merge: true});
    return {synced: true, action: "create", eventId: createdEvent.id};
  }
);

function manamaTodayIso(): string {
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

function addCalendarDaysIso(isoDate: string, days: number): string {
  const [y, mo, day] = isoDate.split("-").map(Number);
  const shifted = new Date(Date.UTC(y, mo - 1, day + days));
  return `${shifted.getUTCFullYear()}-${pad(shifted.getUTCMonth() + 1)}-${pad(shifted.getUTCDate())}`;
}

function buildGoogleCalendarEventPayload(sessionData: Record<string, unknown>) {
  const date = asString(sessionData["date"]);
  const startMinute = asNumber(sessionData["startMinute"]);
  const durationMin = Math.max(5, Math.min(240, asNumber(sessionData["durationMin"], 30)));
  const normalizedDate = /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : manamaTodayIso();
  const m = Math.max(0, Math.min(1439, startMinute));
  const hour = Math.floor(m / 60);
  const minute = m % 60;
  const startWall = `${normalizedDate}T${pad(hour)}:${pad(minute)}:00`;

  const endMinuteTotal = m + durationMin;
  const extraDays = Math.floor(endMinuteTotal / 1440);
  const endM = endMinuteTotal % 1440;
  const endDateStr = extraDays > 0 ? addCalendarDaysIso(normalizedDate, extraDays) : normalizedDate;
  const endHour = Math.floor(endM / 60);
  const endMin = endM % 60;
  const endWall = `${endDateStr}T${pad(endHour)}:${pad(endMin)}:00`;

  return {
    summary: "Pillar Study Session",
    description: `Planned study session (${durationMin} minutes).`,
    start: {
      dateTime: startWall,
      timeZone: APP_CALENDAR_TIME_ZONE,
    },
    end: {
      dateTime: endWall,
      timeZone: APP_CALENDAR_TIME_ZONE,
    },
  };
}

async function ensureGoogleAccessToken(input: {
  integrationRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
  integrationData: FirebaseFirestore.DocumentData;
}): Promise<string | null> {
  const accessToken = asString(input.integrationData["accessToken"]);
  const refreshToken = asString(input.integrationData["refreshToken"]);
  const oauthClientId = asString(input.integrationData["oauthClientId"]);
  const expiresAtIso = asString(input.integrationData["accessTokenExpiresAt"]);
  if (accessToken && !isExpired(expiresAtIso, 60)) {
    return accessToken;
  }
  if (!refreshToken) {
    return null;
  }
  if (!oauthClientId) {
    return null;
  }
  const refreshed = await refreshGoogleToken(refreshToken, oauthClientId);
  if (!refreshed) {
    return null;
  }
  await input.integrationRef.set({
    accessToken: refreshed.accessToken,
    refreshToken: refreshed.refreshToken ?? refreshToken,
    accessTokenExpiresAt: new Date(Date.now() + refreshed.expiresIn * 1000).toISOString(),
    connected: true,
    needsReconnect: false,
    updatedAt: new Date().toISOString(),
  }, {merge: true});
  return refreshed.accessToken;
}

async function refreshGoogleToken(refreshToken: string, clientId: string): Promise<{
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
} | null> {
  if (!clientId) {
    return null;
  }
  const body = new URLSearchParams({
    client_id: clientId,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });
  const response = await safeFetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: body.toString(),
  });
  if (!response.ok) {
    return null;
  }
  const payload = (await response.json()) as Record<string, unknown>;
  const accessToken = asString(payload["access_token"]);
  const expiresIn = asNumber(payload["expires_in"], 3600);
  if (!accessToken) {
    return null;
  }
  return {
    accessToken,
    refreshToken: asString(payload["refresh_token"]) || undefined,
    expiresIn,
  };
}

async function exchangeGoogleAuthCode(input: {
  code: string;
  redirectUri: string;
  codeVerifier: string;
  clientId: string;
}): Promise<{
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
}> {
  if (!input.clientId) {
    throw new HttpsError("invalid-argument", "clientId is required.");
  }
  const body = new URLSearchParams({
    client_id: input.clientId,
    grant_type: "authorization_code",
    code: input.code,
    redirect_uri: input.redirectUri,
    code_verifier: input.codeVerifier,
  });
  const response = await safeFetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: body.toString(),
  });
  const raw = await response.text();
  if (!response.ok) {
    let googleDetail = `HTTP ${response.status}`;
    try {
      const errJson = JSON.parse(raw) as Record<string, unknown>;
      const gErr = asString(errJson["error"]);
      const gDesc = asString(errJson["error_description"]).replace(/\+/g, " ");
      if (gErr) {
        googleDetail = gDesc ? `${gErr}: ${gDesc}` : gErr;
      }
    } catch {
      if (raw.trim()) {
        googleDetail = raw.trim().slice(0, 280);
      }
    }
    console.error("Google token exchange failed:", googleDetail);
    throw new HttpsError(
      "invalid-argument",
      `Google token exchange failed: ${googleDetail}`,
    );
  }
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    throw new HttpsError("internal", "Google token response was not valid JSON.");
  }
  const accessToken = asString(payload["access_token"]);
  const expiresIn = asNumber(payload["expires_in"], 3600);
  if (!accessToken) {
    throw new HttpsError("internal", "Google token response missing access_token.");
  }
  return {
    accessToken,
    refreshToken: asString(payload["refresh_token"]) || undefined,
    expiresIn,
  };
}

async function fetchGoogleEmail(accessToken: string): Promise<string | null> {
  const response = await safeFetch("https://www.googleapis.com/oauth2/v2/userinfo", {
    method: "GET",
    headers: {Authorization: `Bearer ${accessToken}`},
  });
  if (!response.ok) {
    return null;
  }
  const payload = (await response.json()) as Record<string, unknown>;
  const email = asString(payload["email"]);
  return email || null;
}

async function createGoogleCalendarEvent(
  accessToken: string,
  payload: Record<string, unknown>
): Promise<{id: string}> {
  const response = await safeFetch("https://www.googleapis.com/calendar/v3/calendars/primary/events", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError("internal", `Google Calendar create failed: ${body}`);
  }
  const data = (await response.json()) as Record<string, unknown>;
  const id = asString(data["id"]);
  if (!id) {
    throw new HttpsError("internal", "Google Calendar create returned no event id.");
  }
  return {id};
}

async function patchGoogleCalendarEvent(
  accessToken: string,
  eventId: string,
  payload: Record<string, unknown>
): Promise<void> {
  const response = await safeFetch(
    `https://www.googleapis.com/calendar/v3/calendars/primary/events/${eventId}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    }
  );
  if (response.status === 404) {
    throw new HttpsError("not-found", "Linked Google Calendar event not found.");
  }
  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError("internal", `Google Calendar update failed: ${body}`);
  }
}

async function deleteGoogleCalendarEvent(accessToken: string, eventId: string): Promise<void> {
  const response = await safeFetch(
    `https://www.googleapis.com/calendar/v3/calendars/primary/events/${eventId}`,
    {
      method: "DELETE",
      headers: {Authorization: `Bearer ${accessToken}`},
    }
  );
  if (response.status === 404) {
    return;
  }
  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError("internal", `Google Calendar delete failed: ${body}`);
  }
}

function isExpired(expiresAtIso: string, bufferSeconds: number): boolean {
  if (!expiresAtIso) return true;
  const expiresAt = Date.parse(expiresAtIso);
  if (!Number.isFinite(expiresAt)) return true;
  return Date.now() + bufferSeconds * 1000 >= expiresAt;
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.floor(value);
  }
  return fallback;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function pad(value: number): string {
  return value.toString().padStart(2, "0");
}

function safeFetch(input: string, init?: RequestInit): Promise<Response> {
  const fetchFn = (globalThis as {fetch?: typeof fetch}).fetch;
  if (!fetchFn) {
    throw new HttpsError("failed-precondition", "Fetch API is unavailable in runtime.");
  }
  return fetchFn(input, init);
}


