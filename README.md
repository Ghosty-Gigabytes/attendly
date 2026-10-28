# Attendly: Android and web

## GitHub setup
The web branch is `codex/web-app`; `codex/android-app` preserves the Android app. The GitHub Actions workflow checks the web client and packages the backend with the compiled frontend using Java 17 and Flutter 3.47.6. Tests use isolated databases and do not require student credentials or live IMS access.

Create an empty GitHub repository, then run these commands from the project root, replacing `YOUR_USER/YOUR_REPOSITORY`:

```powershell
git remote add origin https://github.com/YOUR_USER/YOUR_REPOSITORY.git
git push -u origin codex/web-app
git push origin codex/android-app
```

If `origin` already exists, inspect it with `git remote -v` before changing it. Select `codex/web-app` as the default branch in GitHub if the website is the primary project. Local SDKs, compiled bundles, databases, encryption keys, signing keys, and previews are excluded from Git. Configure deployment secrets outside source control. No open-source license is granted by this repository yet; choose one before inviting public reuse.

## Branches
- `codex/android-app`: preserved native Android app, including the guided What-if redesign (`2ebd5cc`).
- `codex/web-app`: web client and Spring Boot backend development. Android sources under `outputs/attendance_app` remain unchanged from the preserved branch.

## Current structure
Desktop navigation keeps account details and a logout button in the sidebar footer, with a persistent refresh toolbar. Alt+1 through Alt+5 switch sections. Wide screens show up to three subject columns; subject calendars open in a dismissible dialog. Unsynced personal edits block logout and offer a sync action.

- `apps/web`: Flutter web/PWA client; Material design and the existing attendance, calendar, timetable and What-if interactions.
- `packages/attendly_core`: extracted platform-independent models, counting rules, timetable parsing and projections. The preserved Android app still uses its own snapshot; migration to this shared package is a separate Android change.
- `server`: Java 17, Spring Boot 4.1.2, Spring Security, JDBC, Flyway, PostgreSQL. Local-only H2 profile permits development without installing PostgreSQL. JDBC was chosen for explicit owner/scope/revision queries; JPA is not required for this initial implementation.
- `scripts`: build and local-preview commands.

## Local preview
Prerequisites: Java 17+, Flutter and the Maven wrapper (first use requires internet).

```powershell
./scripts/build-web.ps1
./scripts/start-server.ps1
```

Open http://localhost:8080. Sign in with your IMS student ID and password; Attendly creates an account only after the IMS report verifies that identity. No sample attendance is inserted. The local profile stores its database under `server/.local`, which is ignored by Git. The backend serves the web bundle and `/api` from the same origin. For Flutter hot reload, run the backend with `WEB_ORIGIN=http://localhost:5173` and run Flutter from `apps/web` with `--web-port 5173 --dart-define=API_BASE=http://localhost:8080/api`.

## IMS-first authentication
The main login uses IMS credentials, not a separate Attendly email/password. The verified student ID is unique; an internal UUID owns records. Previously linked snapshots resolve to the existing owner only after successful IMS verification. Migrating an account disables its old email-password credential. Email sign-up/login, Google OAuth, and the duplicate IMS connection flow have been removed. Existing account IDs and attendance/personal records are preserved by migration V3; obsolete authentication columns are removed.

The server stores an Argon2id verifier (19 MiB, 2 passes, parallelism 1). If background refresh is enabled on the login screen, it also stores an AES-256-GCM encrypted password with a random nonce and owner ID as authenticated data. No password is logged or placed in browser storage. Production requires `IMS_CREDENTIAL_KEY`, a base64-encoded random 32-byte key supplied separately from the database. The local profile generates an ignored `server/.local/ims-credential.key`; keep it private and back it up separately. Losing or changing that key requires users to sign in again to re-save credentials; staged key rotation/KMS integration is pending.

An existing user can sign in during a connection timeout/refusal or IMS HTTP 502/503/504 using the last verified password, only within 7 days of successful IMS credential verification. Explicit credential/CAPTCHA rejection, malformed pages, TLS errors and parser errors never activate fallback. Fallback sessions allow saved-record GETs only, expire after 15 minutes of inactivity, and cannot edit records, refresh IMS or change saved credentials. First-time accounts require IMS. Existing device caches remain accessible offline.

