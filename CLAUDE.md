# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Multi-agent market intelligence system running entirely on an iQOO Android phone. No cloud — Ollama in Termux is the LLM, FastAPI in Termux is the backend, Flutter is the Android UI, and OfficeKit opens generated .docx reports. See `docs/PRD.md` and `docs/ARCHITECTURE.md` for full requirements and design.

## Backend (Termux / Python)

Run from the **repo root** (not from `cd backend`) — the package uses `backend.*` imports:

```bash
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Ollama must be running first:
```bash
ollama serve &
ollama pull phi3:mini   # one-time, ~2.3 GB
```

Full startup shortcut (handles Ollama wait loop):
```bash
bash scripts/start.sh
```

Health check: `GET /health` returns `{"status": "ok", "ollama": true/false}`.

There are no automated tests. Lint with `python -m py_compile backend/**/*.py` or run the server and hit endpoints.

## Flutter App

```bash
cd flutter_app
flutter pub get
flutter run                    # on connected device (USB debugging)
flutter build apk --release    # sideload APK
```

Key packages: `dio` (HTTP), `open_filex` (fires Android file intent for .docx), `fl_chart` (charts), `intl` (date formatting). All API calls go through `lib/services/api_service.dart` which hardcodes `http://127.0.0.1:8000`.

## Architecture

### Agent lifecycle (`backend/agents/`)

All agents extend `BaseAgent` (abstract) and follow: `fetch_sources()` → `analyse()` → `store()` → auto-alert on `severity == "high"`. The base `run()` method orchestrates this loop and writes `AgentRun` records. Override `run()` only if post-processing is needed (SalesAgent does this to annotate top-5 leads).

Agent implementations:
- **MarketingAgent** — fetches RSS feeds (TechCrunch + Google Trends India by default); feeds configurable via `marketing_feeds` setting (JSON array)
- **ProductAgent** — fetches Play Store reviews (`google-play-scraper`), Reddit posts, HN Algolia results; sources enabled by settings. Has an inflection-detection step: if new sentiment score deviates ≥ 0.2 from 7-day average for that source type, severity is forced to `"high"`.
- **SalesAgent** — fetches Indeed RSS, blog feeds, and LinkedIn job cards (HTML-scraped, rate-limited to 1 req/10s per company); after `run()`, annotates top-5 leads by score into the first insight's `extra_data`.
- **StrategyAgent** — reads from `insights` table (last 7 days, non-strategy agents), not the web. Writes a `.docx` to `~/storage/downloads/market_briefs/brief_<week_start>.docx` and inserts a `Brief` row.

### Configurable settings keys (stored in `settings` SQLite table)

| Key | Used by | Format |
|---|---|---|
| `ollama_model` | all agents | string, default `phi3:mini` |
| `marketing_feeds` | MarketingAgent | JSON array of RSS URLs |
| `product_app_ids` | ProductAgent | comma-separated Play Store app IDs |
| `product_subreddits` | ProductAgent | comma-separated subreddit names |
| `product_keywords` | ProductAgent | comma-separated HN search keywords |
| `sales_companies` | SalesAgent | comma-separated company names |
| `sales_blog_feeds` | SalesAgent | comma-separated RSS feed URLs |

Agents call `self._get_setting(key, default)` which reads from DB and JSON-decodes if possible.

### Scheduling (`backend/scheduler.py`)

APScheduler `AsyncIOScheduler` (UTC timezone) is started in FastAPI lifespan. Schedules:
- Marketing: every 2 h
- Product: every 4 h
- Sales: every 6 h
- Strategy: cron `day_of_week=sun, hour=8`

All jobs use `misfire_grace_time=300` (fires up to 5 min late after phone wake). Agents can also be triggered on-demand via `POST /agents/{name}/run` (runs in BackgroundTasks).

### Database (`backend/db/`)

SQLite (`market.db` in repo root), WAL mode, `check_same_thread=False`. Tables: `insights`, `agent_runs`, `alerts`, `briefs`, `settings`. The `Insight.extra_data` column stores agent-specific JSON blobs — named `extra_data` because `metadata` is reserved by SQLAlchemy.

### Ollama client (`backend/llm/ollama_client.py`)

Posts to `http://localhost:11434/api/generate` with `format: "json"`. Returns `{}` on any JSON parse failure — all agents must handle empty dicts gracefully with `.get()` and defaults.

### API routes

| Prefix | File |
|---|---|
| `/insights` | `routers/insights.py` |
| `/alerts` | `routers/alerts.py` |
| `/agents` | `routers/agents.py` |
| `/briefs` | `routers/briefs.py` |
| `/settings` | `routers/settings.py` |

Brief download: `GET /briefs/{id}/download` returns the `.docx` file; Flutter downloads it to `Directory.systemTemp` and opens it with `open_filex` (OfficeKit handles the intent).

## Key constraints

- Backend must bind to `127.0.0.1` only (never `0.0.0.0`).
- Ollama model default: `phi3:mini` (≤2.3 GB RAM). User-configurable via the Settings screen.
- Raw scraped text expires after 30 days; processed insights after 90 days (`expires_at` set at insert time, enforced by query filters — no background deletion job).
- `SessionLocal` is used as a context manager (with-block) for FastAPI dependency injection and as a plain session (manual `.close()`) in agent code — both patterns exist.
