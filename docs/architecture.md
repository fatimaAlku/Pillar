# Pillar Architecture (Flutter + Firebase)

## Principles

- Clean Architecture for clear separation of concerns
- Feature-first folder structure for scale
- Riverpod for state management and dependency injection
- Backend-for-frontend via Cloud Functions for AI, email delivery, and sensitive integrations
- Secure-by-default Firebase rules and least-privilege access

## High-Level System

1. Flutter client handles UI, local state, and offline-friendly reads where caching applies.
2. Firebase Auth manages identity; optional email verification uses OTP callables (see below).
3. Firestore stores learning data under each user document (`users/{uid}/…`).
4. Storage stores uploaded notes and related binaries.
5. Cloud Functions orchestrate:
   - Study plan generation and rebalancing (server-side scheduling logic, Bahrain calendar context)
   - OpenAI-backed quiz generation (authenticated callables only; key stays on the server)
   - Quiz attempt persistence under the quiz document tree
   - Rule-based progress recommendations derived from `quizHistory` and legacy attempt data
   - Google Calendar OAuth token exchange and event sync (tokens stored in Firestore; API calls from Functions)

## Flutter Structure

`apps/study_coach/lib`

- `app`: bootstrap, splash, root scaffold / messaging
- `core`: Firebase facades (`auth_service`, `firestore_service`, `storage_service`), shared providers, theme, localization, OAuth bridges (Google Calendar), Firestore path constants, shared AI entry points used by features
- `features/<feature>`
  - `presentation`: screens, widgets, controllers
  - `domain`: entities, repository contracts, domain services
  - `data`: DTOs, repository implementations, feature-specific services
  - `application` (where present): side-effect orchestration (for example study-plan rebalance scheduling) without UI

Feature modules (non-exhaustive; see tree for full detail):

- `auth` — sign-in, session, email verification UX
- `welcome` — post-sign-in onboarding
- `dashboard` — home shell
- `subjects` — courses, topics, notes
- `study_plan` — plans, sessions, personalization, optional Google Calendar sync triggers
- `quizzes` — generation via callables, runner, history
- `progress` — aggregates and detail views
- `recommendations` — loading insights produced by Functions
- `roadmap` — major/course roadmap UI and `roadmapProgress` persistence
- `profile` — profile, quiz history screen, settings-related surfaces
- `study_chat` — conversational study helper; current implementation calls OpenAI from the app using a compile-time `OPENAI_API_KEY` (`--dart-define`), which is separate from quiz generation (server callables only)

## Firestore Model

All primary learner data lives under `users/{uid}/…`. Client rules allow read/write only when `request.auth.uid == userId` for that subtree.

### Top-level (server-only)

| Path | Purpose |
|------|---------|
| `emailVerificationOtps/{docId}` | OTP state for email verification; **no client access** (rules deny reads/writes) |

### Names you might expect (mapping)

| Concept | Path in this project |
|--------|----------------------|
| Study plans | `users/{uid}/studyPlans/{planId}` |
| Quiz document + attempts | `users/{uid}/quizzes/{quizId}` and `…/attempts/{attemptId}` |
| Denormalized quiz history (for plans + insights) | `users/{uid}/quizHistory/{entryId}` |
| Progress / recommendations snapshot | `users/{uid}/insights/{insightId}` |
| Roadmap checklists | `users/{uid}/roadmapProgress/{majorId}` |
| Google Calendar | `users/{uid}/integrations/google_calendar`, `users/{uid}/calendarLinks/{linkId}` |

### Collection tree

- `users/{uid}` — profile
- `users/{uid}/subjects/{subjectId}` — subject
- `users/{uid}/subjects/{subjectId}/topics/{topicId}` — topic
- `users/{uid}/subjects/{subjectId}/notes/{noteId}` — note metadata (optional)
- `users/{uid}/studyPlans/{planId}` — plan header
- `users/{uid}/studyPlans/{planId}/sessions/{sessionId}` — scheduled session
- `users/{uid}/quizzes/{quizId}` — quiz header (see `generateQuiz`)
- `users/{uid}/quizzes/{quizId}/questions/{questionId}` — optional persisted questions (when used)
- `users/{uid}/quizzes/{quizId}/attempts/{attemptId}` — attempt written via `submitQuizAttempt`
- `users/{uid}/quizHistory/{entryId}` — client-written summary rows after a run (scores, weak topics, course/topic linkage)
- `users/{uid}/insights/{insightId}` — output of `generateRecommendations`
- `users/{uid}/roadmapProgress/{majorId}` — completed item keys for a roadmap major
- `users/{uid}/integrations/google_calendar` — connection status and OAuth tokens (managed by Functions)
- `users/{uid}/calendarLinks/{linkId}` — maps study sessions to Google Calendar event IDs

### Field summaries

