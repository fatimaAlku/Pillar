# Pillar — project reflection (four weeks)

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

## Week 3 — Firestore slice, security rules, and first callable flows

### 1. Reflection on work

> **Main task:** Critically describe the work done related to the product.

**What we did**

- **User-scoped data path:** Wired subjects to **live Firestore** via `SubjectsRepositoryImpl` (`users/{uid}/subjects` snapshots) and `subjectsStreamProvider` / `subjectsControllerProvider`, replacing “pure placeholder” risk on Home with a real subscription when the user is signed in.
- **Security baseline:** Added **Firestore security rules** in `firebase/firestore.rules` so paths under `users/{userId}/**` allow read/write only when `request.auth.uid == userId`, matching the architecture goal of least-privilege access to student data.
- **Callable study-plan generation:** Implemented **`generateStudyPlan`** in `firebase/functions/src/index.ts` (auth check, `subjectIds` validation, writes an `active` plan document under `users/{uid}/studyPlans/{planId}`) and connected the Flutter **`StudyPlanRepositoryImpl`** to call that HTTPS callable via `cloud_functions`.
- **Operational clarity:** Extended root **`README.md`** with Functions setup (build, **`OPENAI_API_KEY`** secret for later AI routes), emulator notes, and the **deterministic fallback** behaviour when quiz AI is misconfigured—so demos and local dev do not depend on a paid key being present on day one.

**Why this way**

- **Stream-first subjects** keeps the dashboard reactive without manual refresh logic and stays aligned with Clean Architecture (repository + providers).
- **Rules at the subtree** under `users/{userId}` is simple to reason about for an MVP while still enforcing ownership.
- **Study plan as a callable** keeps plan writes and any future AI logic **server-side**, consistent with Week 1–2 LESPI decisions.

**Resources**

