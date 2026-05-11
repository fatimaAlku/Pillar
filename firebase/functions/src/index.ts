import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {sendEmailVerificationOtp, verifyEmailWithOtp} from "./emailVerificationOtp";
import {buildRecommendationsInsight} from "./generateRecommendations";
import {openAiApiKey, produceQuizQuestions} from "./quizGeneration";
import {
  APP_CALENDAR_TIME_ZONE,
  addCalendarDaysIso,
  manamaTodayIso,
  runGenerateStudyPlan,
  runRebalanceStudyPlan,
} from "./studyPlanGenerator";

admin.initializeApp();

export {sendEmailVerificationOtp, verifyEmailWithOtp};

type GeneratePlanRequest = {
  subjectIds: string[];
};

export const generateStudyPlan = onCall<GeneratePlanRequest>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Unauthenticated");
  }

  const {subjectIds} = request.data;
  if (!subjectIds || subjectIds.length === 0) {
    throw new HttpsError("invalid-argument", "subjectIds are required");
  }

  const userId = request.auth.uid;
  return runGenerateStudyPlan(admin.firestore(), userId, subjectIds);
});

type GenerateQuizRequest = {
  topicIds: string[];
  notesText?: string;
  difficulty?: string;
  numberOfQuestions?: number;
  languageCode?: string;
  quizEmphasis?: string;
};

export const generateQuiz = onCall<GenerateQuizRequest>(
  {secrets: [openAiApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Unauthenticated");
    }

    const topicIds = (request.data.topicIds ?? [])
      .map((t) => t.trim())
      .filter((t) => t.length > 0);
    const notesText = request.data.notesText?.trim();
    if (topicIds.length === 0 && !notesText) {
      throw new HttpsError("invalid-argument", "Provide topicIds or notesText");
    }

    const userId = request.auth.uid;
    const quizRef = admin
      .firestore()
      .collection("users")
      .doc(userId)
      .collection("quizzes")
      .doc();

    const questions = await produceQuizQuestions({
      topics: topicIds,
      notesText,
      difficulty: request.data.difficulty,
      numberOfQuestions: request.data.numberOfQuestions,
      languageCode: request.data.languageCode,
      quizEmphasis: request.data.quizEmphasis,
    });

    const payload = {
      title: "Generated Quiz",
      questions,
    };

    await quizRef.set({
      sourceType: notesText ? "mixed" : "topic",
      topicIds,
      generatedAt: new Date().toISOString(),
      questionCount: payload.questions.length,
    });

    return {quizId: quizRef.id, ...payload};
  },
);

type GenerateQuizQuestionsRequest = {
  topics?: string[];
  notesText?: string;
  difficulty?: string;
  numberOfQuestions?: number;
  languageCode?: string;
  quizEmphasis?: string;
};

export const generateQuizQuestions = onCall<GenerateQuizQuestionsRequest>(
  {secrets: [openAiApiKey]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Unauthenticated");
    }

    const topics = (request.data.topics ?? [])
      .map((topic) => topic.trim())
      .filter((topic) => topic.length > 0);
    const notesText = request.data.notesText?.trim();
    if (!notesText || notesText.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Notes are required. Paste or upload notes so AI can generate the quiz.",
      );
    }

    const questions = await produceQuizQuestions({
      topics,
      notesText,
      difficulty: request.data.difficulty,
      numberOfQuestions: request.data.numberOfQuestions,
      languageCode: request.data.languageCode,
      quizEmphasis: request.data.quizEmphasis,
    });

    return {questions};
  },
);

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
    throw new HttpsError("unauthenticated", "Unauthenticated");
  }

  const userId = request.auth.uid;
  return runRebalanceStudyPlan(admin.firestore(), userId);
});

export const generateRecommendations = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Unauthenticated");
  }

  const userId = request.auth.uid;
  const db = admin.firestore();
  const payload = await buildRecommendationsInsight(db, userId);

  const insightRef = db
    .collection("users")
    .doc(userId)
    .collection("insights")
    .doc();

  await insightRef.set({
    weakAreas: payload.weakAreas,
    strengths: payload.strengths,
    confidenceByTopic: payload.confidenceByTopic,
    recommendationText: payload.recommendationText,
    generatedAt: payload.generatedAt,
    quizSampleSize: payload.quizSampleSize,
  });

  return {
    insightId: insightRef.id,
    generatedAt: payload.generatedAt,
    quizSampleSize: payload.quizSampleSize,
  };
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


