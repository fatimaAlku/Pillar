# Pillar Architecture (Flutter + Firebase)

## Principles

- **Clean Architecture** — presentation, domain, and data layers per feature
- **Feature-first modules** — scale by adding `features/<name>` rather than layering by type globally
- **Riverpod** — state management and dependency injection (`Provider`, `StreamProvider`, controllers)
- **Backend-for-frontend** — Cloud Functions for AI quizzes, study-plan generation, email OTP, Google Calendar API, and attempt persistence
- **Secure-by-default** — Firestore rules scope all learner data to `request.auth.uid`; OTP collection is server-only
- **Single calendar timezone** — `Asia/Bahrain` for “today”, plan horizons, and Google Calendar event payloads (client `app_time_zone.dart` + `studyPlanGenerator.ts`)

## High-level system

<p align="center">
  <img src="../apps/study_coach/assets/Pillar%20-%20high%20level%20design.png" alt="Pillar - high level design" width="640" />
</p>



1. **Flutter client** — UI, Riverpod state, Firestore streams, Storage uploads, local notifications, optional direct OpenAI for study chat only.
2. **Firebase Auth** — email/password; verification via OTP callables (`sendEmailVerificationOtp` / `verifyEmailWithOtp`). Current app build allows sign-in only for `@gmail.com` (`allowed_sign_in_email.dart`).
3. **Firestore** — all learner data under `users/{uid}/…`.
4. **Storage** — profile images under `users/{userId}/profile/…` (rules in `firebase/storage.rules`).
5. **Cloud Functions** — study plans, quiz AI, attempts, recommendations, email OTP, Google Calendar token lifecycle and event sync.

## App shell and navigation

Entry: `main.dart` → `StudyCoachApp` (`app/app.dart`).

**Auth gate:** splash → `AuthScreen` | `VerifyEmailScreen` | `PostSigninWelcomeScreen` | `DashboardScreen`.

**Main shell:** `DashboardScreen` with bottom navigation (`IndexedStack`):

| Index | Screen | Feature module |
|-------|--------|----------------|
| 0 | `HomeDashboardView` | `dashboard` (+ deep links to chat, tasks, focus, subjects) |
| 1 | `StudyPlanTabScreen` | `study_plan` |
| 2 | `QuizzesTabScreen` | `quizzes` |
| 3 | `RoadmapTabScreen` | `roadmap` |
| 4 | `ProfileTabScreen` | `profile` (+ subjects, settings, about) |

Global wrappers: `StudentReminderBootstrapper`, `GoogleCalendarOauthResumeBridge`, `rootScaffoldMessengerKey`.

**Locales:** `en`, `ar` via `appLocaleProvider` and `AppStrings` (not ARB files).

## Flutter structure

`apps/study_coach/lib`

### `app/`

Bootstrap, splash, `MaterialApp` theme/locale, auth gate.

### `core/`

| Area | Role |
|------|------|
| `firebase/` | `auth_service`, `firestore_service`, `storage_service` |
| `state/` | `app_providers` (repository wiring), theme/locale, Google Calendar connection |
| `constants/` | `FirestorePaths` |
| `config/` | `app_time_zone.dart` — Bahrain calendar helpers |
| `localization/` | `app_strings.dart` — EN/AR copy |
| `theme/` | `pillar_theme.dart` |
| `notifications/` | Local reminders synced from academic tasks |
| `oauth/` | Google Calendar PKCE channel, pending store, resume bridge, `google_oauth_env.dart` |
| `notes/` | PDF/text extraction for quiz note input |
| `ai/` | Thin callable wrapper (`AiService`) for legacy quiz/recommendation calls |
| `demo/` | `DemoDataSeeder` — profile-accessible sample subjects, plan, history, tasks |
| `onboarding/` | Post-sign-in welcome completion flag |

### `features/<feature>/`

Typical layers:

- `presentation/` — screens, widgets, Riverpod controllers
- `domain/` — entities, repository contracts
- `data/` — models, repository implementations, `*_service.dart` for callables or HTTP
- `application/` (where present) — side effects without UI (e.g. `schedule_study_plan_rebalance.dart`)

### Feature modules

| Module | Responsibility |
|--------|----------------|
| `auth` | Sign-in/up, session, email verification UI |
| `welcome` | Post-sign-in onboarding |
| `dashboard` | Home tab, inbox-style summaries |
| `subjects` | Subjects, topics, notes metadata and uploads |
| `study_plan` | Plans, sessions, personalization inputs, Calendar sync repository |
| `plans` | Legacy/domain plan types and `PlansRepository` contract (orchestration also lives in `study_plan`) |
| `quizzes` | Callable-backed generation (`CloudFunctionsQuizAiService`), runner, history, PDF export (`QuizReportExporter`, iOS share channel) |
| `progress` | Aggregates from Firestore / history |
| `recommendations` | Loads `insights` written by `generateRecommendations` |
| `roadmap` | Major catalog UI + `roadmapProgress` |
| `profile` | Profile editor, quiz history, reminders settings, privacy/about, demo seed |
| `academic_tasks` | Task CRUD under `academicTasks`, types/priorities, due dates |
| `study_chat` | Scoped chat UI; `OpenAiStudyChatAiService` uses `OPENAI_API_KEY` from environment |
| `focus` | Countdown timer for a study session; marks completion via study sessions repo |

