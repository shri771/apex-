from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from backend.db.database import SessionLocal
from backend.db.models import AgentRun, Insight, Alert
from backend import llm


SYSTEM_PROMPT = (
    "You are a market intelligence analyst. Respond only with valid JSON."
)

USER_PROMPT_TEMPLATE = (
    'Analyse this content and return: '
    '{{"summary": "...", "category": "threat|opportunity|neutral", '
    '"severity": "high|medium|low", "score": 0.0, "key_points": [...]}}\n\n'
    "Content: {raw_text}"
)

DEFAULT_MODEL = "phi3:mini"
RAW_TEXT_RETENTION_DAYS = 30
INSIGHT_RETENTION_DAYS = 90


class BaseAgent(ABC):
    def __init__(self, name: str, model: str = DEFAULT_MODEL):
        self.name = name
        self.model = model

    @abstractmethod
    async def fetch_sources(self) -> list[dict]:
        """Return list of raw items: each must have 'source' and 'raw_text' keys."""

    @abstractmethod
    async def analyse(self, item: dict) -> dict:
        """Analyse a raw item and return an insight dict."""

    async def _default_analyse(self, item: dict) -> dict:
        result = await llm.ollama_client.generate(
            model=self.model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(raw_text=item.get("raw_text", "")),
        )
        result["source"] = item.get("source", "")
        result["raw_text"] = item.get("raw_text", "")
        return result

    def store(self, insight: dict, run_id: int) -> Insight:
        now = datetime.utcnow()
        expires_at = now + timedelta(days=INSIGHT_RETENTION_DAYS)

        row = Insight(
            agent=self.name,
            run_id=run_id,
            source=insight.get("source", ""),
            raw_text=insight.get("raw_text"),
            summary=insight.get("summary", ""),
            category=insight.get("category", "neutral"),
            severity=insight.get("severity", "low"),
            score=insight.get("score"),
            extra_data=insight.get("metadata"),
            expires_at=expires_at,
        )

        with SessionLocal() as db:
            db.add(row)
            db.flush()
            db.refresh(row)
            insight_id = row.id

            if row.severity == "high" and row.category == "threat":
                alert = Alert(
                    insight_id=insight_id,
                    title=f"[{self.name.upper()}] High-severity threat detected",
                    body=row.summary,
                )
                db.add(alert)

            db.commit()
            db.refresh(row)

        return row

    async def run(self):
        now = datetime.utcnow()

        with SessionLocal() as db:
            run = AgentRun(
                agent=self.name,
                started_at=now,
                status="running",
            )
            db.add(run)
            db.commit()
            db.refresh(run)
            run_id = run.id

        findings_count = 0
        error_msg = None

        try:
            items = await self.fetch_sources()
            for item in items:
                insight = await self.analyse(item)
                self.store(insight, run_id)
                findings_count += 1
            status = "success"
        except Exception as exc:
            status = "failed"
            error_msg = str(exc)
            raise
        finally:
            with SessionLocal() as db:
                run_row = db.get(AgentRun, run_id)
                if run_row:
                    run_row.finished_at = datetime.utcnow()
                    run_row.status = status
                    run_row.findings = findings_count
                    run_row.error = error_msg
                    db.commit()
