# Person 1 — Backend Foundation

**Start:** Immediately (no dependencies)  
**Unblock:** Person 2 waits for your `base.py` and `models.py`

---

## Your files

```
backend/requirements.txt
backend/db/database.py
backend/db/models.py
backend/llm/ollama_client.py
backend/agents/base.py
backend/main.py
backend/scheduler.py
backend/routers/insights.py
backend/routers/alerts.py
backend/routers/agents.py
backend/routers/briefs.py
scripts/setup_termux.sh
scripts/start.sh
```

Do **not** touch anything outside this list.

---

## Prompt — paste this into Claude Code at the repo root

```
You are building the backend foundation for a multi-agent market intelligence system running on an iQOO Android phone (Termux + Ollama + FastAPI). Read CLAUDE.md, docs/ARCHITECTURE.md, and docs/PRD.md before writing any code.

Your scope — create these files exactly:
  backend/requirements.txt
  backend/db/database.py
  backend/db/models.py
  backend/llm/ollama_client.py
  backend/agents/base.py
  backend/main.py
  backend/scheduler.py
  backend/routers/insights.py
  backend/routers/alerts.py
  backend/routers/agents.py
  backend/routers/briefs.py
  scripts/setup_termux.sh
  scripts/start.sh

Constraints:
- Do NOT create any of the four concrete agent files (marketing.py, product.py, sales.py, strategy.py) — those belong to another team member.
- database.py must enable WAL mode and check_same_thread=False on the SQLAlchemy engine.
- models.py must implement the exact 4-table schema from ARCHITECTURE.md §4: insights, agent_runs, alerts, briefs.
- ollama_client.py: async wrapper around POST http://localhost:11434/api/generate with format="json"; expose a single async def generate(model, system, user, timeout=60) -> dict.
- base.py: abstract BaseAgent with async methods fetch_sources() -> list[dict], analyse(item: dict) -> dict (calls ollama_client), store(insight: dict), run() orchestrating them. run() must write an agent_runs record with status='running' before starting and update it to 'success'/'failed' on completion. High-severity findings must insert an alerts record.
- main.py: FastAPI app with lifespan that initialises DB and starts APScheduler. Bind to 127.0.0.1:8000 only.
- scheduler.py: register the four jobs per ARCHITECTURE.md §8, importing agent classes by name (stubs are fine — the classes will be provided by Person 2). Use misfire_grace_time=300.
- All routers implement the endpoints listed in ARCHITECTURE.md §5 exactly.
- scripts/setup_termux.sh: installs pkg deps (python, git, clang, libxml2, libxslt), then pip installs requirements.txt, then pulls phi3:mini via ollama.
- scripts/start.sh: starts ollama serve in background, waits for :11434, then runs uvicorn.

When done, verify by running: uvicorn backend.main:app --host 127.0.0.1 --port 8000 and confirming GET /health returns {"status":"ok"}.
```

---

## Done when

- `GET /health` returns `{"status": "ok", "ollama": true/false}`
- All four router files exist with correct endpoints
- `base.py` is abstract and importable with no concrete agent files present
- `scripts/start.sh` launches both Ollama and uvicorn cleanly
