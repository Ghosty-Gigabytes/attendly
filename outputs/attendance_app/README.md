# Attendly

A Flutter Android attendance tracker with independent official and personal records, an offline calendar, and timetable-based leave experiments. The university minimum is **75% for each subject**. There is no aggregate attendance percentage across subjects.

## Try the app

The app opens at **Sign in to IMS** whenever there is no authenticated session. On first login, enter your student ID, password and the displayed CAPTCHA. After a successful login, credentials are encrypted on this Android device using an Android Keystore key. Subsequent launches fetch a fresh CAPTCHA, run the bundled OCR model and attempt sign-in once. If OCR fails or IMS rejects the attempt, the login stays filled in for manual correction. Signing out deletes the saved credentials. Refresh is available; rejected logins fetch a fresh challenge while retaining your entered credentials. Successful login imports your attendance. Session expiry returns to login.

No illustrative attendance is loaded or displayed. Old demo workspaces cannot unlock the app. Official records and personal logs remain separate. The optional With personal percentage combines official totals with pending personal days, per subject.

The Dart client uses the verified IMS request flow with cookie continuity, hidden-token extraction, CAPTCHA OCR and direct HTTPS form submission. The user has verified foreground login on a physical phone. Headless background login still requires device verification.

## Background refresh, notifications and widget

Android WorkManager refreshes approximately hourly, with internet and sufficient battery, starting no earlier than 15 minutes after leaving the app. Timing is inexact and subject to Android battery optimization; force-stopping the app blocks work until reopening. Scheduled work persists across process death/reboot. Work is cancelled while the app is in the foreground and rescheduled when it leaves, avoiding concurrent foreground/background login. The worker uses the same Dart scraper, encrypted credentials and native CAPTCHA OCR. It makes one login attempt per run; CAPTCHA rejection requests manual sign-in rather than hammering IMS. Transient failures receive bounded, delayed retries.

Settings provides independent switches for background refresh, official below-75% alerts, official-record updates and possible discrepancies. Android 13+ asks permission after successful foreground login; notifications remain optional and denial does not prevent refresh. Identical alerts are deduplicated on device. Official updates compare both totals and nonblank daily records, without treating a new empty future date as an upload. Personal edits cannot generate official-update notifications.

Add the resizable Attendly widget through Settings or your launcher widget picker. It lists up to six subjects, lowest official percentages first, plus the latest successful fetch time and a link to the app for the remaining subjects. Widgets update after successful sync and clear on sign-out/account change. No cross-subject percentage is calculated.

Log a class uses single-select numeric chips for present and absent, with More numbers for larger counts. Raw logs remain editable/deletable. Database mutations reload the latest stored scope inside a transaction so a new background snapshot does not get overwritten by a stale personal edit.

## Implemented

- Per-subject official counts, percentages, immediate leave allowance and recovery counts.
- A persistent toggle showing personal records and a **With personal** percentage alongside official data. IMS takes precedence for populated subject/day cells; blank or missing days can contribute personal counts.
- Overview subject cards open a filtered monthly calendar with separate official/personal percentages, colored present/absent/mixed days, daily counts and month navigation. Personal entries remain independent. Log a class asks for a subject and separate present/absent counts (for example 1 present and 1 absent). Saved personal entries can be deleted; clearing a saved timetable mark leaves its scheduled slot unrecorded.
- Effective-date timetable rules, multiple sessions of the same subject, and configurable counted-class weights.
- A What if? planner with explicit Official/Personal baseline and 75–95% targets.
- Future date ranges, whole-day leave, per-class attend/miss/cancel, holidays and hypothetical extra classes.
- Per-subject chronological projections, intermediate dips, final percentages and recovery forecasts from the remaining timetable.
- Individually suitable leave-date search, saved plans, comparison against a saved plan, and reset.
- Transactional Drift/SQLite storage, serialized edits, and isolation by account/semester. Portal refresh never overwrites personal sessions or scenarios.
- CSV copy to the clipboard with explicit source labels and formula-injection protection.
- Cookie-aware Dart login/navigation/parser, manual CAPTCHA and native Android Tesseract bridge.
- Responsive phone/tablet UI with mandatory IMS login.

