# Person 2 — Agents Engineer

**Start:** After Person 1 has delivered `backend/agents/base.py` and `backend/db/models.py`  
**Unblock:** Nobody — you are the last backend piece

---

## Your files

```
backend/agents/marketing.py
backend/agents/product.py
backend/agents/sales.py
backend/agents/strategy.py
```

Do **not** touch anything outside this list. In particular: do not modify `base.py`, `models.py`, `database.py`, or any router file.

---

## Prompt — paste this into Claude Code at the repo root

```
You are implementing the four concrete AI agents for a market intelligence system. Read CLAUDE.md, docs/ARCHITECTURE.md (especially §6), and docs/PRD.md (§4) before writing any code. Person 1 has already built the foundation layer — do not modify any files outside your scope.

Your scope — create these four files only:
  backend/agents/marketing.py
  backend/agents/product.py
  backend/agents/sales.py
  backend/agents/strategy.py

Read backend/agents/base.py first to understand BaseAgent. Each agent must subclass BaseAgent and implement fetch_sources() and analyse().

Marketing agent (runs every 2 h):
- fetch_sources(): pull from RSS feeds listed in a 'settings' SQLite row keyed 'marketing_feeds' (default to TechCrunch + Google Trends IN RSS). Use httpx async client.
- analyse(): prompt Ollama to extract {"summary", "category": threat|opportunity|neutral, "severity": high|medium|low, "score": 0.0-1.0, "key_points": [...]}.
- Emit an alert record for any severity=high finding.

Product agent (runs every 4 h):
- fetch_sources(): Google Play reviews via google-play-scraper for app IDs in 'settings' row 'product_app_ids'; Reddit JSON feeds for subreddits in 'product_subreddits'; HN Algolia search for 'product_keywords'.
- analyse(): extract sentiment score (-1 to +1) and feature requests. Detect inflection if |score - 7-day avg| >= 0.2 and emit alert.

Sales agent (runs every 6 h):
- fetch_sources(): Indeed RSS for company names in 'settings' row 'sales_companies'; company blog RSS feeds in 'sales_blog_feeds'; LinkedIn public HTML scrape rate-limited to 1 req/10 s.
- analyse(): score buying intent as high/medium/low. Store top-5 leads per run in metadata JSON field.

Strategy agent (runs weekly Sunday 08:00, timeout 180 s):
- fetch_sources(): reads last 7 days of rows from insights table — no external HTTP calls.
- analyse(): builds a long structured prompt with aggregated findings grouped by category, calls Ollama, parses response into sections: Executive Summary, Top Threats, Top Opportunities, Recommended Actions, Metrics.
- After storing the insight, generate a .docx using python-docx with one heading per section; save to ~/storage/downloads/market_briefs/brief_{week_start}.docx; insert a record into the briefs table.

Constraints:
- Do NOT modify base.py, models.py, database.py, or any router.
- All HTTP calls must use httpx.AsyncClient with a 30 s timeout; catch httpx.ConnectError and log as skipped without failing the run.
- Each agent must import and use the SessionLocal from backend.db.database for DB writes.

Verify by hitting POST /agents/marketing/run and checking that a row appears in the insights table.
```

---

## Done when

- `POST /agents/marketing/run` completes and an `insights` row is visible in the DB
- `POST /agents/strategy/run` produces a `.docx` file in `~/storage/downloads/market_briefs/`
- No modifications to any P1 file
