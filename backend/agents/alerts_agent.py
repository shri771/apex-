import json
import logging
from datetime import datetime, timedelta

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a real-time market alerts analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """You are a Real-Time Market Alerts Agent for a startup/SMB.

You have been given the last 24 hours of market intelligence findings. Synthesize them into a consolidated alert digest.

Suppress noise — only surface events that materially affect the business. Skip minor blog posts or incremental changes.
Maximum 3 Critical alerts unless all genuinely warrant immediate attention.

Return ONLY a JSON object with these exact fields:
{{
  "summary": "one-sentence digest of the most urgent situation right now",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "critical_count": {critical_count},
  "important_count": {important_count},
  "top_action": "single most important action to take right now",
  "tier_breakdown": {{
    "critical": ["event1", "event2"],
    "watch": ["event3"],
    "fyi": []
  }},
  "key_points": ["point1", "point2"]
}}

severity: high if any Critical alerts, medium if Watch-level alerts, low if FYI only.
score: urgency score 0.0-1.0.

FINDINGS (last 24 hours):
{raw_text}"""


class AlertsAgent(BaseAgent):
    agent_name = "alerts_agent"

    async def fetch_sources(self) -> list[dict]:
        from backend.db.database import SessionLocal
        from backend.db.models import Insight

        threshold = self._get_setting("alert_severity_threshold", "high")
        since = datetime.utcnow() - timedelta(hours=24)

        db = SessionLocal()
        try:
            rows = (
                db.query(Insight)
                .filter(
                    Insight.agent.in_(["market_trends", "competitor_intelligence"]),
                    Insight.created_at >= since,
                )
                .order_by(Insight.severity, Insight.score.desc())
                .all()
            )

            critical = [
                {"summary": r.summary, "agent": r.agent, "source": r.source, "score": r.score}
                for r in rows if r.severity == "high"
            ]
            important = [
                {"summary": r.summary, "agent": r.agent, "source": r.source, "score": r.score}
                for r in rows if r.severity == "medium"
            ]
            informational = [r for r in rows if r.severity == "low"]
        finally:
            db.close()

        payload = json.dumps({
            "critical": critical,
            "important": important,
            "informational_count": len(informational),
        })

        return [{
            "source": "insights_db:last_24h",
            "raw_text": payload,
            "critical_count": len(critical),
            "important_count": len(important),
            "informational_count": len(informational),
            "threshold": threshold,
        }]

    async def analyse(self, item: dict) -> dict:
        critical_count = item.get("critical_count", 0)
        important_count = item.get("important_count", 0)

        if critical_count == 0 and important_count == 0:
            return {
                "summary": "No critical or important alerts in the last 24 hours",
                "category": "neutral",
                "severity": "low",
                "score": 0.0,
                "key_points": [f"{item.get('informational_count', 0)} informational signals processed"],
                "source": item.get("source", ""),
                "raw_text": item.get("raw_text", ""),
                "metadata": json.dumps({
                    "critical_count": 0,
                    "important_count": 0,
                    "informational_count": item.get("informational_count", 0),
                    "top_action": "No immediate action required",
                    "tier_breakdown": {"critical": [], "watch": [], "fyi": []},
                }),
            }

        model = self._get_setting("ollama_model", "phi3:mini")
        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(
                critical_count=critical_count,
                important_count=important_count,
                raw_text=item.get("raw_text", ""),
            ),
            timeout=90,
        )

        severity = "high" if critical_count > 0 else ("medium" if important_count > 0 else "low")

        return {
            "summary": result.get("summary", f"{critical_count} critical, {important_count} important alerts"),
            "category": result.get("category", "neutral"),
            "severity": severity,
            "score": float(result.get("score", min(critical_count / 3.0, 1.0))),
            "key_points": result.get("key_points", []),
            "source": item.get("source", ""),
            "raw_text": item.get("raw_text", ""),
            "metadata": json.dumps({
                "critical_count": critical_count,
                "important_count": important_count,
                "informational_count": item.get("informational_count", 0),
                "top_action": result.get("top_action", ""),
                "tier_breakdown": result.get("tier_breakdown", {}),
            }),
        }
