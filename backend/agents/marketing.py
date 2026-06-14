import json
import logging

import httpx

from .base import BaseAgent

logger = logging.getLogger(__name__)

DEFAULT_FEEDS = [
    "https://techcrunch.com/feed/",
    "https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN",
]

SYSTEM_PROMPT = "You are a competitive market intelligence analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """Analyse this market content for threats and opportunities. Return a JSON object with exactly these fields:
{{
  "summary": "one-sentence summary",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "key_points": ["point1", "point2"],
  "competitor_name": "company name or empty string",
  "threat_score": 50,
  "evidence": ["evidence point 1", "evidence point 2", "evidence point 3"],
  "opportunity_title": "short opportunity title or empty string",
  "opportunity_detail": "detail about market opportunity or empty string",
  "demand_trend_pct": 0
}}

Rules:
- threat_score is integer 0-100 calculated from: mentions volume (30pts), sentiment negativity (30pts), hiring activity (20pts), product launches (20pts)
- evidence must be 2-3 specific factual bullet points proving WHY this is a threat/opportunity
- if competitor_name is empty, set threat_score to 0 and evidence to []
- opportunity_title and opportunity_detail are filled only when category is "opportunity"
- demand_trend_pct is % change in demand (positive means growing), 0 if unknown

Title: {title}
Content: {content}"""


import xml.etree.ElementTree as ET


class MarketingAgent(BaseAgent):
    agent_name = "marketing"

    async def fetch_sources(self) -> list[dict]:
        feeds = self._get_setting("marketing_feeds", DEFAULT_FEEDS)
        if isinstance(feeds, str):
            try:
                feeds = json.loads(feeds)
            except Exception:
                feeds = DEFAULT_FEEDS

        items = []
        async with httpx.AsyncClient(timeout=30) as client:
            for url in feeds:
                try:
                    resp = await client.get(url, headers={"User-Agent": "MarketBot/1.0"})
                    resp.raise_for_status()
                    items.extend(self._parse_rss(resp.text, url))
                except httpx.ConnectError:
                    logger.warning("marketing: cannot connect to %s, skipping", url)
                except Exception as exc:
                    logger.warning("marketing: error fetching %s: %s", url, exc)
        return items

    def _parse_rss(self, xml_text: str, source_url: str) -> list[dict]:
        items = []
        try:
            root = ET.fromstring(xml_text)
            ns = {"atom": "http://www.w3.org/2005/Atom"}
            channel = root.find("channel")
            entries = channel.findall("item") if channel is not None else root.findall("atom:entry", ns)
            for entry in entries[:10]:
                def _text(tag, default=""):
                    el = entry.find(tag)
                    return el.text.strip() if el is not None and el.text else default

                title = _text("title")
                link = _text("link") or _text("atom:link", ns)
                description = _text("description") or _text("atom:summary", ns) or _text("atom:content", ns)
                pub_date = _text("pubDate") or _text("atom:updated", ns)

                if title or description:
                    items.append({
                        "title": title,
                        "link": link,
                        "description": description[:1000],
                        "pub_date": pub_date,
                        "source_url": source_url,
                    })
        except ET.ParseError as exc:
            logger.warning("marketing: XML parse error for %s: %s", source_url, exc)
        return items

    async def analyse(self, item: dict) -> dict:
        user_msg = USER_PROMPT_TEMPLATE.format(
            title=item.get("title", ""),
            content=item.get("description", ""),
        )
        model = self._get_setting("ollama_model", "phi3:mini")
        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=user_msg,
            timeout=60,
        )

        # Build enriched metadata with evidence + threat score
        threat_score = int(result.get("threat_score", 0))
        # Clamp to 0-100
        threat_score = max(0, min(100, threat_score))

        evidence = result.get("evidence", [])
        if not isinstance(evidence, list):
            evidence = []

        competitor_name = result.get("competitor_name", "")
        opportunity_title = result.get("opportunity_title", "")
        opportunity_detail = result.get("opportunity_detail", "")
        demand_trend_pct = int(result.get("demand_trend_pct", 0))

        extra_data = json.dumps({
            "key_points": result.get("key_points", []),
            "competitor_name": competitor_name,
            "threat_score": threat_score,
            "evidence": evidence,
            "opportunity_title": opportunity_title,
            "opportunity_detail": opportunity_detail,
            "demand_trend_pct": demand_trend_pct,
        })

        return {
            "summary": result.get("summary", item.get("title", "")),
            "category": result.get("category", "neutral"),
            "severity": result.get("severity", "low"),
            "score": float(result.get("score", 0.5)),
            "key_points": result.get("key_points", []),
            "source": item.get("link", item.get("source_url", "")),
            "raw_text": item.get("description", ""),
            "metadata": extra_data,
        }
