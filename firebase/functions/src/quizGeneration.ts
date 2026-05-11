/**
 * Server-side quiz generation: OpenAI when OPENAI_API_KEY is configured (secret or env),
 * otherwise template questions (same as legacy buildQuestions).
 *
 * Production: firebase functions:secrets:set OPENAI_API_KEY
 * Emulator: export OPENAI_API_KEY=... in the shell before emulators:start
 */
import {defineSecret} from "firebase-functions/params";

export const openAiApiKey = defineSecret("OPENAI_API_KEY");

export type QuizQuestionShape = {
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

function resolveOpenAiKey(): string | undefined {
  const fromEnv = process.env.OPENAI_API_KEY?.trim();
  if (fromEnv) {
    return fromEnv;
  }
  try {
    const fromSecret = openAiApiKey.value()?.trim();
    if (fromSecret) {
      return fromSecret;
    }
  } catch {
    // Secret not available in some local contexts
  }
  return undefined;
}

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

function emphasisInstruction(emphasis: string): string {
  switch (emphasis) {
    case "definitions":
      return "Prioritize terminology, definitions, and fine-grained conceptual distinctions grounded in the notes.";
    case "application":
      return "Prioritize short scenarios, examples, and applying ideas to new situations that the notes support.";
    case "exam":
    case "exam_style":
      return "Use formal exam-style stems, no hints in wording, and distractors that feel like real university MCQs.";
    case "balanced":
    default:
      return "Balance recall, understanding, and light application according to what the notes support.";
  }
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

function resolveCanonicalTopic(
  candidate: string,
  prompt: string,
  allowed: string[],
  fallback: string,
): string {
  if (allowed.length === 0) {
    return candidate.trim() || fallback;
  }

  const candidateLower = candidate.trim().toLowerCase();
  if (candidate.trim()) {
    for (const t of allowed) {
      if (t.toLowerCase() === candidateLower) {
        return t;
      }
    }
    for (const t of allowed) {
      const tl = t.toLowerCase();
      if (!tl) {
        continue;
      }
      if (candidateLower.includes(tl) || tl.includes(candidateLower)) {
        return t;
      }
    }
  }

  const promptLower = prompt.toLowerCase();
  const promptTokens = promptLower
    .split(/[^a-z0-9\u0600-\u06ff]+/)
    .filter((t) => t.length > 0);

  let bestMatch: string | undefined;
  let bestScore = 0;
  for (const t of allowed) {
    const tl = t.toLowerCase();
    if (!tl) {
      continue;
    }
    let score = 0;
    if (promptLower.includes(tl)) {
      score = tl.length * 2;
    } else {
      for (const word of tl.split(/\s+/)) {
        if (word.length < 3) {
          continue;
        }
        if (promptLower.includes(word)) {
          score += word.length * 2;
          continue;
        }
        const prefix = word.substring(0, word.length < 4 ? word.length : 4);
        for (const tok of promptTokens) {
          if (tok.length < 3) {
            continue;
          }
          if (tok.startsWith(prefix) || word.startsWith(tok)) {
            score += prefix.length;
            break;
          }
        }
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestMatch = t;
    }
  }
  if (bestMatch) {
    return bestMatch;
  }

  return allowed[0]!;
}

function coerceOptionText(rawOption: unknown): string {
  if (rawOption && typeof rawOption === "object" && !Array.isArray(rawOption)) {
    const optionMap = rawOption as Record<string, unknown>;
    const keys = ["text", "option", "label", "value", "answer"] as const;
    for (const key of keys) {
      const v = optionMap[key];
      if (typeof v === "string" && v.trim()) {
        return v.trim();
      }
      if (v != null && String(v).trim()) {
        return String(v).trim();
      }
    }
  }
  return String(rawOption ?? "").trim();
}

function resolveCorrectIndex(q: Record<string, unknown>, options: string[]): number | null {
  const correctIndexRaw = q["correctIndex"] ?? q["answerIndex"];
  const fromIndex = coerceIndex(correctIndexRaw);
  if (fromIndex != null && fromIndex >= 0 && fromIndex <= 3) {
    return fromIndex;
  }

  const correctAnswerRaw = q["correctAnswer"] ?? q["answer"] ?? q["correct_option"];
  const answer = correctAnswerRaw != null ? String(correctAnswerRaw).trim() : "";
  if (!answer) {
    return null;
  }

  const oneBased = parseInt(answer, 10);
  if (!Number.isNaN(oneBased)) {
    if (oneBased >= 1 && oneBased <= 4) {
      return oneBased - 1;
    }
    if (oneBased >= 0 && oneBased <= 3) {
      return oneBased;
    }
  }

  const letter = answer.toUpperCase().charAt(0);
  const letters: Record<string, number> = {A: 0, B: 1, C: 2, D: 3};
  if (letters[letter] != null) {
    return letters[letter]!;
  }

  const cleaned = answer.replace(/^[A-D][\).\:\-\s]+/, "");
  for (let idx = 0; idx < options.length; idx++) {
    const option = options[idx]!.trim().toLowerCase();
    if (option === answer.toLowerCase() || option === cleaned.toLowerCase()) {
      return idx;
    }
  }
  return null;
}

function coerceIndex(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.floor(value);
  }
  if (typeof value === "string") {
    const n = parseInt(value, 10);
    return Number.isNaN(n) ? null : n;
  }
  return null;
}

function parseQuestionsFromOpenAiJson(
  root: Record<string, unknown>,
  allowedTopics: string[],
  fallbackTopic: string,
): QuizQuestionShape[] {
  const rawQuestions = root["questions"];
  if (!Array.isArray(rawQuestions)) {
    throw new Error('Missing "questions" array');
  }

  const canonicalAllowed = allowedTopics.map((t) => t.trim()).filter((t) => t.length > 0);
  const fb = canonicalAllowed.length > 0 ? canonicalAllowed[0]! : fallbackTopic;

  const out: QuizQuestionShape[] = [];
  for (let i = 0; i < rawQuestions.length; i++) {
    const item = rawQuestions[i];
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      throw new Error(`Question[${i}] must be an object`);
    }
    const q = item as Record<string, unknown>;

    let prompt = "";
    for (const key of ["prompt", "question"] as const) {
      const v = q[key];
      if (typeof v === "string" && v.trim()) {
        prompt = v.trim();
        break;
      }
      if (v != null && String(v).trim()) {
        prompt = String(v).trim();
        break;
      }
    }
    if (!prompt) {
      throw new Error(`Question[${i}].prompt must be non-empty`);
    }

    let explanation = "Review your notes for a detailed explanation.";
    for (const key of ["explanation", "rationale", "reasoning"] as const) {
      const v = q[key];
      if (typeof v === "string" && v.trim()) {
        explanation = v.trim();
        break;
      }
    }

    const optionsRaw = q["options"] ?? q["choices"];
    if (!Array.isArray(optionsRaw) || optionsRaw.length < 4) {
      throw new Error(`Question[${i}].options must have at least 4 items`);
    }
    const options = optionsRaw.slice(0, 4).map(coerceOptionText);
    if (options.some((o) => !o.trim())) {
      throw new Error(`Question[${i}].options cannot be empty`);
    }

    const correctIndex = resolveCorrectIndex(q, options);
    if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
      throw new Error(`Question[${i}].correctIndex must resolve to 0-3`);
    }

    const rawTopicTitle = q["topicTitle"] != null ? String(q["topicTitle"]).trim() : "";
    const canonicalTitle = resolveCanonicalTopic(rawTopicTitle, prompt, canonicalAllowed, fb);

    const rawTopicId = q["topicId"] != null ? String(q["topicId"]).trim() : "";
    const topicId = rawTopicId.length > 0 ? rawTopicId : slugify(canonicalTitle);

    const idRaw = q["id"] != null ? String(q["id"]).trim() : "";
    const id = idRaw.length > 0 ? idRaw : `ai_q_${i + 1}`;

    out.push({
      id,
      topicId,
      topicTitle: canonicalTitle,
      prompt,
      options,
      choices: options,
      correctIndex,
      answerIndex: correctIndex,
      explanation,
    });
  }

  if (out.length === 0) {
    throw new Error("No questions returned");
  }
  return out;
}

