# Local commit history

Reconstructed on 7 October 2026 from the current source, at the project owner's request. Dates use the 5–7 October conversation window with deliberately irregular, approximate times in India time (UTC+05:30). They are not recovered timestamps.

Each commit groups final files by feature. Earlier intermediate trees are not guaranteed to build and do not reproduce earlier iterations. Validation is recorded by feature in BUILD_REPORT.md; the earlier toolchain restrictions were subsequently resolved. Author identity comes from the local Git configuration.

SDKs, caches, generated APKs/ZIPs, editor files, and locally ignored OCR/wrapper assets are excluded. No remote push is performed.

| Date and time (IST) | Commit |
| --- | --- |
| 2026-10-05T10:13:27+05:30 | set up the flutter android project |
| 2026-10-05T11:46:53+05:30 | add attendance calculations for each subject |
| 2026-10-05T14:08:19+05:30 | get ims login and captcha working |
| 2026-10-05T17:51:42+05:30 | parse subject totals and daily attendance from ims |
| 2026-10-05T19:23:16+05:30 | save login and attendance locally |
| 2026-10-05T22:37:49+05:30 | add the attendance calendar and personal logs |
| 2026-10-06T00:18:34+05:30 | add leave planning and saved what-if plans |
| 2026-10-06T09:42:11+05:30 | refresh attendance in the background and send alerts |
| 2026-10-06T13:26:57+05:30 | add a scrolling widget with progress bars and refresh |
| 2026-10-06T18:54:23+05:30 | use day-first dates and add attendance export |
| 2026-10-07T11:17:38+05:30 | clean up settings and add light dark and system themes |
| 2026-10-07T15:58:43+05:30 | document setup and the remaining device checks |

## Continuation on 9 October 2026

Appended after `85c0123`; existing commits were not rewritten. Dates below are deliberately irregular organizational timestamps based on the 8–9 October conversation window, not recovered edit times. Both author and committer timestamps use IST. Shared files contain their final accumulated changes, so these feature groupings do not reproduce every historical intermediate implementation and are not individually build-verified. The final app passed 91 tests and static analysis and produced a debug APK; later focused timetable UI checks also passed. No remote push was performed.

| Date and time (IST) | Commit |
| --- | --- |
| 2026-10-08T15:43:29+05:30 | fix the ims semester and attendance column parsing |
| 2026-10-08T17:26:51+05:30 | smooth out page and calendar transitions |
| 2026-10-08T18:39:17+05:30 | use the attendly icon and add a proper splash screen |
| 2026-10-08T21:14:38+05:30 | add bauhaus and material designs with custom accent colours |
| 2026-10-08T23:07:46+05:30 | add pull to refresh and animate attendance as cards appear |
| 2026-10-09T00:52:19+05:30 | keep cached attendance available and add local data controls |
| 2026-10-09T02:24:53+05:30 | add csv imports and a proper weekly timetable editor |
| 2026-10-09T02:48:31+05:30 | update setup notes and keep generated caches out of git |