- [Cloud Firestore (Flutter)](https://firebase.google.com/docs/firestore/quickstart#flutter), [Firestore security rules](https://firebase.google.com/docs/firestore/security/get-started), [Callable Cloud Functions](https://firebase.google.com/docs/functions/callable), `docs/architecture.md`, `firebase/firestore.rules`.

**Alternatives**

- **Custom claims + role-based rules** if we later add tutors or shared cohorts; not needed until multi-user data appears.

**Success criteria (self-check)**

1. **Work described** — Subjects Firestore watch, rules file, `generateStudyPlan` + client repository, README/ops notes.
2. **Reasoning** — Reactive data, ownership rules, server-side plan creation.
3. **References** — Official Firebase/Firestore/Functions docs + internal architecture/rules paths.

---

### 2. Reflection on challenges

> **Main task:** Critically reflect on challenges faced.

**Challenges**

- **Rules vs. product growth:** A single `users/{userId}/{document=**}` match is easy to ship but will need refinement when we add **public templates**, **admin tools**, or **cross-user** features.
- **Callable contracts:** Keeping **request field names** and optional parameters aligned between TypeScript (`generateStudyPlan`) and Dart (`StudyPlanRepositoryImpl`) required discipline; drift causes runtime failures that only show up on device.
- **Emulator vs. cloud:** Deciding whether demos use **emulators** or a **shared dev project** still affects how confidently we can show “real” AI in Week 4 without burning quota.

**Plans**

- Add a short **API contract note** (fields, errors) in `docs/architecture.md` or next to the function for each callable.
- Run **rules unit tests** or emulator-driven checks when new collections appear (e.g. quizzes, attempts).

**Resources**

- Firebase emulator suite; internal `firebase/functions` and `apps/study_coach` call sites.

**Alternatives**

- **BFF-only writes** (no direct client writes to plan documents) with stricter rules; more Functions code, tighter security story.

**Success criteria (self-check)**

1. **Difficult areas** — Rule evolution, cross-language contracts, demo environment.
2. **Alternatives** — Stricter write model via Functions only.
3. **Resources** — Emulator + docs + repo paths.

---

### 3. Reflection on employability skills

> **Main task:** Reflect on one soft skill.

**Skill:** *Stakeholder-ready communication* (what is “done” vs. what is “wired”).

**Situation:** After auth and shell work, it was tempting to say “Firebase is integrated” when some tabs were still placeholders; Week 3 forced clearer language: **subjects and rules are live**, **study plan write path exists**, but full **plan UX** and **quiz AI** were still upcoming.

**Differently next time**

- Maintain a **one-page demo script** alongside the README so supervisors see the exact click path (login → subjects → generate plan) without guessing.

**Future**

- Short **release notes** per week in the repo or a changelog for coursework evidence.

**Success criteria (self-check)**

1. **Skill** — Clear external communication of progress.
2. **Situation** — Balancing integrated backend with partial UI.
3. **Alternatives / future** — Demo script + lightweight changelog.

---

### 4. Reflection on LESPI

> **Main task:** Reflect on LESPI affecting the work.

**Issue**

- **Data integrity and access control:** Once clients can read/write under `users/{uid}`, incorrect rules or client bugs could **delete or overwrite** study data; study plans also encode **academic effort** and deadlines.

**Relation to project**

- Firestore is the system of record for subjects and plans; mistakes affect trust and potentially **assessment-related** records if we store grades or sensitive notes later.

**Mitigation**

- Shipped **uid-scoped rules**; plan generation goes through **authenticated callables**; continued review of **what the client is allowed to write directly** vs. what should move entirely to Functions.

**Success criteria (self-check)**

1. **LESPI issue** — Integrity and authorised access to user-owned documents.
2. **Mitigation** — Rules + callable pattern + ongoing split of write responsibilities.

---

### 5. Plan the coming week

> **Main task:** Describe your planned actions for the coming week.

**Prompt questions**

- What do you plan to complete?
- What resources (tutorials, references, technologies) do you plan to use to complete your work?
- What would you need from your supervisor / supervision?

**Required planning detail**

Planning should show **well-thought-through** next steps: (1) **technical** and **managerial** tasks, separately; (2) a **realistic estimated duration** per task; (3) **links** to resources you will use.

**Planned tasks (end of Week 3 → Week 4 focus)**

| Type | Task | Est. duration | Resources |
|------|------|---------------|-----------|
| Technical | Implement **`generateQuizQuestions`** path end-to-end: OpenAI (or provider) in Functions with **secret** config, **schema validation**, and **fallback** questions if the provider fails | 10–14 h | [Secrets in Functions](https://firebase.google.com/docs/functions/config-env#secret-manager), OpenAI/LLM API docs, existing `firebase/functions/src/index.ts` |
| Technical | Flutter **`QuizAiService`** calling the callable, parsing structured JSON into **`QuizQuestion`**, surfacing **user-visible errors** on the Quizzes tab | 6–8 h | [cloud_functions](https://firebase.google.com/docs/functions/callable#flutter), `quiz_ai_service.dart`, `quizzes_tab_screen.dart` |
| Technical | **`generateQuiz`** persistence path (optional): ensure quiz metadata under `users/{uid}/quizzes` matches what the runner expects | 3–5 h | Firestore data model in `docs/architecture.md` |
| Technical | **Widget / integration tests** for quiz generation happy path and parse failures (mocked callable) | 3–4 h | [Flutter testing](https://docs.flutter.dev/testing) |
| Managerial | **Supervisor demo**: login → subjects visible → generate plan → generate quiz (with and without API key to show fallback) | 1–2 h | — |
| Managerial | **Quota / cost note** in README or internal doc: expected tokens per quiz, how to disable AI in dev | 1 h | Provider billing docs |

**What we need from supervision**

- Approval to use a **shared API key budget** for demos, or confirmation to rely on **fallback-only** demos without live LLM calls.
- Any **institutional policy** on storing **pasted notes** in Firestore vs. ephemeral processing only.

**Screenshots / plan artefacts**

You may add screenshots of your **project plan** or **progress plan** if required or agreed with your supervisor.

- *[Placeholder: insert plan / Gantt / board screenshot here if needed.]*

---

## Week 4 — AI quiz generation, client–function contract, and UX polish

### 1. Reflection on work

> **Main task:** Critically describe the work done related to the product.

**What we did**

- **Server-side quiz AI:** Extended Cloud Functions with **`generateQuizQuestions`** (authenticated, **secret-backed** `OPENAI_API_KEY`, timeout budget) plus **`generateQuiz`** writing user quiz documents and returning a normalised question payload; added **deterministic fallback** generation when keys or provider responses are invalid so the product stays usable in coursework and CI-like environments.
- **Client integration:** Implemented **`FirebaseFunctionsQuizAiService`** in `quiz_ai_service.dart` to call **`generateQuizQuestions`**, validate inputs (topics and/or notes, difficulty, count), and parse either **Map** or **JSON string** responses into **`QuizQuestion`** entities with clear **`QuizAiValidationException` / `QuizAiParseException`** semantics.
- **Quizzes UX:** Reworked **`QuizzesTabScreen`** with a clearer **generate** flow (topics, optional notes, difficulty, question count), loading state tied to **`quizRunnerControllerProvider`**, and copy that explains the value proposition; navigation into **`QuizRunnerScreen`** for attempting generated items.
- **Documentation alignment:** README now documents **secret setup** and fallback behaviour so deployers know why quizzes still work without configuring the provider.

**Why this way**

- **Secrets only in Functions** preserves the security model from earlier weeks while still exposing rich AI output to Flutter.
- **Strict parsing** on the client avoids silently showing malformed MCQs, which would be an ethical and UX failure for a study product.
- **Gradient card + structured form** on the Quizzes tab matches Material 3 patterns used on the dashboard and keeps the feature demoable in a single scroll.

**Resources**

- [Firebase Functions secrets](https://firebase.google.com/docs/functions/config-env#secret-manager), [Callable functions from Flutter](https://firebase.google.com/docs/functions/callable#flutter), provider LLM structured-output guidance, internal `quiz_ai_service.dart` and `index.ts`.

**Alternatives**

- **Server-only rendering** of quiz HTML for web—rejected for now because the native app needs structured models for offline review and analytics later.

**Success criteria (self-check)**

1. **Work described** — `generateQuizQuestions` + client service + quizzes UI + README alignment.
2. **Reasoning** — Secrets off-device, parse safety, consistent presentation layer.
3. **References** — Firebase + Flutter callable docs + repo files.

---

### 2. Reflection on challenges

> **Main task:** Critically reflect on challenges faced.

**Challenges**

- **Non-deterministic LLM output:** Even with prompts and schema hints, models can return **wrong counts**, **duplicate options**, or **JSON that almost parses**—forcing defensive parsing and explicit error strings for the user.
- **Latency and timeouts:** Quiz generation can exceed comfortable mobile wait times; balancing **`timeoutSeconds`** on the function with user expectations required testing on real devices.
- **Dual code paths:** Maintaining **AI-generated** and **fallback** question builders in Functions without diverging field shapes (`question`, `options`, `correctIndex`, etc.) adds review overhead.

**Plans**

- Centralise a **single normaliser** in Functions that both AI and fallback feed, so the Flutter parser sees one schema.
- Add **retry with lower count** on transient provider errors if product owners agree.

**Resources**

- Provider API error catalog; Flutter `Future` timeout patterns; logs in Firebase console.

**Alternatives**

- **Queue + push notification** for long generations; better for 50+ questions, heavier infrastructure for this coursework phase.

**Success criteria (self-check)**

1. **Difficult areas** — LLM variability, timeouts, dual paths.
2. **Alternatives** — Async job queue for long runs.
3. **Resources** — Provider docs + Firebase logs + Flutter async patterns.

---

### 3. Reflection on employability skills

> **Main task:** Reflect on one soft skill.

**Skill:** *Quality focus under uncertainty* (AI features are never “finished,” only “safe enough to ship”).

**Situation:** Quiz generation could ship as a thin demo, but we invested in **validation**, **typed errors**, and **fallback content** so a marker or classmate does not hit a blank screen when the API misbehaves.

**Differently next time**

- Earlier **golden-file fixtures** of provider JSON in tests to catch parser regressions before merging.

**Future**

- **Telemetry** (anonymised): success rate, latency, parse failures—to prioritise prompt engineering vs. client bugs.

**Success criteria (self-check)**

1. **Skill** — Quality and resilience mindset.
2. **Situation** — AI + fallback quiz pipeline.
3. **Alternatives / future** — Fixture tests + telemetry.

---

### 4. Reflection on LESPI

> **Main task:** Reflect on LESPI affecting the work.

**Issues**

- **Accuracy / academic fairness:** AI questions may be **wrong or misleading**; presenting them as authoritative could harm learning or exam preparation (**ethical** duty to label AI-assisted content and encourage verification).
- **Cost and abuse:** Callable endpoints tied to billing and API keys create **financial** and **operational** risk if rates are not guarded (**professional** controls: auth-only, quotas, monitoring).
- **Notes privacy:** Pasting lecture notes into the app sends **personal/academic text** to a third-party model unless we add redaction or on-device-only modes—**legal/privacy** implications depending on jurisdiction and university policy.

**Describe how this relates to your project?**

In this project, LESPI is not abstract; it is embedded in how the AI-powered quiz feature is designed and deployed. Legally and ethically, generated questions can be inaccurate or misleading, so presenting them without clear framing could unfairly affect students' revision and confidence; this is why quiz output should be positioned as assistive rather than authoritative. Socially and professionally, student notes may include personal or sensitive academic material, and sending that text to third-party AI providers creates clear privacy and compliance responsibilities around disclosure, minimisation, and retention. Economically and operationally, the callable model pipeline introduces direct cost and abuse risk, so safeguards such as authentication, rate limits/App Check, monitoring, and secure secret handling are core engineering requirements. Overall, LESPI considerations shape both user experience decisions and backend controls in this project, not just the write-up.


**Mitigation**

- In-app copy that quizzes are **assistive**, not a sole source of truth; README guidance on **secrets** and environment separation; next steps could include **rate limits**, **content warnings**, and **data minimisation** (e.g. truncate or hash notes server-side per policy).

**Success criteria (self-check)**

1. **LESPI issues** — Accuracy, cost/abuse, notes and third-party processing.
2. **Mitigation** — UX honesty, secret handling, documented next controls.

---

### 5. Plan the coming week

> **Main task:** Describe your planned actions for the coming week.

**Prompt questions**

- What do you plan to complete?
- What resources (tutorials, references, technologies) do you plan to use to complete your work?
- What would you need from your supervisor / supervision?

**Required planning detail**

Planning should show **well-thought-through** next steps: (1) **technical** and **managerial** tasks, separately; (2) a **realistic estimated duration** per task; (3) **links** to resources you will use.

**Planned tasks (end of Week 4 → Week 5 focus)**

| Type | Task | Est. duration | Resources |
|------|------|---------------|-----------|
| Technical | **Persist quiz attempts** and weak-topic signals to Firestore (`attempts`, `insights` paths per architecture) and surface a simple **history** list on Progress | 8–12 h | `docs/architecture.md`, Firestore Flutter docs |
| Technical | Flesh out **`rebalanceStudyPlan`** (or client-triggered replan) using performance data, not only `subjectIds` | 6–10 h | Existing callable stub/wiring in `study_plan_repository_impl.dart`, Functions codebase |
| Technical | **Rate limiting / App Check** (or basic callable guards) for `generateQuizQuestions` to reduce abuse risk | 3–5 h | [App Check](https://firebase.google.com/docs/app-check), Functions callable options |
| Technical | **Accessibility pass** on Quizzes tab (labels, contrast, large text) | 2–3 h | [Flutter accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility) |
| Managerial | **User-facing privacy notice** draft: notes, AI providers, retention—aligned with supervision / ethics | 2–3 h | University ethics templates if available |
| Managerial | **End-of-sprint retrospective**: what blocked quiz work, what to automate (CI for Functions build) | 1 h | — |

**What we need from supervision**

- Sign-off on **wording** for AI-assisted study features and any **ethics checklist** required for the module.
- Decision on **minimum viable Progress tab** for the next assessment checkpoint (attempts only vs. charts).

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