## Calculation semantics

For each subject, `A` is attended and `T` is held. At target percentage `p`:

```
eligible:       100*A >= p*T, with T > 0
miss next:      max(0, floor((100*A - p*T) / p))
attend needed:  max(0, ceil((p*T - 100*A) / (100-p)))
```

An empty baseline is displayed as no records. Unknown and cancelled personal sessions are excluded from the denominator. The With personal percentage starts from official totals and adds personal present/absent counts only on days where that subject has a blank or missing IMS record. Once IMS uploads that day, it takes precedence and the personal counts are not added again. Differing subject/day counts are shown as possible discrepancies; incomplete personal logs and delayed uploads can cause them.

The planner assumes all other scheduled classes in the selected future window are held and attended. Mark exceptions explicitly. It does not add hypothetical outcomes to either actual log. Saved plans recalculate against current counts. Plans containing past dates must be moved to a future window. Recovery forecasts assume every remaining scheduled class is held and attended and check at most one year beyond the window. A missing or short timetable is not proof that university recovery is impossible.

## Build

Developed with Flutter 3.47.6 / Dart 3.13.5. Use a compatible stable Flutter SDK, Android SDK 36, and JDK 17 or newer supported by the generated Gradle configuration.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

The APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. This is a development build, not a Play Store release. Configure your own application identifier and release signing before distribution. No signing secrets are included.

Tests use synthetic attendance and a sanitized public IMS login fixture, not saved student information. Test samples are not included in the running application. Widget screenshots are written to the development work directory.

## Enable your trained CAPTCHA model

Place the original `mydigits.traineddata` from your Python project in:

```
assets/tessdata/mydigits.traineddata
```

Rebuild the app. Dart copies the asset into private application storage and calls a small native Android bridge. Tesseract4Android 4.9.0 runs on a dedicated worker thread with page segmentation mode 11, matching the supplied Python configuration. The native engine is recycled after each attempt and temporary CAPTCHA images are removed. If the asset is absent, incompatible, or OCR fails, manual entry remains available. **Recognition accuracy and model compatibility have not been tested without your model.**

## Portal verification still required

The adapter follows:

```
login form → CAPTCHA + hidden fields → login submission
→ My Activities → registered courses + semester
→ My Attendance → form submission → subject totals and dated cells
```

To complete live verification, provide sanitized registered-course and attendance-result HTML. Preserve headers, date labels and representative raw cell values. Remove credentials, cookies, hidden tokens and personal details.

Current explicit parser assumptions:

- Course tables contain code and name/title headers.
- Attendance columns include subject codes; registration order is never used as a silent fallback.
- Semester total row labels include `Overall` and `Present` or `Classes`/`Held`.
- Short dates have the supplied script's `Oct-05` format. Academic-year mapping assumes July–December belong to the first year and January–June to the second. Verify this against the portal before trusting an import.
- Dated cells retain raw values. Blank means no class, 0 means absent and 1 means present; plus-separated values display their individual present/absent counts. The supplied IMS non-class codes (CR, CS, GH, MB, MS, NA, NT, OD, TL) display as blue badges. Days containing only these codes are marked Off; mixed records retain actual 0/1 class counts and a separate off indicator. The interface only shows codes occurring on the selected day, not a full code glossary. Unknown codes remain unclassified. Official overall percentages still use the IMS totals. A missing date outside the fetched report is distinguished from an explicit blank cell.
- JavaScript-only navigation is reported as unsupported rather than executed.

## Source layout

```
lib/domain/       Counts, records, pure-Dart scenario engine and CSV serialization
lib/data/         Drift persistence, controller, portal parser/client, OCR
lib/ui/           Dashboard, calendar, planner, settings/login and reusable widgets
android/          Android host, branding and native Tesseract bridge
test/             Mathematics, parsing, persistence, sync, interaction and layout tests
```

Riverpod supplies the app controller; ListenableBuilder observes it. Persistence uses a versioned Drift database with separate typed JSON entity rows per kind and scope, committed as a transaction. It currently rewrites the active scope on edits; per-entity incremental updates are a future optimization for larger histories.

