# Architecture Document
## Multi-Agent Market Intelligence System

**Version:** 1.0  
**Date:** 2026-06-13  
**Target device:** iQOO Android phone (ARM64, ~8 GB RAM, ~128 GB storage)

---

## 1. System Overview

The entire system runs on a single iQOO phone. There is no cloud backend. Three processes run inside Termux; the Flutter app runs as a normal Android app and communicates with the Termux backend over localhost.

```
┌──────────────────────────────────────────────────────────────┐
│  iQOO Android Phone                                          │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Termux                                             │    │
│  │                                                     │    │
│  │  ┌──────────────┐    ┌──────────────────────────┐  │    │
│  │  │  Ollama      │◄───│  FastAPI Backend          │  │    │
│  │  │  :11434      │    │  :8000                    │  │    │
│  │  │              │    │  ├── agents/               │  │    │
│  │  │  Phi-3-mini  │    │  │   ├── marketing.py      │  │    │
│  │  │  (GGUF/ARM)  │    │  │   ├── product.py        │  │    │
│  │  └──────────────┘    │  │   ├── sales.py          │  │    │
│  │                      │  │   └── strategy.py       │  │    │
│  │  ┌──────────────┐    │  ├── scheduler.py           │  │    │
│  │  │  SQLite DB   │◄───│  │   (APScheduler)         │  │    │
│  │  │  market.db   │    │  └── db/                   │  │    │
│  │  └──────────────┘    └──────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │ HTTP REST (localhost)         │
│  ┌───────────────────────────▼─────────────────────────┐    │
│  │  Flutter App (Android)                              │    │
│  │  Dashboard · Alerts · Per-agent screens · Settings  │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │ Intent (file open)           │
│  ┌───────────────────────────▼─────────────────────────┐    │
│  │  OfficeKit (Android App)                            │    │
│  │  Opens .docx weekly briefs for reading/editing      │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| LLM Inference | Ollama 0.3+ (Termux) | Native ARM64 support, runs Phi-3-mini at ~4 tok/s on iQOO |
| LLM Model | `phi3:mini` (3.8B, Q4_K_M ≈ 2.3 GB) | Fits in RAM alongside backend; fast reasoning |
| Backend language | Python 3.11 | Rich scraping libraries; Termux packages available |
| Web framework | FastAPI + Uvicorn | Async, lightweight, self-documenting |
| Task scheduler | APScheduler 3.x | In-process job scheduling; no Redis/Celery needed |
| Database | SQLite 3 via SQLAlchemy | On-device, zero-server, file-based |
| HTTP scraping | httpx + BeautifulSoup4 | Async HTTP; handles RSS and HTML |
| Report generation | python-docx | Pure Python .docx generation |
| Frontend | Flutter 3.x (Dart) | Single codebase, smooth Android UI, good charts |
| Charts | fl_chart (Flutter) | Lightweight chart library, no JS bridge |
| Reports viewer | OfficeKit (pre-installed on iQOO) | Native Android app, opens .docx via intent |

---

## 3. Repository Layout

```
iq-hack/
├── docs/
│   ├── PRD.md
│   └── ARCHITECTURE.md
│
├── backend/
│   ├── main.py                  # FastAPI app factory + lifespan
│   ├── requirements.txt
│   ├── agents/
│   │   ├── base.py              # BaseAgent class (fetch → prompt → store)
│   │   ├── marketing.py
│   │   ├── product.py
│   │   ├── sales.py
│   │   └── strategy.py
│   ├── db/
│   │   ├── database.py          # SQLAlchemy engine + session factory
│   │   └── models.py            # ORM models
│   ├── llm/
│   │   └── ollama_client.py     # Thin async wrapper around Ollama /api/generate
│   ├── scheduler.py             # APScheduler config + job registration
│   └── routers/
│       ├── insights.py          # GET /insights, GET /insights/{id}
│       ├── alerts.py            # GET /alerts, POST /alerts/{id}/dismiss
│       ├── agents.py            # POST /agents/{name}/run, GET /agents/status
│       └── briefs.py            # GET /briefs, GET /briefs/{id}/download
│
├── flutter_app/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── services/
│       │   └── api_service.dart  # Dio-based REST client
│       ├── models/
│       │   ├── insight.dart
│       │   ├── alert.dart
│       │   └── brief.dart
│       └── screens/
│           ├── dashboard.dart
│           ├── marketing_screen.dart
│           ├── product_screen.dart
│           ├── sales_screen.dart
│           ├── strategy_screen.dart
│           └── settings_screen.dart
│
└── scripts/
    ├── setup_termux.sh           # Bootstrap: pkg install + pip + ollama pull
    └── start.sh                  # Launch Ollama + uvicorn