## AI boundaries

| Capability | Where OpenAI runs | Key location |
|------------|-------------------|--------------|
| Quiz generation | Cloud Functions (`generateQuiz`, `generateQuizQuestions`) | Secret `OPENAI_API_KEY`; template fallback if unset |
| Study chat | Flutter (`OpenAiStudyChatAiService`) | `--dart-define=OPENAI_API_KEY=...` |
| Recommendations | Functions | Rule-based only (`generateRecommendations.ts`) |

The quiz runner uses `generateQuizQuestions` through `CloudFunctionsQuizAiService`, with a **local fallback** generator when the callable fails (offline/demo resilience).

`generateQuiz` also persists a quiz header under `users/{uid}/quizzes/{quizId}` and returns `{ quizId, title, questions }`.

## Firestore model

All primary learner data: `users/{uid}/…`. Rules (`firebase/firestore.rules`):

```text
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Server-only

| Path | Purpose |
|------|---------|
| `emailVerificationOtps/{docId}` | OTP hashes and expiry; **deny all client access** |

### Concept → path

| Concept | Path |
|---------|------|
| Profile | `users/{uid}` |
| Subjects / topics / notes | `users/{uid}/subjects/…`, `…/topics/…`, `…/notes/…` |
| Academic tasks | `users/{uid}/academicTasks/{taskId}` |
| Study plans / sessions | `users/{uid}/studyPlans/{planId}`, `…/sessions/{sessionId}` |
| Quizzes / attempts | `users/{uid}/quizzes/{quizId}`, `…/attempts/{attemptId}` |
| Quiz history (client summaries) | `users/{uid}/quizHistory/{entryId}` |
| Insights | `users/{uid}/insights/{insightId}` |
| Roadmap | `users/{uid}/roadmapProgress/{majorId}` |
| Google Calendar | `users/{uid}/integrations/google_calendar`, `users/{uid}/calendarLinks/{linkId}` |

`FirestorePaths` in the app lists the collection segment names used in code (integrations/calendar links are string literals in Functions and OAuth code).

### Field summaries

- **User:** `name`, `degree`, `year`, `timezone`, profile fields as used by profile UI
- **Subject:** `name`, `color`, `examDate` (ISO-8601)
- **Topic:** `title`, `difficultyEstimate`, note linkage (`notesRef` or equivalent)
- **Note:** `title`, `storagePath`, `createdAt`, `mimeType`
- **Academic task:** `title`, `type` (enum name), `subjectId`, `dueDate`, `estimatedMinutes`, `priority`, `status`, `notes`, `createdAt`, `updatedAt`, `completedAt`
- **Study plan:** `generatedAt`, `startDate`, `endDate`, `status`, `generatedBy`, `lastAdjustedAt`, `subjectIds`
- **Session:** `date` (`yyyy-MM-dd`), `topicId`, `durationMin`, `startMinute`, `completed`, optional `reason` (server planner: e.g. low quiz score, upcoming exam)
- **Quiz:** `sourceType` (`topic` | `mixed` | …), `topicIds`, `generatedAt`, `questionCount`, optional `title`
- **Question (when persisted):** `prompt`, `choices` / `options`, `answerIndex` / `correctIndex`, `order`, optional `explanation`, `topicId`, `topicTitle`
- **Attempt:** `score`, `weakTags`, `completedAt`
- **Quiz history entry:** `completedAt`, `scoreFraction`, `correctCount`, `totalCount`, `weakTopicTitles`, optional `linkedSubjectId`, `linkedSubjectTitle`, `linkedTopicIds`, `linkedTopicTitles`
- **Insight:** `weakAreas`, `strengths`, `confidenceByTopic`, `recommendationText`, `generatedAt`, `quizSampleSize`
- **Roadmap progress:** `completedItemKeys`, `updatedAt`, `version`, `totalItemCount`
- **Google Calendar integration:** `connected`, `needsReconnect`, `email`, `accessToken`, `refreshToken`, `accessTokenExpiresAt`, `oauthClientId`, timestamps
- **Calendar link:** `provider`, `planId`, `sessionId`, `eventId`, `status`, `updatedAt`

### Example documents

`users/{uid}`:

```json
{
  "name": "Alex Student",
  "degree": "BSc Computer Science",
  "year": "2",
  "timezone": "Asia/Bahrain"
}
```

`users/{uid}/academicTasks/{taskId}`:

```json
{
  "title": "Database project milestone",
  "type": "project",
  "subjectId": "subj_db",
  "dueDate": "2026-05-28T00:00:00.000Z",
  "estimatedMinutes": 120,
  "priority": "high",
  "status": "open",
  "notes": "",
  "createdAt": "2026-05-01T10:00:00.000Z",
  "updatedAt": "2026-05-01T10:00:00.000Z"
}
```

`users/{uid}/studyPlans/{planId}/sessions/{sessionId}`:

```json
{
  "date": "2026-05-22",
  "topicId": "topic_bst",
  "durationMin": 45,
  "startMinute": 1020,
  "completed": false,
  "reason": "low_quiz_performance"
}
```

`users/{uid}/quizHistory/{entryId}`:

```json
{
  "completedAt": "2026-05-01T15:05:00.000Z",
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

## Study plan generation (server)

`firebase/functions/src/studyPlanGenerator.ts`:

- Timezone: `APP_CALENDAR_TIME_ZONE = "Asia/Bahrain"`
- Inputs: subject exam dates, topic difficulty, quiz accuracy from history, missed sessions, activity window (14 days)
- Outputs: plan document + session writes with scored topics and `reason` strings
- `rebalanceStudyPlan` recomputes without requiring new `subjectIds`

Client triggers: `StudyPlanRepositoryImpl` callables; optional automatic rebalance via `schedule_study_plan_rebalance.dart`.

## Cloud Functions

All listed functions are **`onCall`** (Firebase Functions v2 HTTPS callable) unless noted. Require `request.auth` except where noted.

| Function | Role |
|----------|------|
| `generateStudyPlan` | `{ subjectIds }` → creates plan + sessions |
| `rebalanceStudyPlan` | Recomputes active plan from current data |
| `generateQuiz` | OpenAI quiz + writes quiz header; returns `{ quizId, title, questions }` |
| `generateQuizQuestions` | OpenAI questions only; `{ questions, sourceType }` (notes require `notesText`) |
| `submitQuizAttempt` | Writes `attempts/{attemptId}` |
| `generateRecommendations` | Rule-based insight → `insights/{insightId}` |
| `sendEmailVerificationOtp` | Sends OTP (secrets + SMTP on Cloud Run) |
| `verifyEmailWithOtp` | Validates OTP, updates verification state |
| `connectGoogleCalendarWithAuthCode` | PKCE token exchange; stores tokens under `integrations/google_calendar` |
| `getGoogleCalendarConnectionStatus` | Connection snapshot for UI |
| `disconnectGoogleCalendar` | Clears tokens |
| `syncStudySessionToGoogleCalendar` | `{ uid, planId, sessionId, action }` create/update/delete events; `calendarLinks` for idempotency |

**Secrets:** `OPENAI_API_KEY` (quiz callables), `EMAIL_OTP_SECRET` (OTP hashing). **SMTP:** Cloud Run env on `sendemailverificationotp`. **Google OAuth:** client id and redirect come from the app (`env.dev.json` / dart-define); refresh uses stored `oauthClientId`.

Implementation entry: `firebase/functions/src/index.ts`. Quiz prompts: `quizGeneration.ts`. OTP: `emailVerificationOtp.ts`.

## Client integrations

### Google Calendar

1. User completes OAuth in the app (platform channel / `url_launcher`).
2. App calls `connectGoogleCalendarWithAuthCode` with `code`, `redirectUri`, `codeVerifier`, `clientId`.
3. Study plan UI triggers `syncStudySessionToGoogleCalendar` on create/update/delete of sessions when connected.

### Local notifications

`StudentReminderSyncController` watches `academicTasks` and schedules reminders via `flutter_local_notifications` (permissions via profile → reminders screen).

### Quiz PDF export

`QuizReportExporter` builds a localized PDF after a run; on iOS, `pillar.quiz_report_share` method channel shares the file.

## Security notes

- Do not ship production builds with `OPENAI_API_KEY` in dart-define unless you accept client key exposure (study chat only today).
- Google Calendar tokens in Firestore are sensitive; only Functions should refresh or call the Calendar API.
- Firestore rules are broad per-user subtree; validate dangerous fields in Functions if you add server-written-only fields later.
- Storage rules currently allow only `users/{userId}/profile/**`.

## Scalability and evolution

- Repository interfaces keep Firestore and callables swappable for tests (`test/support/fake_repositories.dart`).
- Move **study chat** to a callable to match quiz key handling.
- Add composite Firestore indexes when querying across collections at scale (`firebase/firestore.indexes.json`).
- Queue long OpenAI jobs if generation latency becomes an issue.
- Expand offline caching for subjects and active plan streams if needed.

## Testing strategy

| Layer | Examples in repo |
|-------|------------------|
| Domain | `study_plan_personalization_service_test.dart` |
| Data / parsing | `quiz_ai_response_parser_test.dart`, `study_chat_preflight_test.dart` |
| Notifications | `student_reminder_test.dart` |
| Policy | `allowed_sign_in_email_test.dart` |
| UI / export | `widget_test.dart`, `quiz_report_exporter_smoke_test.dart`, `functionality_sweep_test.dart` |

Run: `cd apps/study_coach && flutter test`. Use Firebase emulators for rules and callable contract tests when adding integration coverage.
