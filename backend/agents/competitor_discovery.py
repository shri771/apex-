import json
import logging

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "You are a competitive intelligence analyst. "
    "Your only job is to return a clean list of competitors. "
    "Respond only with valid JSON."
)

USER_PROMPT_TEMPLATE = """You are a Competitor Discovery Agent. Given the business description below, identify competitors.

If competitors are not explicitly named, infer the competitive landscape:
- Find direct competitors (same product, same customer)
- Find indirect competitors (different product, same customer budget)
- Find emerging competitors (startups in the space)

For each competitor confirm they are currently active and serve a meaningfully overlapping customer.
Remove duplicates and rank by relevance (most direct threat first).

Return ONLY a JSON object in this exact format (minimum 5 competitors if market is large enough):
{{
  "competitors": [
    {{
      "name": "Company Name",
      "website": "https://example.com",
      "description": "One-line description of what they do",
      "type": "direct|indirect|emerging"
    }}
  ]
}}

Business Description:
{description}"""


class CompetitorDiscoveryAgent(BaseAgent):
    agent_name = "competitor_discovery"

    async def fetch_sources(self) -> list[dict]:
        description = self._get_setting("user_business_description", "")
        if not description:
            logger.warning("competitor_discovery: user_business_description setting is empty — skipping")
            return []
        return [{"source": "settings:user_business_description", "raw_text": description}]

    async def analyse(self, item: dict) -> dict:
        model = self._get_setting("ollama_model", "phi3:mini")
        description = item.get("raw_text", "")

        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(description=description),
            timeout=90,
        )

        competitors = result.get("competitors", [])
        if not isinstance(competitors, list):
            competitors = []

        # Upsert each competitor into the DB as a side effect
        self._upsert_competitors(competitors)

        n = len(competitors)
        return {
            "summary": f"Discovered {n} competitor{'s' if n != 1 else ''} for your business",
            "category": "neutral",
            "severity": "low",
            "score": 0.5,
            "key_points": [c.get("name", "") for c in competitors if c.get("name")],
            "source": "settings:user_business_description",
            "raw_text": description,
            "metadata": json.dumps({"competitors_found": n, "competitors": competitors}),
        }

    def _upsert_competitors(self, competitors: list[dict]) -> None:
        from backend.db.database import SessionLocal
        from backend.db.models import Competitor

        db = SessionLocal()
        try:
            for c in competitors:
                name = (c.get("name") or "").strip()
                if not name:
                    continue
                existing = (
                    db.query(Competitor)
                    .filter(Competitor.name.ilike(name))
                    .first()
                )
                if existing:
                    existing.website = c.get("website") or existing.website
                    existing.description = c.get("description") or existing.description
                    existing.type = c.get("type") or existing.type
                    existing.active = 1
                else:
                    db.add(Competitor(
                        name=name,
                        website=c.get("website", ""),
                        description=c.get("description", ""),
                        type=c.get("type", "direct"),
                    ))
            db.commit()
            logger.info("competitor_discovery: upserted %d competitors", len(competitors))
        except Exception as exc:
            logger.error("competitor_discovery: failed to upsert competitors: %s", exc)
            db.rollback()
        finally:
            db.close()
