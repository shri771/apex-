# Product Requirements Document
## Multi-Agent Market Intelligence System

**Version:** 1.0  
**Date:** 2026-06-13  
**Platform:** iQOO Android Phone (on-device, offline-first)

---

## 1. Problem Statement

Market intelligence today requires monitoring dozens of fragmented signals simultaneously — competitor ads, product reviews, job postings, industry news — and synthesising them into decisions. Teams either pay for expensive SaaS platforms that share their data with third parties, or manually check sources and miss critical shifts.

This system replaces both with four specialised AI agents running entirely on-device, feeding a unified dashboard accessible anywhere, with no cloud dependency and no data leaving the phone.

---

## 2. User Personas

### Persona A — Field Operator (primary)
- Uses the iQOO phone throughout the day
- Needs at-a-glance threat and opportunity alerts while in meetings, on the move
- Acts on recommendations immediately — shares insights, escalates threats
- Tolerance for latency: medium (accepts 5–10 s for an agent analysis)
- Technical level: non-technical; wants cards and plain-language summaries

### Persona B — Analyst (secondary)
- Sits down with the phone for deeper work 1–2× per week
- Opens weekly Strategy briefs in OfficeKit, edits and shares them
- Wants exportable reports and drillable data
- Technical level: moderate; comfortable with filters and settings

---

## 3. Goals and Non-Goals

### Goals
- Surface competitor threats, customer sentiment shifts, and buying signals in near-real time
- Run four specialised AI agents on a schedule without human intervention
- Provide a Flutter dashboard with real-time alerts and per-agent drill-down
- Generate weekly strategy briefs as .docx files openable in OfficeKit
- Operate fully offline using Ollama + Phi-3-mini in Termux

### Non-Goals
- Cloud sync or multi-device support
- Multi-user or team collaboration
- Web application (mobile-only for now)
- Paid data sources or API subscriptions at launch

---

## 4. Feature Requirements

### 4.1 Marketing AI Agent

**Purpose:** Monitor competitor advertising, brand campaigns, and industry trend signals.

| # | Requirement | Priority |
|---|---|---|
| M1 | Fetch and parse RSS feeds from industry news sources (configurable list) | Must |
| M2 | Scrape Google Trends for tracked keywords every 2 hours | Must |
| M3 | Monitor Meta Ad Library public search for competitor brand names | Should |
| M4 | Detect new campaigns by comparing current vs. previous snapshots | Must |
| M5 | Classify each finding as Threat / Opportunity / Neutral using Ollama | Must |
| M6 | Store findings with timestamp, source, classification, and summary | Must |
| M7 | Trigger a real-time alert when a finding is classified as high-severity Threat | Must |

**Acceptance Criteria:**
- Agent runs every 2 hours via APScheduler without manual trigger
- Each run produces at least one DB record (even if empty-result sentinel)
- Alert fires within 30 s of a high-severity finding being written

### 4.2 Product AI Agent

**Purpose:** Analyse customer voice — reviews, feature requests, and sentiment trends.

| # | Requirement | Priority |
|---|---|---|
| P1 | Scrape Google Play Store reviews for tracked app IDs every 4 hours | Must |
| P2 | Monitor r/[industry] subreddits and Hacker News for product mentions | Should |
| P3 | Extract feature requests from review text using Ollama prompt | Must |
| P4 | Aggregate sentiment score (−1 to +1) per app per run | Must |
| P5 | Detect sentiment inflection points (≥0.2 delta from 7-day average) | Must |
| P6 | Cluster recurring feature requests into themes | Should |
| P7 | Emit alert on significant negative sentiment spike | Must |

**Acceptance Criteria:**
- Sentiment score present on every agent run record
- Feature request clusters update on each run
- Inflection point alert fires within 30 s of detection

### 4.3 Sales AI Agent

**Purpose:** Detect buying signals, lead opportunities, and intent data proxies.

