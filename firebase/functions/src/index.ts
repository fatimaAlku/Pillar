import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";

admin.initializeApp();

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
};

export const generateQuiz = onCall<GenerateQuizRequest>(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const {topicIds, notesText} = request.data;
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
    questions: [
      {
        prompt: "What is the main concept of this topic?",
        choices: ["A", "B", "C", "D"],
        answerIndex: 0,
      },
    ],
  };

  await quizRef.set({
    sourceType: notesText ? "mixed" : "topic",
    topicIds,
    generatedAt: new Date().toISOString(),
    questionCount: payload.questions.length,
  });

  return {quizId: quizRef.id, ...payload};
});

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