## Privacy and current limits

- Credentials are submitted directly to the allowlisted HTTPS university hosts and stored as AES-GCM ciphertext in private preferences, with the encryption key in Android Keystore. Cookies stay in memory; saved credentials and CAPTCHA OCR reauthenticate after restart. Sign out removes saved credentials.
- Attendance is stored in the application's private local database. Android automatic backup is disabled. There is no app backend, cloud sync, or analytics.
- Cached records are scoped by account and semester and restored after IMS login. Old scopes remain stored, but a dedicated archive browser is not implemented.
- Daily logging reminders, automatic longest-consecutive-leave search, file sharing/backup, and a full edit-audit timeline remain future work. Date ranges and explicit consecutive-day plans already work in the planner.
- No physical-device or emulator runtime test has been performed. Synthetic parser tests do not constitute live portal validation.

## Third-party software

Flutter/Dart and pub dependencies retain their respective licenses. Roboto's Apache license is included at `assets/fonts/roboto_license.txt`. The Android OCR bridge uses [Tesseract4Android](https://github.com/adaptech-cz/Tesseract4Android), licensed under Apache 2.0, with its bundled OCR/image-library dependencies. See the upstream notices before publishing.

The widget targets a 4×3 launcher footprint with a vertically scrolling list, one subject per row. Swipe vertically for additional subjects. Widget surfaces use Attendly's cream, white and teal palette, with green/amber/red attendance states. Per-subject day guidance estimates consecutive upcoming teaching days from tomorrow using the saved timetable and official counts. Multiple classes on one date count as one day; weekends without that subject do not count. Holidays and changes are not inferred. Without a usable timetable, class counts are shown instead. These are subject-specific days, not permission to miss a whole university day across all subjects. Re-add the widget after upgrading from the earlier non-scrolling layout.

Dates are displayed day-first (6-Oct, 6 Oct 2026, or 06-10-2026). Date pickers use Indian English. Storage and portal parsing retain their original date keys.

Choose Settings → Appearance to use the device theme, Light, or Dark. The choice is saved on this device. The widget footer includes the fetch date and time; Refresh queues a one-time background IMS update using the saved login, even when scheduled refresh is disabled. It waits for internet and shows Queued/Refreshing while pending. Opening the app cancels background work to avoid competing IMS sessions. CAPTCHA or expired-login issues may require opening the app.

The attendance report determines which subjects appear and their column order. Current-semester registrations supply names/details; registered courses absent from attendance are omitted. An attendance code with no matching metadata is still shown using its code.

Saved attendance opens immediately on launch, including offline. A background sign-in and refresh updates it when possible. Five rejected automatic sign-in/CAPTCHA attempts require manual sign-in; connectivity and report parsing errors preserve offline access. First-time users still need to sign in. The calendar includes a subject selector, themed day highlighting, and a selected-day summary.

Designs: Settings > Appearance > Design offers Classic, Bauhaus, and Material (a Google Material 3-inspired design). Brightness is independent: Dark, Light, or System default. Material is an optional in-app design, not a Google-branded product.

Material accent: Settings > Appearance > Accent color offers presets, a custom hex color, and System color. System color uses Android 12+ OS accents, with blue fallback on unsupported devices. Material is the default for new installs; existing saved design selections are preserved.

## Local data and app information

Settings now includes an offline privacy notice, troubleshooting help, installed Android version/build, Flutter dependency licences and the bundled Roboto licence. Privacy, help and local-data deletion are also accessible before signing in. No support contact or policy URL is invented: configure a real public contact and publish a privacy policy before a Play release. Review native dependency notices separately before publishing.

Delete local data asks for confirmation, clears records for every stored account and semester, timetables, plans, personal logs, app preferences and encrypted credentials/key, cancels background work, and clears widget data/notifications. It leaves university records, exported copies and Android permission choices alone. A non-personal reset epoch prevents older background fetches from saving erased data again. Deletion failures are reported and can be retried; sign-out still retains saved records.

