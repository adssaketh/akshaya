# Firebase setup (Spark plan, no billing)

Nothing here needs a Cloud Billing account or the Blaze plan. Do not add one.

## 1. Project and app
1. Firebase console -> your project (Spark plan).
2. Project settings -> Your apps -> Android app, package `com.akshayapatra.app`.
3. Add the **debug SHA-1** (below) to that app.
4. Download `google-services.json` and store its whole text in the GitHub secret `GOOGLE_SERVICES_JSON` (never commit it). Re-download and update the secret after enabling Google sign-in, because the file only then contains the web OAuth client.

## 2. A stable debug SHA-1
GitHub runners would otherwise generate a new debug keystore each build, which breaks Google sign-in. The workflow:
- uses the secret `DEBUG_KEYSTORE_BASE64` (base64 of your `debug.keystore`) if you set it, so your own SHA-1 (`DC:15:20:...:3B`) keeps working, or
- creates a keystore once and caches it (`akshaya-debug-keystore-v1`); the build log prints its SHA-1, register that one.

To use your own: `base64 -w0 ~/.android/debug.keystore` and paste into the secret.

## 3. Authentication
Console -> Authentication -> Sign-in method: enable **Google** and **Email/Password**. No phone auth.

## 4. Firestore
1. Console -> Firestore Database -> Create database (production mode, a free-tier region).
2. Deploy rules and indexes (Firebase CLI, once): `firebase deploy --only firestore:rules,firestore:indexes --project <id>`; or paste `firestore.rules` into the Rules tab and create the seven composite indexes from `firestore.indexes.json` (collection `isDeleted` asc + `updatedAt` asc, for categories, items, shoppingLists, batches, entries, logs, recipes).

## 5. App Check (already used by AI)
Play Integrity for release builds; for debug APKs register the debug token shown in logcat (App Check -> Apps -> Manage debug tokens). Enforce App Check on Firestore only after tokens are registered.

## 6. Rules tests (no project needed)
`cd firebase && npm install && firebase emulators:exec --only firestore --project akshaya-rules-test "npm test"`. CI runs this as the `rules-tests` job.

## Spark quota notes
Free daily limits: 50K reads, 20K writes, 20K deletes, 1 GiB stored. The app keeps well inside by: reading only documents changed since the last sync (server `syncedAt` cursor), one live listener per collection and only while the app is open, a push queue in batches of 20, a daily purge of 30-day-old soft deletes, and a 1 hour pause when the quota error appears. Settings shows today's estimated reads and writes. Roughly: first sync of 500 items costs ~1.5K reads/writes; a normal day with two phones is well under 1K.