```

---

## 4. Database Schema

### Tables

```sql
-- Stores every processed finding from any agent
CREATE TABLE insights (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    agent       TEXT NOT NULL,          -- 'marketing' | 'product' | 'sales' | 'strategy'
    run_id      INTEGER NOT NULL,
    source      TEXT NOT NULL,          -- URL or feed name
    raw_text    TEXT,                   -- original scraped text (nullable after retention)
    summary     TEXT NOT NULL,          -- Ollama-generated summary
    category    TEXT NOT NULL,          -- 'threat' | 'opportunity' | 'neutral'
    severity    TEXT NOT NULL,          -- 'high' | 'medium' | 'low'
    score       REAL,                   -- agent-specific numeric score (sentiment, intent, etc.)
    metadata    TEXT,                   -- JSON blob for agent-specific fields
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at  DATETIME               -- set by agent based on retention policy
);

-- Tracks each scheduled job execution
CREATE TABLE agent_runs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    agent       TEXT NOT NULL,
    started_at  DATETIME NOT NULL,
    finished_at DATETIME,
    status      TEXT NOT NULL,         -- 'running' | 'success' | 'failed'
    findings    INTEGER DEFAULT 0,     -- count of insights produced
    error       TEXT                   -- error message if failed
);

-- Active alerts surfaced to the Flutter UI
CREATE TABLE alerts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    insight_id  INTEGER REFERENCES insights(id),
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    dismissed   INTEGER DEFAULT 0,    -- boolean
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Weekly Strategy brief files
CREATE TABLE briefs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    week_start  DATE NOT NULL,
    file_path   TEXT NOT NULL,         -- absolute path to .docx on device
    summary     TEXT,                  -- executive summary for preview
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Indexes

```sql
CREATE INDEX idx_insights_agent_created ON insights(agent, created_at DESC);
CREATE INDEX idx_alerts_dismissed        ON alerts(dismissed, created_at DESC);
CREATE INDEX idx_agent_runs_agent        ON agent_runs(agent, started_at DESC);
```

---

## 5. API Endpoint Map

Base URL: `http://localhost:8000`

### Insights

| Method | Path | Description |
|---|---|---|
| GET | `/insights` | List insights; query params: `agent`, `category`, `severity`, `limit`, `since` |
| GET | `/insights/{id}` | Single insight detail |

### Alerts

| Method | Path | Description |
|---|---|---|
| GET | `/alerts` | List undismissed alerts |
| POST | `/alerts/{id}/dismiss` | Dismiss an alert |

### Agents

| Method | Path | Description |
|---|---|---|
| GET | `/agents/status` | Last run status + next scheduled time for all four agents |
| POST | `/agents/{name}/run` | Trigger a manual run (`name`: marketing, product, sales, strategy) |

### Briefs

| Method | Path | Description |
|---|---|---|
| GET | `/briefs` | List all weekly briefs metadata |
| GET | `/briefs/{id}/download` | Stream the .docx file |

### Health

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Returns `{"status":"ok","ollama":true/false}` |

---

## 6. Agent Design

Each agent inherits from `BaseAgent`:

```python
# backend/agents/base.py (pseudocode)
class BaseAgent:
    async def fetch_sources(self) -> list[RawItem]
    async def analyse(self, item: RawItem) -> Insight  # calls Ollama
    async def store(self, insight: Insight)
    async def run(self):  # orchestrates fetch → analyse → store → alert
```

### Ollama prompt pattern

All agents use a structured prompt with JSON output mode:

```
System: You are a market intelligence analyst. Respond only with valid JSON.
User: Analyse this content and return:
  {"summary": "...", "category": "threat|opportunity|neutral",
   "severity": "high|medium|low", "score": 0.0–1.0, "key_points": [...]}

Content: {raw_text}
```

Ollama is called via `POST /api/generate` with `format: "json"`.

### Marketing Agent fetch sources

- RSS feeds: list from `settings.marketing_feeds` (default: TechCrunch, The Verge, industry-specific)
- Google Trends: `https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN` (public RSS)
- Meta Ad Library: public search endpoint (HTML scrape, no auth)

### Product Agent fetch sources

- Google Play reviews: `google-play-scraper` Python package
- Reddit: public RSS `https://www.reddit.com/r/{subreddit}/new.json`
- HN Algolia: `https://hn.algolia.com/api/v1/search?query={keyword}&tags=story`

### Sales Agent fetch sources

- Indeed RSS: `https://www.indeed.com/rss?q={company}&l=`
- Company blogs: RSS feeds from tracked company list
- LinkedIn: public job listing HTML scrape (rate-limited, 1 req/10 s)