- **User:** `name`, `degree`, `year`, `timezone` (optional; shape evolves with profile UI)
- **Subject:** `name`, `color`, `examDate` (ISO-8601 string)
- **Topic:** `title`, `difficultyEstimate`, `notesRef` (or equivalent note linkage)
- **Note:** `title`, `storagePath`, `createdAt`, `mimeType` (as implemented in uploads)
- **Study plan:** `generatedAt`, `startDate`, `endDate`, `status`, `generatedBy`, `lastAdjustedAt`, `subjectIds` (align with `generateStudyPlan` / `studyPlanGenerator`)
- **Session:** `date` (calendar day), `topicId`, `durationMin`, `startMinute` (optional; minutes from midnight for intraday scheduling), `completed`
- **Quiz:** `sourceType`, `topicIds`, `generatedAt`, `questionCount`; optional `title`
- **Question:** `prompt`, `choices`, `answerIndex`, `order`
- **Attempt (under quiz):** `score`, `weakTags`, `completedAt` (callable `submitQuizAttempt`)
- **Quiz history entry:** `completedAt`, `scoreFraction`, `correctCount`, `totalCount`, `weakTopicTitles`, optional `linkedSubjectId`, `linkedSubjectTitle`, `linkedTopicIds`, `linkedTopicTitles`
- **Insight:** `weakAreas`, `strengths`, `confidenceByTopic`, `recommendationText`, `generatedAt`, `quizSampleSize`
- **Roadmap progress:** `completedItemKeys` (array of strings), `updatedAt`, `version`, `totalItemCount`
- **Google Calendar integration:** `connected`, `needsReconnect`, tokens and expiry fields (see Functions; treat as sensitive)

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
  "startMinute": 540,
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

`users/{uid}/quizHistory/{entryId}`:

```json
{
  "completedAt": "2026-04-01T15:05:00.000Z",
  "scoreFraction": 0.8,
  "correctCount": 4,
  "totalCount": 5,
  "weakTopicTitles": ["AVL rotations"],
  "linkedSubjectId": "subj_ds",
  "linkedSubjectTitle": "Data Structures",
  "linkedTopicIds": ["topic_bst"],
  "linkedTopicTitles": ["Binary search trees"]
}
```

`users/{uid}/insights/{insightId}`:

```json
{
  "weakAreas": ["time_management", "revision_consistency"],
  "strengths": ["short_quiz_accuracy"],
  "confidenceByTopic": { "topic_bst": 0.62 },
  "recommendationText": "Prioritize daily review blocks before new content.",
  "generatedAt": "2026-04-01T16:00:00.000Z",
  "quizSampleSize": 12
}
```

`users/{uid}/roadmapProgress/{majorId}`:

```json
{
  "completedItemKeys": ["intro_cs_1", "intro_cs_2"],
  "updatedAt": "2026-04-01T17:00:00.000Z",
  "version": 1,
  "totalItemCount": 40
}
```

## Cloud Functions Boundaries

All of the following are **callable** functions (`onCall`) unless noted. They expect an authenticated Firebase user unless stated otherwise.

| Function | Role |
|----------|------|
| `generateStudyPlan` | Builds plan + sessions from selected subjects (writes Firestore) |
| `rebalanceStudyPlan` | Recomputes sessions from current exams/topics and performance signals |
| `generateQuiz` | OpenAI quiz; creates `quizzes/{quizId}` header and returns `{ quizId, title, questions }` |
| `generateQuizQuestions` | OpenAI-only question payload (requires `notesText`; returns `{ questions }` without persisting a quiz header) |
| `submitQuizAttempt` | Writes `quizzes/{quizId}/attempts/{attemptId}` |
| `generateRecommendations` | Derives insight from quiz history + attempts; writes `insights/{insightId}` (no LLM) |
| `sendEmailVerificationOtp` | Sends OTP email (secret `EMAIL_OTP_SECRET`; SMTP env in production) |
| `verifyEmailWithOtp` | Validates OTP and updates Auth/Firestore as implemented |
| `connectGoogleCalendarWithAuthCode` | Exchanges OAuth code; stores tokens under `integrations/google_calendar` |
| `getGoogleCalendarConnectionStatus` | Returns connection snapshot for the signed-in user |
| `disconnectGoogleCalendar` | Clears tokens and marks disconnected |
| `syncStudySessionToGoogleCalendar` | Creates/updates/deletes Calendar events; uses `calendarLinks` for idempotency |

**Secrets and config:** keep `OPENAI_API_KEY`, `EMAIL_OTP_SECRET`, and SMTP settings in Functions secrets / managed environment for quiz generation and email OTP. The study-chat feature may still expect `OPENAI_API_KEY` via `--dart-define` at build time (see `OpenAiStudyChatAiService`); treat that as a separate, client-exposed key risk if you ship production builds—prefer moving chat to a callable if you need parity with quiz security.

See `firebase/functions/src/quizGeneration.ts` and `emailVerificationOtp.ts` for server setup comments.

## Scalability Notes

- Repository interfaces in the domain layer keep Firebase and AI providers swappable and testable.
- Consider stronger offline caching for subjects and active plans if latency or connectivity is an issue.
- If OpenAI call latency grows, add queue-based generation and push results to Firestore.
- Instrument recommendation and quiz quality with analytics if you need a feedback loop.

## Testing Strategy

- Domain unit tests for pure logic (for example study plan personalization helpers).
- Data layer tests with fakes/mocks for `FirebaseFirestore` or repository implementations.
- Widget tests for critical flows.
- Emulator and integration tests for Firestore rules and callable contracts where feasible.
