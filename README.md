# Market Intelligence

An on-device, multi-agent market intelligence system designed for an iQOO Android phone. The project combines a local FastAPI backend, scheduled Python agents, SQLite storage, Ollama LLM inference in Termux, and a Flutter Android dashboard.

The goal is to monitor market signals such as competitor campaigns, product sentiment, buying intent, and weekly strategy themes without sending data to a cloud backend.

## Table of Contents

- [Overview](#overview)
- [Current Status](#current-status)
- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Backend](#backend)
- [Flutter App](#flutter-app)
- [Agents](#agents)
- [Pipeline](#pipeline)
- [Database](#database)
- [API Reference](#api-reference)
- [Setup](#setup)
- [Running the Project](#running-the-project)
- [Development Notes](#development-notes)
- [Known Gaps](#known-gaps)
- [Related Docs](#related-docs)

## Overview

Market Intelligence started with four core AI agents and now also includes a newer six-agent market intelligence pipeline.

| Agent | Purpose | Schedule |
| --- | --- | --- |
| Marketing | Reads market and trend feeds, classifies threats and opportunities | Every 2 hours |
| Product | Reads product reviews and public product discussions, estimates sentiment | Every 4 hours |
| Sales | Reads hiring and company announcement signals, estimates buying intent | Every 6 hours |
| Strategy | Synthesizes the last 7 days of insights into a weekly `.docx` brief | Sundays at 08:00 |

Newer pipeline agents:

| Agent | Purpose | Schedule |
| --- | --- | --- |
| Competitor Discovery | Discovers and stores active competitors | Daily at 06:00 UTC |
| Market Trends | Collects broader market trend signals | Every 6 hours |
| Competitor Intelligence | Reads stored competitors and gathers competitor signals | Every 12 hours |
| Demand Lead Signals | Collects demand and lead-intent signals | Every 8 hours |
| Strategy | Synthesizes recent findings into a strategy brief | Sundays at 08:00 UTC, plus full pipeline |
| Alerts Agent | Produces alert-oriented synthesis from recent findings | Every 6 hours |

The system is intentionally local-first:

- Ollama runs on the Android phone through Termux.
- FastAPI runs on `127.0.0.1:8000`.
- SQLite stores insights, agent runs, alerts, and strategy briefs.
- Flutter talks to the backend over localhost.
- Generated strategy briefs are saved as Word documents for OfficeKit or another Android document viewer.

## Current Status

This repository is a working foundation/prototype, not a fully finished production app.

Implemented:

- FastAPI app startup with database initialization and APScheduler.
- SQLite schema for insights, agent runs, alerts, and briefs.
- REST endpoints for insights, alerts, agents, briefs, settings, competitors, the full pipeline, and health checks.
- Ollama client wrapper using `/api/generate` with JSON mode.
- Agent modules for marketing, product, sales, strategy, competitor discovery, market trends, competitor intelligence, demand/lead signals, and alerts.
- Strategy `.docx` generation with `python-docx`.
- Flutter Material app with dashboard, per-agent screens, settings, alert banner, polling, and brief download/open support.
- Termux setup and startup scripts.

Important caveat:

This is still a prototype. The shared agent base now provides settings lookup, model selection, Ollama access, run tracking, insight storage, and alert creation. Some specialized agents may still need endpoint-by-endpoint verification with live data sources and Ollama running before all scheduled jobs can be considered production-ready.

## Architecture

```text
iQOO Android phone
|
|-- Termux
|   |-- Ollama on localhost:11434
|   |-- FastAPI backend on 127.0.0.1:8000
|   |-- SQLite database: market.db
|   |-- APScheduler jobs
|
|-- Flutter Android app
|   |-- Dashboard
|   |-- Agent detail screens
|   |-- Settings
|   |-- Brief download/open flow
|
|-- OfficeKit or compatible document app
    |-- Opens generated .docx strategy briefs
```

Core data flow:

```text
Scheduled agent run
  -> fetch public source data
  -> send structured prompt to Ollama
  -> parse JSON response
  -> store Insight rows in SQLite
  -> create Alert rows for high-severity threats
  -> Flutter polls API and updates dashboard
```

Weekly strategy flow:

```text
Strategy agent
  -> read last 7 days of non-strategy insights
  -> ask Ollama for structured brief sections
  -> write .docx to ~/storage/downloads/market_briefs
  -> insert/update Brief row
  -> expose file through /briefs/{id}/download
```

## Repository Layout

```text
.
|-- backend/
|   |-- main.py                  FastAPI app and lifespan hooks
|   |-- pipeline.py              Full multi-agent pipeline orchestration
|   |-- scheduler.py             APScheduler job registration
|   |-- requirements.txt         Python dependencies
|   |-- agents/
|   |   |-- base.py              Shared agent run/store logic
|   |   |-- competitor_discovery.py
|   |   |-- competitor_intelligence.py
|   |   |-- market_trends.py
|   |   |-- demand_lead_signals.py
|   |   |-- alerts_agent.py
|   |   |-- marketing.py         RSS/trend market signal agent
|   |   |-- product.py           Review, Reddit, and HN sentiment agent
|   |   |-- sales.py             Hiring, blog, and LinkedIn signal agent
|   |   |-- strategy.py          Weekly brief generation agent
|   |-- db/
|   |   |-- database.py          SQLAlchemy engine/session setup
|   |   |-- models.py            ORM models and indexes
|   |-- llm/
|   |   |-- ollama_client.py     Async Ollama API wrapper
|   |-- routers/
|       |-- insights.py          Insight list/detail endpoints
|       |-- alerts.py            Alert list/dismiss endpoints
|       |-- agents.py            Agent status/manual-run endpoints
|       |-- briefs.py            Brief list/download endpoints
|       |-- competitors.py       Competitor list/detail/archive endpoints
|       |-- pipeline.py          Full pipeline trigger endpoint
|       |-- settings.py          Settings list/upsert endpoints
|
|-- flutter_app/
|   |-- pubspec.yaml             Flutter dependencies
|   |-- lib/
|       |-- main.dart            App shell and bottom navigation
|       |-- services/
|       |   |-- api_service.dart Backend REST client
|       |-- models/              Insight, alert, and brief models
|       |-- screens/             Dashboard and feature screens
|
|-- scripts/
|   |-- setup_termux.sh          Termux bootstrap helper
|   |-- start.sh                 Starts Ollama and FastAPI backend
|
|-- docs/
|   |-- PRD.md                   Product requirements
|   |-- ARCHITECTURE.md          Detailed architecture notes
|
|-- team/                        Implementation task briefs
|-- CLAUDE.md                    Agent/developer guidance
```

## Backend

Technology stack:

- Python
- FastAPI
- Uvicorn
- SQLAlchemy
- SQLite
- APScheduler
- httpx
- BeautifulSoup4
- python-docx
- google-play-scraper
- Ollama

Backend entry point:

```bash
uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

On startup, the backend:

1. Creates SQLite tables through `init_db()`.
2. Registers all scheduler jobs.
3. Starts the APScheduler instance.
4. Serves the REST API.

The backend intentionally binds to `127.0.0.1`, keeping it local to the phone.

## Flutter App

The Flutter app is a dark Material 3 Android dashboard.

Main features:

- Bottom navigation for Marketing, Product, Sales, Strategy, and Settings.
- Agent status polling every 10 seconds with running/completion feedback.
- Pull-to-refresh for latest insights and alerts.
- Alert banner for active high-severity alerts.
- Manual agent trigger buttons in Settings, including the newer pipeline agents.
- Model selector UI for `phi3:mini`, `llama3.2:3b`, and `gemma2:2b`.
- Brief download and open flow using `open_filex`.
- Competitor and pipeline API support in the REST client.

The REST client is defined in:

```text
flutter_app/lib/services/api_service.dart
```

The API base URL is currently hard-coded:

```dart
static const String _baseUrl = 'http://127.0.0.1:8000';
```

## Agents

All agents are intended to inherit from `BaseAgent`.

`BaseAgent.run()` is responsible for:

1. Creating an `agent_runs` row with status `running`.
2. Calling `fetch_sources()`.
3. Calling `analyse()` for each fetched item.
4. Storing generated insights.
5. Creating an alert for high-severity threats.
6. Updating the `agent_runs` row with success/failure details.

### Marketing Agent

File:

```text
backend/agents/marketing.py
```

Current source types:

- TechCrunch RSS
- Google Trends daily trending RSS for India
- Configurable `marketing_feeds` setting, once settings persistence is completed

Output fields:

- Summary
- Category: `threat`, `opportunity`, or `neutral`
- Severity: `high`, `medium`, or `low`
- Score
- Key points

### Product Agent

File:

```text
backend/agents/product.py
```

Current source types:

- Google Play reviews for configured app IDs
- Reddit subreddit JSON feeds
- Hacker News Algolia search

The Product agent asks Ollama for sentiment and feature requests, then compares new sentiment against a 7-day average to detect inflection points.

### Sales Agent

File:

```text
backend/agents/sales.py
```

Current source types:

- Indeed RSS searches for configured companies
- Company blog RSS feeds
- Public LinkedIn job search HTML pages

The Sales agent asks Ollama for buying intent fields such as `intent_score`, `company`, and `signal_type`. It also annotates the top five leads from the latest successful run.

### Strategy Agent

File:

```text
backend/agents/strategy.py
```

The Strategy agent does not scrape external data. It reads recent insights from SQLite, groups them by agent and category, calls Ollama for a weekly strategy brief, and writes a `.docx` file.

Brief output directory:

```text
~/storage/downloads/market_briefs
```

Expected brief sections:

- Executive Summary
- Top Threats
- Top Opportunities
- Recommended Actions
- Metrics

### Newer Pipeline Agents

Files:

```text
backend/agents/competitor_discovery.py
backend/agents/market_trends.py
backend/agents/competitor_intelligence.py
backend/agents/demand_lead_signals.py
backend/agents/alerts_agent.py
```

These agents support a broader staged workflow:

1. Discover competitors and store active competitor records.
2. Run market-trend, competitor-intelligence, and demand/lead-signal collection.
3. Run strategy and alert synthesis over the stored findings.

## Pipeline

The full pipeline is orchestrated in:

```text
backend/pipeline.py
```

Execution order:

```text
Stage 0   CompetitorDiscovery
Stage 1   MarketTrends + CompetitorIntelligence + DemandLeadSignals
Stage 2   Strategy + AlertsAgent
```

The scheduler runs the full pipeline daily at 07:00 UTC. It can also be triggered manually through the API:

```http
POST /pipeline/run
```

## Database

SQLite database URL:

```text
sqlite:///./market.db
```

The database is created relative to the process working directory. The Termux startup script runs Uvicorn from the repository root, so the default database file is:

```text
market.db
```

SQLite WAL mode is enabled through a SQLAlchemy connection event.

### Tables

| Table | Purpose |
| --- | --- |
| `insights` | Processed findings from agents |
| `agent_runs` | Scheduled/manual execution history |
| `alerts` | Active and dismissed alert records |
| `briefs` | Weekly strategy brief metadata and file paths |
| `settings` | Key/value settings used by agents and the app |
| `competitors` | Active and archived competitor records |

### Insight fields

| Field | Description |
| --- | --- |
| `agent` | Agent name |
| `run_id` | Related `agent_runs` ID |
| `source` | URL or source label |
| `raw_text` | Original scraped text or source excerpt |
| `summary` | LLM-generated summary |
| `category` | `threat`, `opportunity`, or `neutral` |
| `severity` | `high`, `medium`, or `low` |
| `score` | Agent-specific numeric score |
| `extra_data` | JSON string for agent-specific metadata |
| `created_at` | Creation timestamp |
| `expires_at` | Intended retention timestamp |

## API Reference

Base URL:

```text
http://127.0.0.1:8000
```

Interactive docs are available when the backend is running:

```text
http://127.0.0.1:8000/docs
```

### Health

```http
GET /health
```

Returns backend status and whether Ollama is reachable.

Example response:

```json
{
  "status": "ok",
  "ollama": true
}
```

### Insights

```http
GET /insights
```

Query parameters:

| Parameter | Description |
| --- | --- |
| `agent` | Optional agent filter |
| `category` | Optional category filter |
| `severity` | Optional severity filter |
| `limit` | Result limit, 1 to 500, default 50 |
| `since` | Optional ISO datetime lower bound |

```http
GET /insights/{insight_id}
```

Returns a single insight or `404`.

### Alerts

```http
GET /alerts
```

Returns undismissed alerts.

```http
POST /alerts/{alert_id}/dismiss
```

Marks an alert as dismissed.

### Agents

```http
GET /agents/status
```

Returns last-run and next scheduled run information for each agent.

```http
POST /agents/{name}/run
```

Triggers a manual background run.

Valid `name` values:

- `marketing`
- `product`
- `sales`
- `strategy`
- `competitor_discovery`
- `market_trends`
- `competitor_intelligence`
- `demand_lead_signals`
- `alerts_agent`

### Briefs

```http
GET /briefs
```

Returns strategy brief metadata.

```http
GET /briefs/{brief_id}/download
```

Downloads the generated `.docx` brief.

### Settings

```http
GET /settings
```

Returns stored key/value settings.

```http
POST /settings
```

Creates or updates a setting.

Example body:

```json
{
  "key": "selected_model",
  "value": "phi3:mini"
}
```

### Competitors

```http
GET /competitors
```

Returns active competitors.

```http
GET /competitors/{competitor_id}
```

Returns a single competitor or `404`.

```http
POST /competitors/{competitor_id}/archive
```

Marks a competitor inactive.

### Pipeline

```http
POST /pipeline/run
```

Triggers the full staged pipeline in the background.

## Setup

### Termux Backend Setup

Install Termux on the Android phone, clone the repository, and run:

```bash
bash ~/iq-hack/scripts/setup_termux.sh
```

The script performs:

- `pkg update`
- Python, Git, compiler, and XML library installation
- `pip` upgrade
- Python dependency installation
- `ollama pull phi3:mini`

Manual equivalent:

```bash
pkg update -y
pkg upgrade -y
pkg install python git clang libxml2 libxslt -y
pip install --upgrade pip
cd ~/iq-hack/backend
pip install -r requirements.txt
ollama pull phi3:mini
```

### Python Dependencies

Backend dependencies are pinned in:

```text
backend/requirements.txt
```

Install them with:

```bash
pip install -r backend/requirements.txt
```

### Flutter Setup

From a machine with Flutter installed:

```bash
cd flutter_app
flutter pub get
flutter run
```

To build a release APK:

```bash
cd flutter_app
flutter build apk --release
```

The generated APK will be under:

```text
flutter_app/build/app/outputs/flutter-apk/
```

## Running the Project

### Start Ollama and Backend

In Termux:

```bash
bash ~/iq-hack/scripts/start.sh
```

The script:

1. Starts `ollama serve` in the background.
2. Waits until `http://localhost:11434/api/tags` responds.
3. Starts Uvicorn on `127.0.0.1:8000`.

### Start Backend Manually

If Ollama is already running:

```bash
cd ~/iq-hack
uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

### Verify Backend

```bash
curl http://127.0.0.1:8000/health
```

Expected shape:

```json
{
  "status": "ok",
  "ollama": true
}
```

### Run Flutter App

```bash
cd flutter_app
flutter run
```

The app expects the backend at:

```text
http://127.0.0.1:8000
```

## Development Notes

### Scheduler

Scheduler registration is in:

```text
backend/scheduler.py
```

Configured jobs:

```text
marketing   interval   every 2 hours
product     interval   every 4 hours
sales       interval   every 6 hours
strategy    cron       Sunday 08:00
competitor_discovery       cron       daily 06:00 UTC
market_trends              interval   every 6 hours
competitor_intelligence    interval   every 12 hours
demand_lead_signals        interval   every 8 hours
alerts_agent               interval   every 6 hours
full_pipeline              cron       daily 07:00 UTC
```

All jobs use:

```text
misfire_grace_time=300
```

### Ollama

The Ollama client is in:

```text
backend/llm/ollama_client.py
```

It posts to:

```text
http://localhost:11434/api/generate
```

with:

```json
{
  "format": "json",
  "stream": false
}
```

Default model:

```text
phi3:mini
```

### Alerts

Alerts are created automatically when an insight is both:

```text
category == "threat"
severity == "high"
```

### Generated Briefs

Strategy briefs are written to:

```text
~/storage/downloads/market_briefs
```

The backend stores the path in the `briefs` table and serves the file through `FileResponse`.

## Known Gaps

The next backend tasks are:

- Verify all newer pipeline agents end-to-end with live source data and Ollama running.
- Add seed/default settings for tracked feeds, app IDs, companies, keywords, and selected model.
- Add tests for agent run lifecycle, alert creation, brief generation, and API serialization.
- Add retention cleanup for raw text, insights, alerts, and briefs.
- Expand Flutter Settings persistence around the newer backend settings endpoints.
- Add error UI for backend unavailable, Ollama unavailable, and failed agent runs.

## Related Docs

More detailed product and architecture notes are available in:

- [docs/PRD.md](docs/PRD.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [CLAUDE.md](CLAUDE.md)

