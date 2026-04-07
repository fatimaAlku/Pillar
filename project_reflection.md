# Pillar — project reflection (two weeks)

Reflection structured by week. Each week follows the coursework template: **work**, **challenges**, **employability skills**, **LESPI** (Legal, Ethical, Social, Professional issues), and **plan the coming week**. Where used below, **prompt questions** and **success criteria** appear before our answers.

**Template key (sidebar colours)**

| Part | Theme |
|------|--------|
| 1 | Reflection on work |
| 2 | Reflection on challenges |
| 3 | Reflection on employability skills |
| 4 | Reflection on LESPI |
| 5 | Plan the coming week |

---

## Week 1 — Foundation, architecture, and backend shape

### 1. Reflection on work

> **Main task:** Critically describe the work you have done related to your product.

**Prompt questions**

- What did you do in relevance to your product?
- Why did you do it this way? Possible ways of implementing your product.
- What resources (tutorials, references, technologies) do you plan to use or did you use to complete your work?
- What would you do alternatively?

**Success criteria**

- Critical reflection includes (1) description of work done, (2) reasoning for what worked well, and (3) links to references and/or theories.
- Shows genuine efforts towards developing the final product.

**Our reflection**

**What we did in relation to the product**

- Defined **Pillar** as a cross-platform study assistant (Flutter + Firebase): subjects, study plans, AI quizzes, progress, and adaptive planning (as captured in the root `README.md`).
- Documented **architecture** in `docs/architecture.md`: Clean Architecture, feature-first layout, Riverpod, Firebase (Auth, Firestore, Storage, Cloud Functions), and planned callable boundaries for AI and plan logic.
- Established the **repository layout**: `apps/study_coach` (Flutter), `firebase` (config, rules, functions), and `docs`.
- Implemented **feature modules** with presentation / domain / data layers for subjects, study plan, quizzes, progress, and recommendations, plus shared `core` services (e.g. Firebase wrappers, Firestore paths, AI service abstraction).
- **Connected Firebase** to the project (CLI / project wiring per commit history) and sketched an initial **Firestore data model** (users, subjects, topics, study plans, sessions, quizzes, attempts, insights).

**Why we did it this way**

- Clean Architecture and repository interfaces keep the UI independent of Firebase and future AI providers, which matches the product goal of secure, evolvable backends (keys only in Functions, as noted in architecture docs).
- Feature-first folders scale as we add screens and use cases without turning `lib/` into a flat list of unrelated files.

**Resources used or planned**

