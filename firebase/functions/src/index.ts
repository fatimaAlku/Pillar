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
    generatedAt: now,
    status: "draft",
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

  // Stub result. Replace with AI provider integration in a service layer.
  return {
    title: "Generated Quiz",
    questions: [
      {
        prompt: "What is the main concept of this topic?",
        choices: ["A", "B", "C", "D"],
        answerIndex: 0,
      },
    ],
  };
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
