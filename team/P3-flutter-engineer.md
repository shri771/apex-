# Person 3 — Flutter Engineer

**Start:** Immediately (parallel with Person 1 — uses API contract from `docs/ARCHITECTURE.md §5`)  
**Unblock:** Nobody

---

## Your files

```
flutter_app/pubspec.yaml
flutter_app/lib/main.dart
flutter_app/lib/services/api_service.dart
flutter_app/lib/models/insight.dart
flutter_app/lib/models/alert.dart
flutter_app/lib/models/brief.dart
flutter_app/lib/screens/dashboard.dart
flutter_app/lib/screens/marketing_screen.dart
flutter_app/lib/screens/product_screen.dart
flutter_app/lib/screens/sales_screen.dart
flutter_app/lib/screens/strategy_screen.dart
flutter_app/lib/screens/settings_screen.dart
```

Do **not** touch anything outside `flutter_app/`. You don't need the backend running to start — stub the API responses until Person 1 is done.

---

## Prompt — paste this into Claude Code (Flutter SDK must be installed on your machine)

```
You are building the Flutter Android app for a market intelligence system. Read CLAUDE.md, docs/ARCHITECTURE.md (§5 API endpoints, §7 Flutter architecture), and docs/PRD.md (§5 Dashboard Requirements) before writing any code. The backend runs at http://127.0.0.1:8000 — you can stub responses until it is ready.

Your scope — create the entire flutter_app/ directory:
  flutter_app/pubspec.yaml
  flutter_app/lib/main.dart
  flutter_app/lib/services/api_service.dart
  flutter_app/lib/models/insight.dart
  flutter_app/lib/models/alert.dart
  flutter_app/lib/models/brief.dart
  flutter_app/lib/screens/dashboard.dart
  flutter_app/lib/screens/marketing_screen.dart
  flutter_app/lib/screens/product_screen.dart
  flutter_app/lib/screens/sales_screen.dart
  flutter_app/lib/screens/strategy_screen.dart
  flutter_app/lib/screens/settings_screen.dart

pubspec.yaml dependencies: dio (HTTP client), fl_chart (charts), open_filex (OfficeKit intent), intl. No Riverpod/Bloc — StatefulWidget + setState only.

api_service.dart: single Dio instance pointing to http://127.0.0.1:8000. Methods:
  getInsights({agent, category, severity, limit, since}) -> List<Insight>
  getAlerts() -> List<Alert>
  dismissAlert(int id)
  getAgentStatus() -> Map
  triggerAgentRun(String name)
  getBriefs() -> List<Brief>
  downloadBrief(int id) -> String (local file path)

All models: fromJson constructors matching the ARCHITECTURE.md §4 schema field names exactly.

Dashboard screen:
- Polls GET /insights?limit=50 and GET /alerts every 30 s via Timer.periodic.
- Shows a persistent alert banner at top when any alert is present; tapping drills into the insight; banner has a dismiss button.
- Scrolling card feed below: each card shows agent icon, category badge (colour-coded: red=threat, green=opportunity, grey=neutral), summary text, relative timestamp.
- Pull-to-refresh triggers immediate re-fetch.

Per-agent screens (reachable from bottom navigation bar):
- Marketing: trend keywords list + source feed list.
- Product: sentiment score line chart (fl_chart) over last 14 days; feature request chips.
- Sales: lead table sorted by intent score (high first); company name + signal summary.
- Strategy: list of weekly briefs (date + executive summary preview); tapping a brief calls downloadBrief() then OpenFilex.open() to launch OfficeKit.

Settings screen: text fields for tracked keywords, competitor names, app IDs; a dropdown to pick Ollama model; a manual-run button per agent that calls POST /agents/{name}/run.

Constraints:
- Base URL is hardcoded to http://127.0.0.1:8000 (no env config needed — single-user on-device).
- Do NOT implement any backend logic or modify files outside flutter_app/.
- Use StatefulWidget + setState for local state; no external state management package.

Verify with: flutter run on a connected iQOO device (or emulator) — dashboard loads, alert banner shows if any alerts exist, Strategy screen brief list renders, tapping a brief opens OfficeKit.
```

---

## Done when

- `flutter run` connects to `localhost:8000` and dashboard renders
- Alert banner appears and dismiss works
- Strategy screen brief list shows; tapping a brief opens OfficeKit via intent
- No files modified outside `flutter_app/`