The refresh worker checks every 15 minutes for stale snapshots of users who opted in. It reuses valid IMS sessions, then signs in with encrypted credentials and local OCR when necessary. Failed refreshes preserve the last snapshot; an explicit login rejection removes the encrypted password to stop repeated submissions. Settings can remove that encrypted password without deleting attendance or the fallback verifier. API login throttling is per student and source IP for this single-server foundation; shared/distributed throttling remains a deployment task.

## IMS connection
CAPTCHA answers are filled using bundled Tesseract native libraries and the same `mydigits.traineddata` model as Android. Recognition runs locally on the server with sparse-text segmentation (PSM 11); no external OCR service or separate Tesseract installation is needed on supported platforms. The number remains editable; recognition failure or a busy OCR worker leaves manual entry available. Refreshing the image clears the previous answer. CAPTCHA images and answers are not logged or stored in the database. See the [Tesseract documentation](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage) for recognition options. Run the optional public-challenge smoke test by setting `IMS_LIVE_SMOKE=true` before backend tests; it fetches a public image without signing into a student account.

The IMS adapter follows the Android/Python flow, including the legacy `fy` compatibility field; current report year/semester come from IMS. Redirects are restricted to IMS HTTPS hosts and cookies are isolated per user. Live public CAPTCHA fetch and OCR have been verified; real student sign-in and deployed PostgreSQL still require end-to-end verification. The web ID-card viewer fetches Personal Info > ID Card Details, verifies the student ID, and loads IMS photo/signature/logo images. Server snapshots are encrypted and responses use Cache-Control: no-store. The browser keeps an account-scoped copy for offline use and clears it on logout. Mobile navigation opens a fullscreen front/back viewer with portrait/landscape card rotation and drag tilt; it does not change phone orientation or request motion-sensor access. The card uses Department, student Ph.No., IMS address, B.Tech. 4-year / M.Tech. 2-year batches, and no barcode or registrar signature. Live ID-card retrieval still needs a real-account check.

## Offline and sync
The web client stores account-scoped snapshots and pending edits in IndexedDB through Sembast Web. Official records remain separate from personal records, timetable rules and plans. The app shell has a custom service worker; API/auth routes are never cached by it. The web renderer is bundled locally for offline use. First use must be online. The packaged build pre-caches its app/renderer assets before the offline shell activates. Browser storage may be evicted or manually cleared; server-synced records can be downloaded again, while unsynced changes cannot be recovered after local deletion.

Mutations have UUIDs and base revisions; the server deduplicates retries and retains deletion tombstones. Conflicts keep the local version pending and require a choice. The initial conflict dialog shows the preserved record payloads; a friendlier field-level comparison is pending. Sync runs on opening/retrying or after edits; closed-browser background sync is not promised. Signing out is blocked when unsynced edits exist, then clears this browser's local database. Cross-semester pending-edit migration is not complete; resolve pending edits before switching semesters. Android-to-Attendly-account migration is not implemented yet.

## Configuration and production work
Default server configuration expects `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `WEB_ORIGIN` and HTTPS (`COOKIE_SECURE=true`). `compose.yaml` supplies an optional local PostgreSQL instance; its password must be set in the environment. The database migration uses PostgreSQL-compatible SQL. Integration tests currently run on H2 in PostgreSQL mode; real PostgreSQL deployment verification remains required.

This is a local-development foundation, not a public launch. Pending: distributed rate limits/abuse protection, account export/deletion, persistent session storage across server instances, managed key rotation, push notifications, production backups/monitoring and Safari/offline lifecycle checks. No secrets or real student records are committed. A live IMS account is needed for the remaining external end-to-end checks.

## Validation
Run backend checks with `server/mvnw.cmd -f server/pom.xml test` (or `mvn -f server/pom.xml test`), and Flutter checks from `apps/web` with `flutter test` and `flutter analyze`. Build the web bundle before packaging the backend JAR so it includes the UI. Do not commit `server/src/main/resources/static`, `server/target`, credentials or local databases.


## Initial web milestone validation
Backend integration/parser/OCR tests and eleven Flutter web controller/layout tests pass, including encrypted credential storage, stable IMS account creation, outage-only fallback and read-only enforcement. Flutter analysis is clean and the release web build and executable Spring Boot JAR succeed. The combined app was served at localhost:8080 and its desktop login page inspected in the in-app browser. Mobile and desktop login layouts were also rendered in widget tests. Live IMS student authentication, PostgreSQL deployment and real iPhone lifecycle behavior remain unverified.
