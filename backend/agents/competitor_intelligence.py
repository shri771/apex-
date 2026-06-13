import asyncio
import json
import logging
import xml.etree.ElementTree as ET

import httpx
from bs4 import BeautifulSoup

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a competitive intelligence analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """You are a Competitor Intelligence Agent for a startup/SMB.

Analyse the information below about a competitor and return a competitive assessment.

Return ONLY a JSON object with these exact fields:
{{
  "summary": "one-sentence summary of competitor's current state and strategy",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "strategic_focus": "what this competitor is currently investing in / pushing toward",
  "threat_signals": ["signal1", "signal2"],
  "counter_move": "one recommended counter-move for our startup",
  "key_points": ["point1", "point2"]
}}

severity: high=actively expanding into our space, medium=adjacent threat, low=stable/declining.
score: buying threat probability 0.0-1.0.
threat_signals: specific evidence of threat (e.g. "hired 5 ML engineers", "dropped pricing 20%").

Competitor: {name} ({type})
Website: {website}

Scraped Data:
{raw_text}"""


class CompetitorIntelligenceAgent(BaseAgent):
    agent_name = "competitor_intelligence"

    async def fetch_sources(self) -> list[dict]:
        from backend.db.database import SessionLocal
        from backend.db.models import Competitor

        db = SessionLocal()
        try:
            competitors = db.query(Competitor).filter(Competitor.active == 1).all()
            competitor_data = [
                {"id": c.id, "name": c.name, "website": c.website or "", "type": c.type}
                for c in competitors
            ]
        finally:
            db.close()

        if not competitor_data:
            logger.warning("competitor_intelligence: no active competitors found — run competitor_discovery first")
            return []

        indeed_base = self._get_setting("competitor_job_boards", "")

        items = []
        for comp in competitor_data:
            item = await self._fetch_competitor(comp, indeed_base)
            items.append(item)
        return items

    async def _fetch_competitor(self, comp: dict, indeed_base: str) -> dict:
        name = comp["name"]
        website = comp["website"]

        async with httpx.AsyncClient(
            timeout=20,
            headers={"User-Agent": "CompetitorBot/1.0"},
            follow_redirects=True,
        ) as client:
            homepage_task = self._scrape_homepage(client, website)
            jobs_task = self._fetch_jobs(client, name, indeed_base)
            press_task = self._fetch_press(client, name)

            homepage_text, jobs_text, press_text = await asyncio.gather(
                homepage_task, jobs_task, press_task, return_exceptions=True
            )

        homepage_text = homepage_text if isinstance(homepage_text, str) else ""
        jobs_text = jobs_text if isinstance(jobs_text, str) else ""
        press_text = press_text if isinstance(press_text, str) else ""

        raw_text = (
            f"HOMEPAGE:\n{homepage_text[:1000]}\n\n"
            f"JOB POSTINGS:\n{jobs_text[:800]}\n\n"
            f"PRESS MENTIONS:\n{press_text[:600]}"
        )

        return {
            "competitor_id": comp["id"],
            "competitor_name": name,
            "competitor_type": comp["type"],
            "website": website,
            "source": website or name,
            "raw_text": raw_text,
        }

    async def _scrape_homepage(self, client: httpx.AsyncClient, url: str) -> str:
        if not url:
            return ""
        try:
            resp = await client.get(url)
            soup = BeautifulSoup(resp.text, "html.parser")
            for tag in soup(["script", "style", "nav", "footer"]):
                tag.decompose()
            return soup.get_text(separator=" ", strip=True)[:1500]
        except Exception as exc:
            logger.warning("competitor_intelligence: homepage scrape failed for %s: %s", url, exc)
            return ""

    async def _fetch_jobs(self, client: httpx.AsyncClient, company: str, base_url: str) -> str:
        url = base_url or f"https://www.indeed.com/rss?q={company}&l="
        try:
            resp = await client.get(url)
            resp.raise_for_status()
            root = ET.fromstring(resp.text)
            channel = root.find("channel")
            entries = channel.findall("item") if channel is not None else []
            titles = []
            for entry in entries[:8]:
                el = entry.find("title")
                if el is not None and el.text:
                    titles.append(el.text.strip())
            return "\n".join(titles)
        except Exception as exc:
            logger.warning("competitor_intelligence: jobs fetch failed for %s: %s", company, exc)
            return ""

    async def _fetch_press(self, client: httpx.AsyncClient, company: str) -> str:
        try:
            url = f"https://hn.algolia.com/api/v1/search?query={company}&tags=story&hitsPerPage=5"
            resp = await client.get(url)
            resp.raise_for_status()
            hits = resp.json().get("hits", [])
            lines = [h.get("title", "") for h in hits if h.get("title")]
            return "\n".join(lines)
        except Exception as exc:
            logger.warning("competitor_intelligence: press fetch failed for %s: %s", company, exc)
            return ""

    async def analyse(self, item: dict) -> dict:
        model = self._get_setting("ollama_model", "phi3:mini")

        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(
                name=item.get("competitor_name", ""),
                type=item.get("competitor_type", "direct"),
                website=item.get("website", ""),
                raw_text=item.get("raw_text", ""),
            ),
            timeout=60,
        )

        return {
            "summary": result.get("summary", f"Intelligence report for {item.get('competitor_name', '')}"),
            "category": result.get("category", "neutral"),
            "severity": result.get("severity", "low"),
            "score": float(result.get("score", 0.5)),
            "key_points": result.get("key_points", []),
            "source": item.get("source", ""),
            "raw_text": item.get("raw_text", ""),
            "metadata": json.dumps({
                "competitor_id": item.get("competitor_id"),
                "competitor_name": item.get("competitor_name", ""),
                "competitor_type": item.get("competitor_type", ""),
                "strategic_focus": result.get("strategic_focus", ""),
                "threat_signals": result.get("threat_signals", []),
                "counter_move": result.get("counter_move", ""),
            }),
        }
