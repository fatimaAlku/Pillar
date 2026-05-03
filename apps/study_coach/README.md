# Pillar Study Coach

Flutter app for the Pillar study coach experience.

## Local run with Google Calendar config

1. Open `env.dev.json` and set:
   - `GOOGLE_CLIENT_ID` — **iOS** OAuth client ID when running on iOS (from Google Cloud → Credentials → your iOS client).
   - `GOOGLE_REDIRECT_URI` — must match Google’s native-app format: `YOUR_IOS_BUNDLE_ID:/oauth2redirect` (default matches this app’s Xcode bundle id `com.example.pillarStudyCoach`). Your **iOS OAuth client** in Google Cloud must use that **same** bundle id.
2. Run the app with Dart defines from file:

```bash
flutter run --dart-define-from-file=env.dev.json
```

For **Android**, use your Android OAuth client id and set `GOOGLE_REDIRECT_URI` to `com.example.pillar_study_coach:/oauth2redirect` (same pattern, using `applicationId` from `android/app/build.gradle.kts`).
