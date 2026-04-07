# Pillar Architecture (Flutter + Firebase)

## Principles

- Clean Architecture for clear separation of concerns
- Feature-first folder structure for scale
- Riverpod for state management + dependency injection
- Backend-for-frontend via Cloud Functions for AI and business logic
- Secure-by-default Firebase rules and least privilege access

## High-Level System

1. Flutter client handles UI, local state, and offline-friendly interactions.
2. Firebase Auth manages identity.
3. Firestore stores core learning data (subjects, topics, plans, quiz attempts, metrics).
4. Storage stores uploaded notes/resources.
5. Cloud Functions orchestrate:
   - Study plan generation
   - AI quiz generation from topics/notes
   - Personalized recommendations
   - Plan recalculation based on performance/deadlines

## Flutter Structure

`apps/study_coach/lib`

- `app`: app bootstrap, router, top-level providers
- `core`: shared services (auth client, firestore client, error handling, DI)
- `features/<feature>`
  - `presentation`: pages, widgets, controllers/view models
  - `domain`: entities, value objects, repository contracts, use cases
  - `data`: datasource adapters, DTOs, repository implementations

Implemented feature modules:

- `subjects`
- `study_plan`
- `quizzes`
- `progress`
- `recommendations`

## Firestore Model (initial)

All paths are under a single user root: `users/{uid}/…`. There are no top-level `subjects` or `quizzes` collections.

### Names you might expect (mapping)

| Concept | Path in this project |
|--------|----------------------|
| `study_plans` | `users/{uid}/studyPlans/{planId}` |
| `quiz_results` | `users/{uid}/quizzes/{quizId}/attempts/{attemptId}` |
| `progress_tracking` | Derived from completed `sessions`, quiz `attempts`, and optional `insights` docs |

### Collection tree

- `users/{uid}` — profile
- `users/{uid}/subjects/{subjectId}` — subject
- `users/{uid}/subjects/{subjectId}/topics/{topicId}` — topic
- `users/{uid}/subjects/{subjectId}/notes/{noteId}` — uploaded note metadata (optional)
- `users/{uid}/studyPlans/{planId}` — plan header
- `users/{uid}/studyPlans/{planId}/sessions/{sessionId}` — scheduled session
- `users/{uid}/quizzes/{quizId}` — quiz header
- `users/{uid}/quizzes/{quizId}/questions/{questionId}` — persisted question (optional; see Functions)
- `users/{uid}/quizzes/{quizId}/attempts/{attemptId}` — one quiz result / attempt
- `users/{uid}/insights/{insightId}` — aggregated recommendations / progress snapshot

### Field summaries

- **User:** `name`, `degree`, `year`, `timezone` (all optional strings until profile UI writes them)
- **Subject:** `name`, `color` (hex or palette id), `examDate` (ISO-8601 string)
- **Topic:** `title`, `difficultyEstimate` (number), `notesRef` (Storage path or note doc id)
- **Note:** `title`, `storagePath`, `createdAt`, `mimeType` (shape TBD when uploads ship)
- **Study plan:** `generatedAt`, `startDate`, `endDate`, `status`, `generatedBy`, `lastAdjustedAt`, `subjectIds` (see `generateStudyPlan`)
- **Session:** `date`, `topicId`, `durationMin`, `completed`
- **Quiz:** `sourceType`, `topicIds`, `generatedAt`, `questionCount` (see `generateQuiz`); optional `title`
- **Question:** `prompt`, `choices` (array of strings), `answerIndex` (int), `order` (int)
- **Attempt (quiz result):** `score`, `weakTags`, `completedAt`
- **Insight (progress / recommendations):** `weakAreas`, `strengths`, `confidenceByTopic`, `recommendationText`, `generatedAt`

### Example documents

`users/{uid}` (profile):

```json
{
  "name": "Alex Student",
  "degree": "BSc Computer Science",
  "year": "2",
  "timezone": "Asia/Kuwait"
}
```

`users/{uid}/subjects/{subjectId}`:

```json
{
  "name": "Data Structures",
  "color": "#5C6BC0",
  "examDate": "2026-06-15T00:00:00.000Z"
}
```

`users/{uid}/subjects/{subjectId}/topics/{topicId}`:

```json
{
  "title": "Binary search trees",
  "difficultyEstimate": 0.6,
  "notesRef": "notes/abc123.pdf"
}
```

`users/{uid}/subjects/{subjectId}/notes/{noteId}`:

```json
{
  "title": "Lecture 3",
  "storagePath": "users/{uid}/notes/abc123.pdf",
  "createdAt": "2026-04-01T12:00:00.000Z",
  "mimeType": "application/pdf"
}
```

`users/{uid}/studyPlans/{planId}`:

```json
{
  "generatedAt": "2026-04-01T10:00:00.000Z",
  "startDate": "2026-04-01T10:00:00.000Z",
  "endDate": "2026-06-15T23:59:59.000Z",
  "status": "active",
  "generatedBy": "ai",
  "lastAdjustedAt": "2026-04-01T10:00:00.000Z",
  "subjectIds": ["subj_bio", "subj_chem"]
}
```

`users/{uid}/studyPlans/{planId}/sessions/{sessionId}`:

```json
{
  "date": "2026-04-02",
  "topicId": "topic_bst",
  "durationMin": 45,
  "completed": false
}
```

`users/{uid}/quizzes/{quizId}`:

```json
{
  "sourceType": "topic",
  "topicIds": ["topic_bst", "topic_heaps"],
  "generatedAt": "2026-04-01T14:30:00.000Z",
  "questionCount": 5,
  "title": "Generated Quiz"
}
```

`users/{uid}/quizzes/{quizId}/questions/{questionId}`:

```json
{
  "order": 0,
  "prompt": "What is the main concept of this topic?",
  "choices": ["A", "B", "C", "D"],
  "answerIndex": 0
}
```

`users/{uid}/quizzes/{quizId}/attempts/{attemptId}`:

```json
{
  "score": 0.8,
  "weakTags": ["rotations", "balancing"],
  "completedAt": "2026-04-01T15:00:00.000Z"
}
```

`users/{uid}/insights/{insightId}`:

```json
{
  "weakAreas": ["time_management", "revision_consistency"],
  "strengths": ["short_quiz_accuracy"],
  "confidenceByTopic": { "topic_bst": 0.62 },
  "recommendationText": "Prioritize daily review blocks before new content.",
  "generatedAt": "2026-04-01T16:00:00.000Z"
}
```

## Cloud Functions Boundaries

- `generateStudyPlan` (callable/https): creates plan from subjects/exam dates
- `generateQuiz` (callable/https): uses AI provider to build quiz payload
- `submitQuizAttempt` (callable/https): stores attempt and computes weak areas
- `rebalanceStudyPlan` (trigger/callable): updates sessions based on latest outcomes
- `dailyDeadlineSweep` (scheduled): marks urgency and sends reminders

Keep AI API keys only in Functions config/secrets. Never expose in Flutter.

## Scalability Notes

- Use repository interfaces in domain layer to keep provider-agnostic design
- Add caching and offline sync for key reads (subjects/plans)
- Add background jobs for heavy AI processing if response latency grows
- Add analytics events for recommendation quality feedback loop

## Testing Strategy

- Domain unit tests for use cases (pure logic)
- Data layer tests with fake repositories
- Widget tests for key screens
- Emulator integration tests for callable functions + Firestore rules