| # | Requirement | Priority |
|---|---|---|
| S1 | Parse publicly available job postings (Indeed RSS, LinkedIn public feeds) for tracked company names every 6 hours | Must |
| S2 | Detect hiring signals that indicate budget expansion or new initiatives | Must |
| S3 | Monitor company blog RSS feeds for product announcements | Must |
| S4 | Score each signal as buying intent (High / Medium / Low) using Ollama | Must |
| S5 | Surface top-5 leads per run by intent score | Must |
| S6 | Track signal history per company over 90-day rolling window | Should |

**Acceptance Criteria:**
- Intent score present on every signal record
- Top-5 lead list available via API within 10 s of agent completing
- 90-day history queryable per company

### 4.4 Strategy AI Agent

**Purpose:** Synthesise findings from all three agents into a weekly strategic brief.

| # | Requirement | Priority |
|---|---|---|
| ST1 | Run every Sunday at 08:00 local time | Must |
| ST2 | Pull last 7 days of records from Marketing, Product, and Sales agents | Must |
| ST3 | Build a structured prompt and call Ollama to draft the brief | Must |
| ST4 | Brief sections: Executive Summary, Top Threats, Top Opportunities, Recommended Actions, Metrics | Must |
| ST5 | Export brief as .docx using python-docx | Must |
| ST6 | Notify the Flutter app that a new brief is available | Must |
| ST7 | Retain last 12 weekly briefs on device | Should |

**Acceptance Criteria:**
- Brief .docx generated every Sunday, openable in OfficeKit
- All four sections present and non-empty
- Brief delivered to Flutter notification within 60 s of generation completing

---

## 5. Dashboard Requirements

### 5.1 Unified Feed (Home Screen)

- Chronological feed of all agent findings, newest first
- Each card shows: agent icon, classification badge, summary text, timestamp
- Swipe-to-dismiss for low-priority items
- Pull-to-refresh triggers a manual agent run
- Real-time updates via polling every 30 s (or WebSocket push if feasible)

### 5.2 Alert Banner

- Persistent banner at top of screen when a high-severity Threat is active
- Tap to drill into the full finding
- Dismiss button (persists dismissal to DB)

### 5.3 Per-Agent Screens

Each of the four agents has a dedicated drill-down screen:

| Screen | Key data shown |
|---|---|
| Marketing | Trend chart, campaign snapshot diff, top competitor moves |
| Product | Sentiment timeline chart, feature request clusters, review samples |
| Sales | Lead score table, hiring signal timeline, top opportunities |
| Strategy | List of weekly briefs, preview of latest brief, export button |

### 5.4 Settings Screen

- Add/remove tracked keywords, competitor names, app IDs, RSS feeds
- Manual trigger per agent
- Model selector (Ollama models available on device)
- Brief export directory path

---

## 6. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Performance | Agent analysis < 30 s per Ollama call on iQOO hardware (Phi-3-mini) |
| Memory | Backend process < 1.5 GB RAM at steady state; Flutter app < 200 MB |
| Storage | SQLite DB < 500 MB after 90 days of data |
| Offline | All core features work with no internet; data collection gracefully skips when offline |
| Privacy | No telemetry, no cloud calls, all data stays on device |
| Battery | Agents run at staggered intervals; no background wake locks between runs |
| Reliability | APScheduler jobs restart on crash; last-run timestamp written before job starts |

---

## 7. Data Retention

| Data type | Retention period |
|---|---|
| Raw scraped text | 30 days |
| Processed insights | 90 days |
| Sentiment time-series | 180 days |
| Weekly briefs (.docx) | 12 weeks (rolling) |
| Alert records | 90 days |

---

## 8. Out of Scope (v1)

- Authenticated API integrations (Twitter/X API, LinkedIn API, etc.)
- Push notifications via FCM (local only)
- Machine learning model fine-tuning on device
- Competitor paid ad spend estimation
- CRM integration
- iPad / tablet layout

---

## 9. Success Metrics

| Metric | Target |
|---|---|
| Agents running on schedule | 100% of scheduled runs complete within ±5 min |
| Alert latency | < 30 s from finding creation to banner display |
| Weekly brief quality | User rates brief useful ≥ 4/5 in in-app survey |
| Battery impact | < 5% additional drain per day from background agents |
