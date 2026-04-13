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
