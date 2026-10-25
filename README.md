# Attendly: Android and web

## Branches
- `codex/android-app`: preserved native Android app, including the guided What-if redesign (`2ebd5cc`).
- `codex/web-app`: web client and Spring Boot backend development. Android sources under `outputs/attendance_app` remain unchanged from the preserved branch.

## Current structure
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

Open http://localhost:8080. Sign up with a local test account; no sample attendance is inserted. The local profile stores its database under `server/.local`, which is ignored by Git. The backend serves the web bundle and `/api` from the same origin. For Flutter hot reload, run the backend with `WEB_ORIGIN=http://localhost:5173` and run Flutter from `apps/web` with `--web-port 5173 --dart-define=API_BASE=http://localhost:8080/api`.

## Google sign-in
1. Create a Google Cloud project and configure its OAuth branding/consent screen. In testing, add your Google account as a test user.
2. Create an OAuth client of type **Web application**. For the same-origin local preview, register exactly `http://localhost:8080/login/oauth2/code/google` as the authorized redirect URI. Add your HTTPS production callback separately after deployment is selected.
3. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in the server environment (not Flutter, source control or a public config file).
4. Run `./scripts/start-server.ps1 -Google`. The server activates `local,google`; the client discovers Google availability through `/api/config` and displays **Continue with Google**.

Spring Security runs the authorization-code/OpenID Connect flow and creates a server session. Google is identified by its `sub` claim and requires a verified email. Only `openid profile email` scopes are requested. An existing password account with the same email is not silently merged; explicit account linking is still pending. Google sign-in authenticates Attendly only; IMS must be connected separately. A real Google round trip cannot be verified without configured OAuth credentials.

## IMS connection
Authenticated users request a CAPTCHA, submit their IMS credentials and receive a server-fetched attendance snapshot. HTTP redirects are restricted to the IMS HTTPS hosts. Cookies are isolated by Attendly user; passwords are not persisted. This adapter follows the existing Android/Python flow, including the legacy portal login `fy` compatibility field; report year/semester come from IMS, not that field. Sessions currently live in server memory for up to 30 minutes, so restarting the server or expiry requires reconnecting IMS. Scheduled refresh and encrypted persistent IMS credentials are not implemented yet. Live student login is not verified in this branch; fixture tests cover report parsing and column identity. ID-card fetching is still Android-only.

## Offline and sync
The web client stores account-scoped snapshots and pending edits in IndexedDB through Sembast Web. Official records remain separate from personal records, timetable rules and plans. The app shell has a custom service worker; API/auth routes are never cached by it. The web renderer is bundled locally for offline use. First use must be online. The packaged build pre-caches its app/renderer assets before the offline shell activates. Browser storage may be evicted or manually cleared; server-synced records can be downloaded again, while unsynced changes cannot be recovered after local deletion.

Mutations have UUIDs and base revisions; the server deduplicates retries and retains deletion tombstones. Conflicts keep the local version pending and require a choice. The initial conflict dialog shows the preserved record payloads; a friendlier field-level comparison is pending. Sync runs on opening/retrying or after edits; closed-browser background sync is not promised. Signing out is blocked when unsynced edits exist, then clears this browser's local database. Cross-semester pending-edit migration is not complete; resolve pending edits before switching semesters. Android-to-Attendly-account migration is not implemented yet.

## Configuration and production work
Default server configuration expects `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `WEB_ORIGIN` and HTTPS (`COOKIE_SECURE=true`). `compose.yaml` supplies an optional local PostgreSQL instance; its password must be set in the environment. The database migration uses PostgreSQL-compatible SQL. Integration tests currently run on H2 in PostgreSQL mode; real PostgreSQL deployment verification remains required.

This is a local-development foundation, not a public launch. Pending: email verification/recovery, explicit provider linking, rate limits/abuse protection, account export/deletion, persistent session storage across server instances, encryption/key management for optional stored IMS credentials, scheduled workers/push, production backups/monitoring and Safari/offline lifecycle checks. No secrets or real student records are committed. Google client credentials and a live IMS account are needed for the remaining external end-to-end checks.

## Validation
Run backend checks with `server/mvnw.cmd -f server/pom.xml test` (or `mvn -f server/pom.xml test`), and Flutter checks from `apps/web` with `flutter test` and `flutter analyze`. Build the web bundle before packaging the backend JAR so it includes the UI. Do not commit `server/src/main/resources/static`, `server/target`, credentials or local databases.


## Initial web milestone validation
Seven Spring integration/parser tests and four Flutter web controller/layout tests pass. Flutter analysis is clean and the release web build and executable Spring Boot JAR succeed. The combined app was served at localhost:8080 and its desktop login page inspected in the in-app browser. Mobile and desktop login layouts were also rendered in widget tests. Live Google login requires OAuth configuration; live IMS student authentication, PostgreSQL deployment and real iPhone lifecycle behavior remain unverified.
