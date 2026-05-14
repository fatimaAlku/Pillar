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

  `EMAIL_OTP_SECRET` is only used to **hash** OTPs in Firestore; it is **not** your SMTP password. Mail credentials are `SMTP_USER` and `SMTP_PASS` (environment variables on Cloud Run).

  Deploy at least once so the functions exist, then attach the secret to the OTP callables if the CLI prompts you to.

  **SMTP in production (required or mail is never sent):** Gen 2 callables run on **Cloud Run**. Plain environment variables such as `SMTP_HOST` are **not** picked up from your laptop; you must set them on the **Cloud Run service** for `sendEmailVerificationOtp` (the verify callable does not send email).

  1. In [Google Cloud Console](https://console.cloud.google.com/) pick the **same project** as Firebase (see `.firebaserc` → `default`).
  2. Open **Cloud Run** → find the service whose name matches the function, usually `sendemailverificationotp` (lowercase). Confirm the **region** in the URL or list (often `us-central1` if you never set a custom region).
  3. Open that service → **Edit & deploy new revision** → **Variables & secrets** → **Add variable** and set at least:
     - `SMTP_HOST` — your provider’s SMTP hostname (required in production).
     - `SMTP_PORT` — optional; default is `587` in code.
     - `SMTP_USER` / `SMTP_PASS` — if the provider requires authentication (prefer [Secret Manager](https://console.cloud.google.com/security/secret-manager) for `SMTP_PASS` and reference it as a secret on the service instead of a plain variable).
     - `EMAIL_FROM` — sender address; for **Microsoft 365** use the **same** address as `SMTP_USER` unless your admin documents otherwise (if unset, the function defaults `From` to `SMTP_USER`).
  4. **Deploy** the revision. No Flutter rebuild is required.

  From a machine with [`gcloud`](https://cloud.google.com/sdk/docs/install) and access to the project, you can list services and regions:

  ```bash
  gcloud run services list --project=YOUR_PROJECT_ID
  ```

  Variable names and behavior are documented in `firebase/functions/src/emailVerificationOtp.ts`.

  **Gmail SMTP (step-by-step, good for testing OTP):**

  1. Open [Google Account security](https://myaccount.google.com/security) for the Gmail address you will use to send mail.
  2. Enable **2-Step Verification** if it is not already on (required for app passwords).
  3. Open [App passwords](https://myaccount.google.com/apppasswords), create one (e.g. app “Mail”, device “Pillar functions”), and copy the **16-character** password (spaces optional); this is **not** your normal Gmail password.
  4. In [Google Cloud Console](https://console.cloud.google.com/) select the same project as Firebase (see `.firebaserc`).
  5. Go to **Cloud Run** → open the service **`sendemailverificationotp`** (region is often `us-central1`).
  6. Click **Edit & deploy new revision** → **Variables & secrets** → add or update:
     - `SMTP_HOST` = `smtp.gmail.com`
     - `SMTP_PORT` = `587`
     - `SMTP_USER` = your full Gmail address (e.g. `you@gmail.com`)
     - `SMTP_PASS` = the app password from step 3 (store as a **secret** reference on Cloud Run if possible, not in chat or screenshots).
     - `EMAIL_FROM` = the **same** Gmail as `SMTP_USER` (or omit it; the function defaults `From` to `SMTP_USER` when `EMAIL_FROM` is empty).
  7. Under **Secrets**, ensure **`EMAIL_OTP_SECRET`** is still mounted for this function (that secret is only for hashing OTPs in Firestore, not for Gmail).
  8. **Deploy** the new revision.
  9. In the app, open **Verify your email** and tap **Resend code**; check the **student inbox** and **Spam** for the message.

  Gmail has daily send limits; for production traffic use a transactional provider (SendGrid, SES, etc.) and a verified domain.

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