### Strategy Agent

- No external fetching — reads last 7 days from `insights` table
- Builds a long structured prompt with aggregated findings per category
- Calls Ollama (longer timeout: 120 s)
- Parses response into sections and writes .docx via python-docx
- File stored at `~/storage/downloads/market_briefs/brief_{week}.docx`

---

## 7. Flutter App Architecture

Pattern: **Feature-first with a service layer**

```
lib/
├── services/api_service.dart      # single Dio client, base URL = localhost:8000
├── models/                        # Freezed/fromJson data classes
└── screens/                       # each screen manages its own state via StatefulWidget
                                   # (simple enough to avoid Bloc/Riverpod for v1)
```

### Dashboard polling

The dashboard polls `GET /insights?limit=50` and `GET /alerts` every 30 s using a `Timer.periodic`. A `RefreshIndicator` triggers immediate refresh.

### OfficeKit integration

```dart
// Open .docx from the FastAPI download URL via Android intent
final filePath = await _downloadBrief(briefId);  // saves to cache dir
await OpenFilex.open(filePath);  // opens OfficeKit via Android file intent
```

Uses the `open_filex` Flutter package; OfficeKit registers as the default .docx handler on iQOO.

---

## 8. Scheduler Configuration

```python
# backend/scheduler.py
scheduler.add_job(marketing_agent.run,  'interval', hours=2,   id='marketing')
scheduler.add_job(product_agent.run,    'interval', hours=4,   id='product')
scheduler.add_job(sales_agent.run,      'interval', hours=6,   id='sales')
scheduler.add_job(strategy_agent.run,   'cron',     day_of_week='sun', hour=8, id='strategy')
```

Jobs use `misfire_grace_time=300` (5 min) so a delayed job still runs after phone wake.

---

## 9. Ollama Model Selection

| Model | Size (Q4_K_M) | Speed on ARM64 | Reasoning | Chosen |
|---|---|---|---|---|
| `phi3:mini` | 2.3 GB | ~4–6 tok/s | Good for JSON extraction | **Yes** |
| `llama3.2:3b` | 1.9 GB | ~5–7 tok/s | Good general | Alternative |
| `gemma2:2b` | 1.6 GB | ~7–9 tok/s | Fast, less accurate | Fallback |

Default: `phi3:mini`. User can switch in Settings screen; model name stored in SQLite `settings` table.

---

## 10. Setup Instructions

### Step 1 — Termux bootstrap

```bash
# In Termux
pkg update && pkg upgrade -y
pkg install python git clang libxml2 libxslt -y
pip install --upgrade pip
```

### Step 2 — Install Ollama in Termux

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull phi3:mini
```

### Step 3 — Install backend dependencies

```bash
cd ~/iq-hack/backend
pip install -r requirements.txt
```

`requirements.txt` includes: `fastapi uvicorn[standard] sqlalchemy apscheduler httpx beautifulsoup4 python-docx google-play-scraper`

### Step 4 — Start the backend

```bash
~/iq-hack/scripts/start.sh
# Starts Ollama as background process, then uvicorn on :8000
```

### Step 5 — Build and install Flutter app

On a development machine with Flutter SDK:

```bash
cd ~/iq-hack/flutter_app
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or sideload the APK directly onto the iQOO phone.

---

## 11. Security Considerations

- FastAPI binds to `127.0.0.1:8000` only — not accessible from LAN
- No authentication needed (single-user, local-only)
- Scraped raw text is stored unencrypted in SQLite (acceptable for personal intel data)
- No credentials stored; all sources are public
- .docx files written to internal storage, not shared external storage

---

## 12. Failure Modes and Mitigations

| Failure | Mitigation |
|---|---|
| Ollama OOM during agent run | `OLLAMA_MAX_LOADED_MODELS=1`; agent retries once after 30 s |
| Source website unreachable | Agent catches `httpx.ConnectError`; logs as skipped; does not fail the run |
| APScheduler job missed (phone asleep) | `misfire_grace_time=300`; job runs on next wake if within grace window |
| SQLite locked (concurrent writes) | `check_same_thread=False`; WAL mode enabled on DB init |
| Strategy brief generation timeout | Ollama timeout set to 180 s; partial brief saved if timeout hit |

---

## 13. Future Considerations (Post-v1)

- WebSocket push from FastAPI to Flutter for sub-second alert delivery
- Background Termux service via `termux-services` (runit) for auto-start on boot
- Encrypted SQLite via SQLCipher for sensitive competitive data
- Sync briefs to laptop via local Wi-Fi (rsync or scp)
- Swap Phi-3-mini for Llama 3.1 8B if iQOO model has ≥12 GB RAM
