# Pillar

<p align="center">
  <img src="apps/study_coach/assets/Pillar%20-%20Home.png" alt="Pillar - Home" width="280" />
</p>

Cross-platform study assistant for university students. The Flutter app (Pillar) helps learners organize courses, follow an AI-assisted study plan, take generated quizzes, track progress, and sync sessions to Google Calendar. The backend is Firebase (Auth, Firestore, Storage, Cloud Functions).

## What the app does

After sign-in and optional email verification, students use five main tabs:

| Tab | Purpose |
|-----|---------|
| **Home** | Today’s study sessions, upcoming academic tasks, progress snapshot, study chat entry, quick actions |
| **Plan** | Study plan calendar, session completion, focus timer, plan generation/rebalance |
| **Quiz** | AI quiz generation from topics and/or uploaded notes (text extraction), quiz runner, PDF report export |
| **Roadmap** | Degree roadmap checklist persisted per major |
| **Profile** | Account, courses, academic tasks, quiz history, notifications, language (EN/AR),  Google Calendar sync |

Other notable capabilities:

- **Courses & topics** — courses, exam dates, topics
- **Academic tasks** — homework, exams, projects, etc., with local notification reminders
- **Study chat** — scope-limited OpenAI assistant (requires client `OPENAI_API_KEY`; see below)
- **Recommendations** — rule-based insights from quiz history (Cloud Function, no LLM)
- **Bilingual UI** — English and Arabic (`AppStrings`), including RTL quiz PDF export
- **Calendar context** — scheduling and “today” use `Asia/Bahrain` (Manama), aligned with Cloud Functions

Sign-in is restricted to **Gmail** addresses (`@gmail.com`) in the current build.

## Tech stack

| Layer | Technology |
|-------|------------|
| Client | Flutter 3.x (iOS, Android, Web), Riverpod |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions (Node, Gen 2) |
| AI (quizzes) | OpenAI via authenticated HTTPS callables only |
| AI (study chat) | OpenAI from the app via `--dart-define=OPENAI_API_KEY=...` |
| Integrations | Google Calendar (OAuth PKCE from the client; tokens and API calls on Functions) |

## Repository layout

```
Pillar/
├── apps/study_coach/     # Flutter app (pillar_study_coach)
├── firebase/
│   ├── functions/        # Cloud Functions (TypeScript)
│   ├── firestore.rules
│   └── storage.rules
├── scripts/              # e.g. run-ios-simulator.sh
├── docs/
│   └── architecture.md   # Data model, features, callables
├── firebase.json         # CLI: emulators, deploy, hosting (web)
└── .firebaserc
```

App-specific run notes (Google OAuth): `apps/study_coach/README.md`.

## Quick start

### Flutter app

```bash
cd apps/study_coach
flutter pub get
flutter run
```

iPhone Simulator from repo root:

```bash
./scripts/run-ios-simulator.sh
# Optional device name:
./scripts/run-ios-simulator.sh "iPhone 16"
```

**Google Calendar** (optional): configure `env.dev.json` and run with defines — see `apps/study_coach/README.md`.

**Study chat** (optional): pass an OpenAI key at build/run time (not used for quizzes):

```bash
flutter run --dart-define=OPENAI_API_KEY=your_key
# Or combine with env.dev.json:
flutter run --dart-define-from-file=env.dev.json --dart-define=OPENAI_API_KEY=your_key
```

### Cloud Functions

```bash
cd firebase/functions
npm install
npm run build
```

Authenticated **HTTPS callables** (Flutter uses `cloud_functions`):

| Area | Functions |
|------|-----------|
| Study plan | `generateStudyPlan`, `rebalanceStudyPlan` |
| Quizzes (OpenAI) | `generateQuiz`, `generateQuizQuestions` |
| Progress | `submitQuizAttempt`, `generateRecommendations` |
| Email | `sendEmailVerificationOtp`, `verifyEmailWithOtp` |
| Google Calendar | `connectGoogleCalendarWithAuthCode`, `getGoogleCalendarConnectionStatus`, `disconnectGoogleCalendar`, `syncStudySessionToGoogleCalendar` |

Quiz flows in the app call `generateQuizQuestions` (and related paths) so the **OpenAI key never ships in the client** for quizzes.

### Secrets and environment (production)

**Quiz AI:**

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

**Email OTP:**

```bash
firebase functions:secrets:set EMAIL_OTP_SECRET
```

`EMAIL_OTP_SECRET` hashes OTPs in Firestore; it is not your SMTP password. Mail uses `SMTP_USER` / `SMTP_PASS` on the Cloud Run service for `sendEmailVerificationOtp`.

Gen 2 functions run on **Cloud Run**. Set SMTP variables on the **`sendemailverificationotp`** service in the same GCP project as Firebase (see `.firebaserc` → `default`). Minimum variables: `SMTP_HOST`, optionally `SMTP_PORT` (default `587`), `SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM`. Mount `EMAIL_OTP_SECRET` as a secret on that service.

Detailed SMTP behavior and Gmail app-password steps: `firebase/functions/src/emailVerificationOtp.ts`.

**Local emulators** (from repo root):

```bash
export OPENAI_API_KEY=your_openai_key
# Optional: EMAIL_OTP_SECRET, SMTP_* for real email locally
firebase emulators:start
```

Without SMTP locally, OTP callables may log the code instead of sending mail.

### Web hosting (optional)

Root `firebase.json` hosts `apps/study_coach/build/web` after:

```bash
cd apps/study_coach && flutter build web
firebase deploy --only hosting
```

## Core architecture

Clean Architecture with feature-first modules under `apps/study_coach/lib/features/<feature>/`:

- `presentation` — UI and Riverpod controllers
- `domain` — entities, repository contracts, use cases
- `data` — DTOs, repository implementations, remote services

`core/` holds Firebase wrappers, theme, localization, notifications, OAuth bridges, and shared providers. Firebase and AI are behind repository interfaces where features need testability.

See **`docs/architecture.md`** for Firestore paths, example documents, and function boundaries.

## Tests

```bash
cd apps/study_coach
flutter test
```

Includes widget/smoke tests, study-plan personalization, quiz parsers, study-chat preflight, student reminders, and sign-in email rules.

## Firebase config note

- Root `firebase.json` + `.firebaserc` — CLI emulators and deploy.
- `apps/study_coach/firebase.json` — FlutterFire metadata (gitignored).
