# Pillar

Cross-platform study assistant for university students, built with Flutter and Firebase.

## Product Goals

- Let students organize subjects, topics, and exam deadlines
- Generate dynamic study plans based on time and performance
- Generate AI quizzes from notes/topics
- Track progress and identify weak areas
- Automatically adjust the plan as deadlines approach

## Tech Stack

- Frontend: Flutter (iOS, Android, Web)
- Backend: Firebase Auth, Firestore, Storage, Cloud Functions
- AI: OpenAI via authenticated HTTPS callables (quiz generation)

## Repository Layout

- `apps/study_coach`: Flutter application
- `firebase`: Firebase config, security rules, and Cloud Functions
- `docs`: Architecture and implementation guidance

## Quick Start

### 1) Flutter App

```bash
cd apps/study_coach
flutter pub get
flutter run
```

iPhone Simulator quick start from repo root:

```bash
./scripts/run-ios-simulator.sh
```

Optional: choose a different simulator device name:

```bash
./scripts/run-ios-simulator.sh "iPhone 16"
```

### 2) Firebase Functions

```bash
cd firebase/functions
npm install
npm run build
```

Main **HTTPS callables** (all require a signed-in user except where noted):

| Area | Functions |
|------|-----------|
| Study plan | `generateStudyPlan`, `rebalanceStudyPlan` |
| Quizzes (OpenAI) | `generateQuiz`, `generateQuizQuestions` |
| Progress | `submitQuizAttempt`, `generateRecommendations` |
| Email | `sendEmailVerificationOtp`, `verifyEmailWithOtp` |
| Google Calendar | `connectGoogleCalendarWithAuthCode`, `getGoogleCalendarConnectionStatus`, `disconnectGoogleCalendar`, `syncStudySessionToGoogleCalendar` |

The Flutter app calls these over HTTPS; it does not embed `OPENAI_API_KEY` for quiz generation.

#### Secrets and environment (production)

- **Quiz AI:** set the OpenAI key as a Firebase secret:

  ```bash
  firebase functions:secrets:set OPENAI_API_KEY
  ```

- **Email OTP:** set a long random pepper and SMTP for sending codes:

  ```bash
  firebase functions:secrets:set EMAIL_OTP_SECRET
  ```

  Configure SMTP on the deployed function environment (for example `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM`). See comments in `firebase/functions/src/emailVerificationOtp.ts` for details.

For local emulators:

```bash
export OPENAI_API_KEY=your_openai_key
# Optional: export EMAIL_OTP_SECRET=... and SMTP_* if you want real email locally
firebase emulators:start
```

With the emulator, OTP flows may log the code instead of sending mail when SMTP is not configured.

### 3) Firebase Emulator (optional)

From repo root:

```bash
firebase emulators:start
```

### Firebase config note

- Root `firebase.json` + `.firebaserc` are used by Firebase CLI for emulators/deploy.
- `apps/study_coach/firebase.json` is FlutterFire metadata and is ignored in git.

## Core Architecture

The app follows Clean Architecture with feature-first modules:

- `presentation`: UI + state management
- `domain`: entities + use cases + repository contracts
- `data`: DTOs + repository implementations + remote/local data sources

Firebase and AI providers are abstracted behind repository interfaces for testability and future scalability.

## Tests

```bash
cd apps/study_coach
flutter test
```

## Further Reading

- Deeper architecture notes: `docs/architecture.md`