- [Flutter documentation](https://docs.flutter.dev/)
- [Firebase documentation](https://firebase.google.com/docs) (Auth, Firestore, Functions)
- [Riverpod](https://riverpod.dev/) for state and dependency injection
- Internal reference: `docs/architecture.md` and root `README.md`

**What we might do alternatively**

- Start with a smaller vertical slice (one feature end-to-end) before scaffolding all modules—faster user-visible progress, slightly more rework if boundaries shift.

**Success criteria (self-check)**

1. **Description of work** — Yes: repo structure, docs, layered features, Firebase orientation.
2. **Reasoning for what worked well** — Yes: separation of concerns and documented boundaries support later AI and security rules.
3. **Links to references/theories** — Yes: Clean Architecture / layered design aligns with common software architecture practice; cited official docs above.

---

### 2. Reflection on challenges

> **Main task:** Critically reflect on challenges faced.

**What was most challenging**

- **Scope vs. depth:** Scaffolding many features at once without yet wiring every flow end-to-end can make it harder to demo “one complete path” early.
- **Firebase + local dev:** Emulator setup, config files, and keeping FlutterFire metadata straight (e.g. multiple `firebase.json` contexts noted in README) add operational overhead.
- **Designing the data model early** without all UI flows fixed risks small schema churn later.

**How we plan to handle those challenges**

- Prioritize the **first end-to-end feature** (e.g. subjects + first study-plan touchpoint) as in README “Next Steps.”
- Use **Firebase emulators** locally and document the happy path in README.
- Treat Firestore fields as **versioned** where needed and keep rules aligned with `docs/architecture.md`.

**Resources**

- Firebase emulator docs; FlutterFire setup guides; architecture doc as single source of truth for collections.

**Alternatives**

- Prototype only in Firestore console + one screen first, then formalize schema; trade-off is more throwaway work.

**Success criteria (self-check)**

1. **Difficult tasks described** — Yes: scope, tooling, schema timing.
2. **Alternatives** — Yes: vertical slice first; prototype-first schema.
3. **References** — Yes: Firebase/FlutterFire/emulator resources.

---

### 3. Reflection on employability skills

> **Main task:** Reflect on one soft skill that affected the work.

**Skill, situation, and reflection**

- **Skill:** *Communication through writing and shared structure* (documentation and conventions).
- **Situation:** Multiple layers (app, firebase, docs) needed the same mental model of features and data; without clear docs, contributors would duplicate or contradict patterns.
- **What worked:** Central `README.md` and `docs/architecture.md` gave a shared vocabulary (feature folders, repository contracts, LESPI-adjacent security notes).

**How we would handle it differently**

- Add a short **contributing** section earlier: how to run the app, where to put a new feature, and a checklist for Firestore path changes.

**Future**

- Lightweight **ADRs** (architecture decision records) for big choices (e.g. Riverpod vs. other state libraries) so reasoning survives onboarding.

**Success criteria (self-check)**

1. **One employability skill** — Written communication / documentation discipline.
2. **Situation** — Aligning repo layout and backend boundaries.
3. **Alternatives / future** — Contributing guide, ADRs.

---

### 4. Reflection on LESPI

> **Main task:** Reflect on Legal, Ethical, Social, and Professional issues.

**Issue identified**

- **Professional / security:** API keys and LLM credentials must not ship in the Flutter client; AI calls should run in **Cloud Functions** with secrets in environment/config (stated in `docs/architecture.md`).

**How it relates to the project**

- The product relies on **AI-generated quizzes and plans**; mishandling keys would be a legal/professional incident and could expose user data or incur cost abuse.

**Mitigation (done or intended)**

- Architecture explicitly keeps keys **only in Functions**; client uses abstractions (`ai_service`, repositories). Next: implement Functions with locked-down IAM, validate inputs, and apply **Firestore security rules** per user UID.

**Success criteria (self-check)**

1. **One LESPI issue** — Secret management and professional duty of care for user data and infrastructure.
2. **Mitigation** — Backend-for-frontend pattern and planned rules; no keys in client.

---

### 5. Plan the coming week

> **Main task:** Describe your planned actions for the coming week.

**Prompt questions**

- What do you plan to complete?
- What resources (tutorials, references, technologies) do you plan to use to complete your work?
- What would you need from your supervisor / supervision?

**Required planning detail**

Planning should show **well-thought-through** next steps: (1) **technical** and **managerial** tasks, separately; (2) a **realistic estimated duration** per task; (3) **links** to resources you will use.

**Planned tasks (end of Week 1 → Week 2 focus)**

| Type | Task | Est. duration | Resources |
|------|------|---------------|-----------|
| Technical | Wire **Firebase Auth** into the Flutter app (sign-in / sign-up / sign-out) and expose session state via **Riverpod** | 6–8 h | [Firebase Auth (Flutter)](https://firebase.google.com/docs/auth/flutter/start), [Riverpod](https://riverpod.dev/) |
| Technical | Add **app shell**: splash / loading gate, `MaterialApp` theme, route home to **auth vs. signed-in** dashboard | 4–5 h | [Flutter navigation](https://docs.flutter.dev/ui/navigation), app `lib/app/` structure |
| Technical | Build **dashboard skeleton** (e.g. bottom navigation + placeholder tabs for study plan, quizzes, progress) | 4–5 h | [Material 3](https://docs.flutter.dev/ui/design/material) |
| Technical | Add a **repeatable iOS run** path (script or documented commands) so the team can demo on Simulator | 1–2 h | [Flutter — iOS setup](https://docs.flutter.dev/get-started/install/macos) |
| Managerial | Short **README** update: how to run the app and what is implemented vs. placeholder | 1 h | Repo `README.md` |
| Managerial | **Checkpoint** with supervisor: confirm Firebase project / test account strategy for demos | 0.5–1 h | — |

**What we need from supervision**

- Confirmation of **demo expectations** for the next milestone (e.g. “signed-in shell only” vs. first Firestore read).
- Agreement on whether to use **Firebase Emulator** or a **shared dev project** for assessment demos.

**Screenshots / plan artefacts**

You may add screenshots of your **project plan** or **progress plan** if required or agreed with your supervisor.

- *[Placeholder: insert plan / Gantt / board screenshot here if needed.]*

---

## Week 2 — App shell, auth, dashboard, and developer workflow

### 1. Reflection on work

> **Main task:** Critically describe the work done related to the product.

**What we did**

- Built the **app entry and navigation shell** in `apps/study_coach/lib/app/app.dart`: Material 3 theme, app title “Pillar,” and an **auth gate** that shows a splash delay, then either `AuthScreen` or `DashboardScreen` based on `currentAuthUserProvider`.
- Implemented **auth flow support** in `auth_controller.dart`: `AuthFormController` for sign-in, sign-up, and sign-out using `authRepositoryProvider`, with loading/error state suitable for forms (`AuthFormState`, `FeatureState` for high-level status).
- Implemented a **dashboard** with **bottom navigation** across Home, Study Plan, Quizzes, and Progress; Home ties into feature controllers (subjects, study plan, quizzes, progress, recommendations) for early integration; other tabs use placeholders aligned with product copy.
- Added **developer ergonomics**: `scripts/run-ios-simulator.sh` to boot a chosen iOS Simulator and run `flutter run`; documented optional device name in `README.md`.

**Why this way**

- Riverpod **`FutureProvider`** for startup and **`Stream`/async providers** for auth matches reactive UX (splash → signed in or auth form).
- Bottom navigation mirrors the **product pillars** (plan, quiz, progress) so future screens slot in without restructuring root navigation.

**Resources**

- [Flutter Material 3](https://docs.flutter.dev/ui/design/material), [Firebase Auth Flutter](https://firebase.google.com/docs/auth/flutter/start), Riverpod provider patterns.

**Alternatives**

- Use `go_router` with redirect guards for deeper linking later; acceptable trade-off: more setup now for better URLs and web.

**Success criteria (self-check)**

1. **Work described** — Auth gate, auth controller, dashboard skeleton, script + README.
2. **Reasoning** — Reactive auth; nav matches roadmap.
3. **References** — Flutter, Firebase Auth, Riverpod.

---

### 2. Reflection on challenges

> **Main task:** Critically reflect on challenges faced.

**Challenges**

- **Async auth edge cases:** Distinguishing loading, signed-out, and error states so users are not stuck on splash or sent to the wrong screen.
- **Simulator and path assumptions:** The run script uses a fixed workspace path; teammates cloning elsewhere must adjust or parameterize.
- **Placeholder vs. real data:** Dashboard tabs promise features not yet fully implemented—risk of perceived “empty” product until repositories return live Firestore data.

**Plans**

- Harden **error reporting** on auth (user-visible messages already partially supported via `AuthFormState`).
- Generalize scripts with **`REPO_ROOT`** detection or document the edit point.
- Connect **one repository** to Firestore for a minimal list UI to replace placeholder text on one tab.

**Resources**

- Flutter async UI guidelines; Firebase Auth error codes; internal controllers/repositories.

**Alternatives**

- Feature flags per tab until backend ready; or a single “coming soon” consolidated screen (less navigation polish).

**Success criteria (self-check)**

1. **Difficult areas** — Auth async, script portability, placeholder UX.
2. **Alternatives** — Flags vs. consolidated screen.
3. **Resources** — Listed above.

---

### 3. Reflection on employability skills

> **Main task:** Reflect on one soft skill.

**Skill:** *Initiative and tooling mindset* (removing friction for repeated tasks).

**Situation:** Running the app on iOS Simulator required several manual steps each time; we automated boot + `flutter run` in `scripts/run-ios-simulator.sh` and documented it in `README.md`.

**Differently next time**

- Add a **`--device` list** mode to the script and print available simulators when lookup fails (the script already hints at `xcrun simctl list`).

**Future**

- Mirror a small script for **Android** or document `flutter devices` one-liners for parity.

**Success criteria (self-check)**

1. **Skill** — Initiative / developer experience.
2. **Situation** — iOS run automation.
3. **Alternatives / future** — Device listing; Android parity.

---

### 4. Reflection on LESPI

> **Main task:** Reflect on LESPI affecting the work.

**Issue**

- **Privacy / ethical use of accounts:** Email/password auth stores identity in Firebase; we must handle **password practices**, **account recovery**, and clear **data use** expectations as we add notes upload and AI features.

**Relation to project**

- Study apps hold **sensitive academic and possibly personal** content in Firestore/Storage; sign-in is the gateway to that data.

**Mitigation**

- Use **Firebase Auth** built-in security; ensure **Firestore rules** enforce `request.auth.uid` ownership on user paths (per architecture); plan **minimal data collection** and in-app messaging before enabling uploads; never log passwords or tokens in client debug output (review `kDebugMode` usage).

**Success criteria (self-check)**

1. **LESPI issue** — Privacy and responsible handling of student data tied to authentication.
2. **Mitigation** — Auth provider + planned rules + discipline around logging and future privacy copy.

---

### 5. Plan the coming week

> **Main task:** Describe your planned actions for the coming week.

**Prompt questions**

- What do you plan to complete?
- What resources (tutorials, references, technologies) do you plan to use to complete your work?
- What would you need from your supervisor / supervision?

**Required planning detail**

Planning should show **well-thought-through** next steps: (1) **technical** and **managerial** tasks, separately; (2) a **realistic estimated duration** per task; (3) **links** to resources you will use.

**Planned tasks (end of Week 2 → next week)**

| Type | Task | Est. duration | Resources |
|------|------|---------------|-----------|
| Technical | **Subjects (or first domain slice)** end-to-end: Firestore read/write for `users/{uid}/subjects`, list + add subject in UI | 8–10 h | [Cloud Firestore (Flutter)](https://firebase.google.com/docs/firestore/quickstart#flutter), `docs/architecture.md` (paths) |
| Technical | Draft **Firestore security rules** for user-scoped collections and test with emulator | 3–4 h | [Firestore security rules](https://firebase.google.com/docs/firestore/security/get-started), `firebase` rules in repo |
| Technical | **First callable or stub** for study-plan generation (even static JSON) to validate client → Functions wiring | 4–6 h | [Callable functions](https://firebase.google.com/docs/functions/callable), `firebase/functions` |
| Technical | Replace one **dashboard placeholder** with live data (e.g. subject count or list on Home) | 2–3 h | Existing `subjects` feature modules |
| Managerial | Define **MVP demo script** (login → see data → one user action) for supervisor review | 1–2 h | — |
| Managerial | **Risk log** update: schema churn, AI quota, or assessment deadline—note mitigations | 1 h | — |

**What we need from supervision**

- Feedback on **priority order**: subjects + rules first vs. Functions stub first if time is tight.
- Sign-off or wording for **privacy / data use** copy before uploads or third-party AI calls go live.

**Screenshots / plan artefacts**

You may add screenshots of your **project plan** or **progress plan** if required or agreed with your supervisor.

- *[Placeholder: insert plan / Gantt / board screenshot here if needed.]*

---

## References (shared)

| Topic        | Reference |
|-------------|-----------|
| Flutter     | https://docs.flutter.dev/ |
| Firebase    | https://firebase.google.com/docs |
| Riverpod    | https://riverpod.dev/ |
| Architecture | `docs/architecture.md` |
| Product overview | Root `README.md` |
