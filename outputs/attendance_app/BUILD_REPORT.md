# Attendly 0.2.0+4 — verification

Verified 2026-10-06 with Flutter 3.47.6 / Dart 3.13.5.

- Full automated suite: **42 tests passed**. Earlier legacy Date-header and IMS-request test mismatches are resolved; tests now reflect the user's verified request flow and header-based subject mapping.
- Static analysis: no issues found in the final implementation.
- Android debug APK: compiled, including Android WorkManager, the headless Flutter entry point, shared encrypted-credential/OCR bridges, notification channels and AppWidgetProvider.
- Test coverage includes pending-day aggregation, official precedence, matching upload reconciliation, off-day/partial-record discrepancies, event generation, unchanged-update suppression, stale foreground state preserving background official totals, numeric selection, scoped persistence, saved login, phone/tablet layouts and subject-specific table column order.

## Implemented behavior

WorkManager schedules approximately hourly, with internet/battery constraints and a 15-minute initial delay after leaving the app. A native worker starts the retained Dart background entry point and uses the existing IMS scraper, saved encrypted credentials and OCR. A run is bounded to three minutes with limited retry attempts. Foreground activity cancels background work to avoid competing logins; leaving the app reschedules it. Successful refresh merges only official records into the latest stored account/semester scope. Personal edits also reload stored state inside a transaction; SQLite uses WAL and a busy timeout.

Alerts cover official attendance below 75%, changed official totals/daily records, possible log discrepancies, and manual sign-in needed for failed CAPTCHA. Notifications are deduplicated and permission-aware. The widget shows up to six subjects in risk order, fetch time, and opens the app on tap. Sign-out cancels work and clears widget/notifications. Settings provides toggles and widget pinning.

With personal means official totals plus personal counts for blank/missing official days only. Nonblank official days win, including off codes; disagreements are displayed as possible discrepancies. Daily logs may be incomplete or IMS uploads delayed, so discrepancies do not rewrite either source.

## Device validation still required

Native compilation and Dart tests do not verify OEM battery behavior, reboot scheduling, headless OCR/sign-in against a live account, permission dialogs, or launcher widget rendering. Install the APK, allow notifications, add the widget, leave the app in the background with internet, and inspect Settings' last background attempt after Android permits the job. A force-stopped app cannot run scheduled work until reopened. Credentials and real student records are not embedded in the test fixtures.

The APK is debug-signed, not a Play Store release. Builds/tests ran in an isolated validation copy to keep temporary R: paths out of the user's Android Studio project.

Subject labels now include names alongside codes throughout selectors, calendar records, timetable, planner comparisons, discrepancies, notifications, widget rows and CSV exports. Existing 42 tests passed after this change; static analysis was clean.

Widget visual refresh: rounded background, separate subject cards, color-coded percentages, name/code hierarchy and height-aware row count. Android build and static analysis passed; six reconciliation/publication tests passed. Launcher rendering still requires device validation.

Widget resize correction: removed six-subject cap, used separate portrait/landscape height bounds, distributed remaining height across subject cards, wrapped names, and added per-subject recovery/leave guidance where space permits. Native APK compilation verified; final launcher layout needs device confirmation.

Scrollable widget grid: Android RemoteViewsService/GridView, two columns, target 4×3 launcher footprint, Material light/dark and dynamic-color resources. Added timetable-based day estimates with four dedicated tests; all ten targeted tests passed and APK compilation passed. Launcher sizing/scroll gestures and dynamic colors need device verification.

Widget presentation simplified: removed app title and low-attendance counter; full-width scrolling subject rows with larger text, percentage aligned right, secondary code/counts, day guidance, and a quiet official-refresh footer. Material colors retained.

Widget visual refinement: softly rounded neutral Material surfaces, medium-weight typography, separated class totals and day guidance, and slim progress bars matching percentage colors (red below 75%, amber 75–79.9%, green 80%+; empty neutral track for no records). Native build verifies RemoteViews resources; launcher appearance requires device confirmation.

Palette/date update: widget uses the app's exact cream/white/teal/green/amber/red palette across system themes. App locale is Indian English; display dates, discrepancy dates, background/widget timestamps, and CSV dates are day-first. Internal date keys remain ISO for storage. All 46 tests passed.

Plain-language copy update: simplified personal-log explanations, attendance-difference alerts and planner guidance. Corrected stale planner text that said the personal option used personal logs alone. Attendance calculations are unchanged; static analysis passed.

Widget refresh and dark mode: one-time network-constrained work with duplicate-tap suppression, shared-worker concurrency guard, queued/running labels and saved-login reuse; fetch time restored. Persistent system/light/dark appearance, theme-aware cards, calendar, text, dialogs and navigation. Existing 46-test suite passed; added dark preference/navigation test passed and its rendered preview was inspected. Static analysis clean; Android debug build succeeded. Live widget refresh still requires device/account validation.

2026-10-07 pending verification: Removed Display & targets and its personal toggle. Appearance is now a Dark / Light / System default segmented control. Dark surfaces changed to neutral charcoal. Initial static analysis passed; UI tests were updated for the removed toggle and lazy-loaded Appearance control. Final test/build could not run because Windows denied executable path resolution after the environment restart. The packaged APK is the previous version; the source ZIP contains these newer changes.