function tryParseJson(raw: string): unknown {
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function parseJsonObjectFromModelContent(content: string): Record<string, unknown> {
  const direct = tryParseJson(content);
  if (direct && typeof direct === "object" && !Array.isArray(direct)) {
    return direct as Record<string, unknown>;
  }

  const fenced = /```(?:json)?\s*([\s\S]*?)\s*```/i.exec(content);
  if (fenced?.[1]) {
    const fromFence = tryParseJson(fenced[1].trim());
    if (fromFence && typeof fromFence === "object" && !Array.isArray(fromFence)) {
      return fromFence as Record<string, unknown>;
    }
  }

  throw new Error("Could not parse JSON object from AI response");
}

const OPENAI_TIMEOUT_MS = 45_000;

async function fetchOpenAiQuizQuestions(
  apiKey: string,
  input: {
    topics: string[];
    notesText: string;
    difficulty: string;
    numberOfQuestions: number;
    languageCode: string;
    quizEmphasis: string;
  },
): Promise<QuizQuestionShape[]> {
  const allowedTopicsList = input.topics.length > 0 ? input.topics : ["General"];
  const allowedTopicsJson = JSON.stringify(allowedTopicsList);
  const isArabic = input.languageCode === "ar";
  const emphasisLine = emphasisInstruction(input.quizEmphasis);

  const systemPrompt = [
    "You generate high-quality MCQ quizzes for university students.",
    'Return JSON only with shape: {"questions":[{"prompt":"string","options":["a","b","c","d"],"correctIndex":0,"explanation":"string","topicTitle":"string"}]}',
    "Rules:",
    "- Use the notes as the primary source of truth.",
    "- Every correct answer must be directly supported by the notes.",
    "- Keep distractors plausible but incorrect relative to the notes.",
    "- Exactly 4 options per question.",
    "- correctIndex must be 0,1,2,3.",
    `- Return exactly ${input.numberOfQuestions} questions.`,
    `- Difficulty level is ${input.difficulty}.`,
    `- Question style: ${emphasisLine}`,
    `- topicTitle MUST be copied VERBATIM from this allowed list: ${allowedTopicsJson}.`,
    '- NEVER invent generic labels (e.g. "general", "miscellaneous", "common mistakes", "fundamentals", "review"). Always pick the most specific allowed topic that the question targets.',
    "- Distribute questions across the allowed topics so each chosen topic is represented when there are enough questions.",
    isArabic
      ? "- Write all questions, options, and explanations in Arabic. Keep topicTitle EXACTLY as in the allowed list (do not translate)."
      : "- Write all questions, options, and explanations in English. Keep topicTitle EXACTLY as in the allowed list.",
  ].join("\n");

  const userPrompt = [
    `Allowed topics (use as topicTitle exactly): ${allowedTopicsJson}`,
    `Notes:\n${input.notesText}`,
  ].join("\n\n");

  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), OPENAI_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.4,
        response_format: {type: "json_object"},
        messages: [
          {role: "system", content: systemPrompt},
          {role: "user", content: userPrompt},
        ],
      }),
      signal: ac.signal,
    });
  } finally {
    clearTimeout(timer);
  }

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI HTTP ${response.status}: ${body.slice(0, 500)}`);
  }

  const decoded = (await response.json()) as Record<string, unknown>;
  const choices = decoded["choices"];
  if (!Array.isArray(choices) || choices.length === 0) {
    throw new Error("OpenAI response missing choices");
  }
  const firstChoice = choices[0] as Record<string, unknown>;
  const message = firstChoice["message"] as Record<string, unknown> | undefined;
  const content = message?.["content"];
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("OpenAI content missing");
  }

  const jsonRoot = parseJsonObjectFromModelContent(content.trim());
  const fallbackTopic = allowedTopicsList[0] ?? "General";
  return parseQuestionsFromOpenAiJson(jsonRoot, allowedTopicsList, fallbackTopic);
}

function fitQuestionCount(
  ai: QuizQuestionShape[],
  n: number,
  templateInput: {
    topics: string[];
    notesText?: string;
    difficulty: "easy" | "medium" | "hard";
  },
): QuizQuestionShape[] {
  const trimmed = ai.slice(0, n);
  if (trimmed.length >= n) {
    return trimmed;
  }
  const need = n - trimmed.length;
  const extra = buildQuestions({
    ...templateInput,
    numberOfQuestions: need,
  });
  return [
    ...trimmed,
    ...extra.map((q, i) => ({
      ...q,
      id: `ai_q_${trimmed.length + i + 1}`,
    })),
  ];
}

export type ProduceQuizInput = {
  topics: string[];
  notesText?: string;
  difficulty?: string;
  numberOfQuestions?: number;
  languageCode?: string;
  quizEmphasis?: string;
};

/**
 * Uses OpenAI when API key is set and notes are non-empty; otherwise template questions.
 */
export async function produceQuizQuestions(raw: ProduceQuizInput): Promise<QuizQuestionShape[]> {
  const difficulty = normalizeDifficulty(raw.difficulty);
  const numberOfQuestions = normalizeQuestionCount(raw.numberOfQuestions);
  const topicsTrimmed = raw.topics.map((t) => t.trim()).filter((t) => t.length > 0);
  const topics = topicsTrimmed.length > 0 ? topicsTrimmed : ["General"];
  const notesText = raw.notesText?.trim() ?? "";
  const languageCode = raw.languageCode === "ar" ? "ar" : "en";
  const quizEmphasis = raw.quizEmphasis?.trim() || "balanced";

  const key = resolveOpenAiKey();
  if (key && notesText.length > 0) {
    try {
      const ai = await fetchOpenAiQuizQuestions(key, {
        topics,
        notesText,
        difficulty: raw.difficulty ?? "medium",
        numberOfQuestions,
        languageCode,
        quizEmphasis,
      });
      if (ai.length > 0) {
        return fitQuestionCount(ai, numberOfQuestions, {topics, notesText, difficulty});
      }
    } catch (e) {
      console.error("OpenAI quiz generation failed, using template fallback", e);
    }
  }

  return buildQuestions({
    topics,
    notesText,
    difficulty,
    numberOfQuestions,
  });
}
