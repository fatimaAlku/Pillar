# Pillar Architecture (Flutter + Firebase)

## Principles

- Clean Architecture for clear separation of concerns
- Feature-first folder structure for scale
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

Suggested feature modules:

- `subjects`
- `plans`
- `quizzes`
- `progress`
- `recommendations`

## Firestore Model (initial)

- `users/{uid}`
  - profile fields (name, degree, year, timezone)
- `users/{uid}/subjects/{subjectId}`
  - name, color, examDate
- `users/{uid}/subjects/{subjectId}/topics/{topicId}`
  - title, difficultyEstimate, notesRef
- `users/{uid}/studyPlans/{planId}`
  - generatedAt, dateRange, status
- `users/{uid}/studyPlans/{planId}/sessions/{sessionId}`
  - date, topicId, durationMin, completed
- `users/{uid}/quizzes/{quizId}`
  - sourceTopicIds, createdAt, questionCount
- `users/{uid}/quizzes/{quizId}/attempts/{attemptId}`
  - score, weakTags, completedAt
- `users/{uid}/insights/{insightId}`
  - weakAreas, confidenceByTopic, recommendationText

## Cloud Functions Boundaries

- `generateStudyPlan` (callable/https): creates plan from subjects/exam dates
- `generateQuiz` (callable/https): uses AI provider to build quiz payload
- `submitQuizAttempt` (callable/https): stores attempt and computes weak areas
- `rebalancePlan` (trigger/callable): updates sessions based on latest outcomes
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
