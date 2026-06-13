# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Multi-agent market intelligence system running entirely on an iQOO Android phone. No cloud — Ollama in Termux is the LLM, FastAPI in Termux is the backend, Flutter is the Android UI, and OfficeKit opens generated .docx reports. See `docs/PRD.md` and `docs/ARCHITECTURE.md` for full requirements and design.

## Backend (Termux / Python)

```bash
cd backend
pip install -r requirements.txt          # install deps
uvicorn main:app --reload --host 127.0.0.1 --port 8000   # dev server
```

Ollama must be running first:
```bash
ollama serve &          # starts on :11434
ollama pull phi3:mini   # one-time model download (~2.3 GB)
```

Full startup shortcut:
```bash
bash scripts/start.sh
```

## Flutter App

```bash
cd flutter_app
flutter pub get
flutter run                        # on connected device (USB debugging)
flutter build apk --release        # build APK for sideload
```

The app always talks to `http://127.0.0.1:8000` — no env config needed since everything is on-device.

## Architecture in brief

- **Four agents** (`backend/agents/`) each inherit `BaseAgent` and follow fetch → Ollama prompt → SQLite store → alert pattern.
- **APScheduler** (inside the FastAPI process) drives all scheduling: Marketing every 2 h, Product every 4 h, Sales every 6 h, Strategy weekly Sunday 08:00.
- **SQLite** (`market.db`) is the only database. WAL mode is enabled. Tables: `insights`, `agent_runs`, `alerts`, `briefs`.
- **Ollama** is called via `POST /api/generate` with `format: "json"` — all agents expect structured JSON back.
- **Strategy agent** reads from `insights` (last 7 days) rather than scraping; produces a `.docx` via python-docx stored in `~/storage/downloads/market_briefs/`.
- **Flutter** opens `.docx` briefs by downloading from `GET /briefs/{id}/download` and firing an Android file intent — OfficeKit picks it up.

## Key constraints

- Ollama model default: `phi3:mini` (≤2.3 GB RAM). Model name is stored in a `settings` SQLite table and user-configurable in the app.
- Backend must bind to `127.0.0.1` only (never `0.0.0.0`).
- APScheduler jobs use `misfire_grace_time=300` so jobs still fire after phone wake.
- SQLite is opened with WAL mode and `check_same_thread=False` to handle FastAPI's async workers.
- Raw scraped text expires after 30 days; processed insights after 90 days.
