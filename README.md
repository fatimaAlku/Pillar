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
- AI: External LLM API via Cloud Functions

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

## Next Steps

- Connect Auth flows (email/password + provider sign-in)
- Implement first end-to-end feature: Subjects + Study Plan generation
- Add Cloud Function AI endpoints and secure callable invocation