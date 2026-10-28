# Attendly

**Know your attendance. Plan your time.**

Attendly helps NSUT students check their IMS attendance, keep personal class records, and explore leave plans before taking a break. It includes a Flutter Android app and a responsive Flutter web app backed by Spring Boot.

Attendance is calculated **for each subject**, with a minimum of **75%**. There is no combined attendance percentage across subjects.

> An independent student project, not an official NSUT service. IMS remains the source of official attendance. The website is under active development and is not yet ready for a public production launch.

## Features

| Feature | What it does |
| --- | --- |
| IMS sign-in | Uses your existing student ID and password; no separate Attendly registration. |
| Attendance overview | Shows subject names, percentages, class counts, and classes you can miss or need to attend. |
| Personal records | Lets you log present and absent classes while waiting for faculty uploads. |
| Attendance calendar | Shows daily attendance with separate official and personal records. |
| Timetable | Supports pasted timetable imports and a weekly calendar editor. |
| What if? | Projects how leave, extra classes, and cancellations affect each subject. |
| Virtual ID card | Displays front/back views using IMS details and images, with rotation and subtle motion. |
| Offline access | Keeps previously loaded records available on the device. |
| Web sync | Saves personal records and plans to your account and queues offline edits. |
| Material interface | Adapts to mobile and desktop with light/dark appearance. |

The Android app also includes home-screen widgets and device notifications. These are separate from the web app.

### Official and personal attendance

Official records and personal logs stay separate. Turning on personal records shows an additional percentage that includes classes IMS has not recorded yet.

If IMS and your personal log both contain a record for the same subject on the same day, **the IMS record is used**. Classes are never added twice. Differing counts can be flagged for review.

In IMS reports, `1` means present, `0` means absent, and a blank cell means no recorded class. Off-day codes are displayed separately and do not count as held classes. Leave projections depend on your timetable and the assumptions shown in the planner.

## Project structure

```text
apps/web/                 Flutter web client and PWA shell
packages/attendly_core/    Shared Dart models and attendance calculations
server/                   Spring Boot API, IMS adapter, database migrations
scripts/                  Build, offline-shell preparation, server startup
outputs/attendance_app/   Existing Flutter Android app
docs/                     Technical notes
compose.yaml              Optional local PostgreSQL service
```

| Branch | Purpose |
| --- | --- |
| `codex/web-app` | Web app, shared Dart package, and backend. |
| `codex/android-app` | Preserved Android app. |

The Android app currently uses its own domain implementation. It has not been migrated to the shared package or web account system.

## Tech stack

- **Frontend:** Flutter, Dart, Material 3, Dio, Sembast/IndexedDB.
- **Backend:** Java 17, Spring Boot 4.1.2, Spring Security, JDBC, Jsoup.
- **Database:** PostgreSQL with Flyway migrations; H2 for local development and tests.
- **Authentication:** IMS verification, server sessions, Argon2id verification, and optional encrypted credentials for background refresh.
- **OCR:** Bundled Tesseract and a custom digit model, with manual CAPTCHA entry available.

## Run locally

### Prerequisites

- Flutter **3.47.6**, including its Dart SDK.
- JDK **17** with `JAVA_HOME` configured.
- PowerShell for the helper scripts.
- Internet access for initial dependencies and IMS sign-in.

The Maven wrapper is included. PostgreSQL is optional when using the local profile.

### Build and start

Run from the repository root:

```powershell
./scripts/build-web.ps1
./scripts/start-server.ps1
```

Open [localhost:8080](http://localhost:8080) and sign in with IMS. Spring Boot serves both the compiled frontend and the API.

The local database and encryption key are created under `server/.local/`. Keep the key private and retain it with your installation. These files are excluded from Git.

### Frontend development with hot reload

In the first terminal, from the repository root:

```powershell
$env:WEB_ORIGIN = 'http://localhost:5173'
./scripts/start-server.ps1
```

In a second terminal:

```powershell
cd apps/web
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE=http://localhost:8080/api
```

### Run the backend with Maven

From the repository root:

```powershell
cd server
./mvnw.cmd spring-boot:run '-Dspring-boot.run.profiles=local'
```

Build the frontend first if you want this server to serve the website too. For IntelliJ, import `server/pom.xml`, select Java 17, set the working directory to `server`, and activate the `local` Spring profile.

### Package the combined app

From the repository root:

```powershell
./scripts/build-web.ps1
./server/mvnw.cmd -f server/pom.xml clean package
cd server
java -jar target/attendly-server-0.0.1-SNAPSHOT.jar --spring.profiles.active=local
```

Rebuild the web bundle after frontend changes. Maven packages the existing bundle; it does not compile Flutter automatically.

For Android setup, see the [Android app README](outputs/attendance_app/README.md).

## Configuration

The default server profile uses PostgreSQL and secure cookies. The `local` profile uses on-disk H2 and permits HTTP development.

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | JDBC PostgreSQL connection URL. |
| `DATABASE_USER` | Database username. |
| `DATABASE_PASSWORD` | Database password; also required by `compose.yaml`. |
| `WEB_ORIGIN` | Frontend origin, including scheme and port. |
| `COOKIE_SECURE` | Keep `true` for HTTPS deployments. |
| `IMS_CREDENTIAL_KEY` | Base64-encoded random 32-byte encryption key, required outside the local profile. |

`compose.yaml` provides an optional PostgreSQL 16 container. Supply `DATABASE_PASSWORD` before running `docker compose up -d`. Keep deployment secrets outside source control.

## Privacy and offline behavior

- Accounts are created only after IMS verifies the student's identity.
- Passwords are not stored in browser storage. Background refresh uses an encrypted server-side password only when enabled by the user.
- ID-card snapshots are encrypted on the server. The browser keeps an account-scoped offline copy.
- The PWA asset cache excludes API responses. Private offline records use the browser's local database.
- Signing out clears this browser's local records. Pending edits must be synced first.
- First use requires a connection. Clearing browser storage can remove unsynced edits.
- Certain IMS outages allow recently verified existing users a restricted session to read saved records, without editing or refreshing.

See [technical notes](docs/technical-notes.md) for authentication, encryption, fallback rules, and sync limitations. The virtual card is a convenience view; it does not establish university approval or replace an officially accepted ID.

## Development checks

From `apps/web`:

```powershell
flutter pub get
flutter analyze
flutter test
```

From the repository root:

```powershell
./server/mvnw.cmd -f server/pom.xml test
```

GitHub Actions checks the web client, builds the frontend, and tests/packages the backend. Normal tests use isolated databases and need no student credentials. The optional live challenge test is enabled separately with `IMS_LIVE_SMOKE=true`.

## Remaining work

- Verify live web ID-card retrieval and wider IMS report variations.
- Validate PostgreSQL deployment and iPhone/Safari offline behavior.
- Add account export/deletion and improve sync-conflict explanations.
- Add production monitoring, backups, managed key rotation, and distributed rate limiting/session storage.
- Complete Android-to-web account migration and cross-semester pending-edit handling.

## License

No project license has been selected yet. Third-party libraries and bundled assets retain their respective licenses. University names and marks belong to their respective owners.
