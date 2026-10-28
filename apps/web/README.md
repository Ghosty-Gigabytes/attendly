# Attendly web

Flutter Material 3 client for the Spring Boot IMS-backed backend. No separate email account or Google SSO is used.

From the repository root, run `scripts/build-web.ps1`, then `scripts/start-server.ps1`. Open http://localhost:8080.

For frontend development, start the local backend with WEB_ORIGIN=http://localhost:5173, then run from this folder:

```powershell
../../work/flutter.ps1 run -d chrome --web-port 5173 --dart-define=API_BASE=http://localhost:8080/api
```

The mobile ID-card destination opens the private fullscreen viewer; Alt+I or the sidebar opens it on desktop. Authentication, cache, refresh, and key-management details are in the repository README.