Background refresh defaults to off for new installs and requires an explanation/confirmation when enabled. Existing explicit preferences are preserved. Temporary IMS diagnostic logging and obsolete commented parser/service implementations have been removed; validation and error handling remain.

## Weekly timetable editor

Open Weekly timetable from Settings, Calendar, or What if. The editor is a horizontal-scroll week grid with time-proportional subject blocks, fixed weekday headers and a compact-column option. Tap a slot to add a class or a block to edit it; repeat sessions using Duplicate or Copy day. Subjects are searchable. Attendance count is independent of duration.

The AI prompt requests versioned JSON with the actual subject roster, selected lab group, original subject labels, session type, canonical 24-hour times and independent attendance counts. Unknown subject codes and uncertain lab counts stay blank for review; mismatched groups and invalid structure reject the import. Paste JSON (including fenced AI responses) into the import sheet. File selection is not used. CSV remains compatible with day,subject_code,start_time,end_time,attendance_count. Review and fix missing fields, overlaps and duplicates before applying. Imports change only the draft until saved. Attendly does not upload photos or contact an AI service.

Drafts are saved per account/semester, can be restored or discarded, and are removed by Delete local data. Apply confirms the effective range and replaces only that date interval, preserving schedules outside it. Actual attendance is never marked by timetable editing. Existing persisted rules without an end time use a one-hour display duration; review those end times when editing. Their attendance counts are unchanged.

### Timetable viewing and time display
The dedicated Timetable navigation tab shows saved Monday-Friday classes for the selected week. Tap a class for details; use Edit to import or change the schedule. Saturday/Sunday are not columns or selectable days; imported weekend entries require correction rather than being silently discarded. Settings > Time format switches between 12-hour and 24-hour display across the app, time pickers, export timestamps and widget fetch time. Import times remain 24-hour HH:MM regardless of the display setting.

### Timetable home-screen widget
Settings > Background updates & widgets > Add timetable widget opens the Android launcher pin flow. Alternatively, long-press the home screen and choose Widgets > Attendly timetable. The resizable widget shows a scrollable single-day time grid: hourly labels, gaps and blocks proportional to class duration, with subject names/codes, session type, group and start/end times. Small previous/next controls skip weekends; tapping the date returns to today. Saved effective dates are respected. It works offline, updates when the saved schedule/time preference changes, and receives periodic Android widget updates (which the launcher may delay). No background IMS login is needed to view the timetable. The widget has no title or separate Today button.

### Material home-screen widget appearance
Both widgets use Material surfaces, rounded cards, readable secondary text and pill controls. Attendance uses prominent percentage figures and rounded status-coloured progress bars. Widget brightness follows the app Light/Dark/System selection; accents follow the Material accent preference. Changing appearance republishes cached widgets without an IMS fetch. Android 12+ RemoteViews contain both day/night colour variants for system-theme reapplication. Older Android versions use explicit light/dark fallback surfaces and pick up system changes on their next widget update; launchers may defer periodic updates. No app screen design is removed.

Attendance widget footer: compact fetched date/time and icon-only refresh. Attendance progress uses a theme-aware static wave with a separate remaining track. Timetable rendering uses bounded hourly bitmap tiles to support long days without a single oversized RemoteViews image. Native checks live in android/app/src/androidTest; -PwidgetPreview builds a separate test package so an existing installation is not replaced.

### Virtual ID card
The full-screen ID Card view fetches ID Card Details through the authenticated IMS session. It uses Department, the student's Ph.No., and the complete IMS address, with portrait, student signature and university logo loaded through the same session. Front/back tap-to-flip and optional motion effects remain available. Barcode and registrar signature are omitted. Admission year comes from the roll-number prefix; batch duration currently assumes four years for B.Tech and two for M.Tech. Unsupported courses do not receive a guessed end year.

Card details and image bytes are cached privately per account for offline viewing, hidden after sign-out and removed by Delete local data. Missing images are identified without substituting a fake image. This is an independent digital view, not a university-issued credential. Live Personal Info navigation and image availability still require verification with an authenticated account.
