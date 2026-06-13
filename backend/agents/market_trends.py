import asyncio
import json
import logging
import xml.etree.ElementTree as ET

import httpx

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a market trend analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """You are a Market Trends Intelligence Agent for a startup/SMB.

Analyse the content below and identify the market trend it represents.

Return ONLY a JSON object with these exact fields:
{{
  "summary": "one-sentence summary of the trend and why it matters to a startup",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "trend_name": "short name for this trend",
  "signal_strength": 7,
  "industry_relevance": 8,
  "key_points": ["point1", "point2"]
}}

signal_strength: 1-10, how strong/widespread is the signal (1=single mention, 10=everywhere).
industry_relevance: 1-10, how relevant to {industry} industry.
score: normalized relevance+momentum score 0.0-1.0.
severity: high if accelerating trend with major impact, medium if emerging, low if fading/minor.

Industry: {industry}
Geography: {geography}

Content:
Title: {title}
{content}"""


class MarketTrendsAgent(BaseAgent):
    agent_name = "market_trends"

    async def fetch_sources(self) -> list[dict]:
        industry = self._get_setting("trends_industry", "technology")
        geography = self._get_setting("trends_geography", "IN")
        extra_raw = self._get_setting("trends_extra_feeds", "")

        feeds = [
            f"https://trends.google.com/trends/trendingsearches/daily/rss?geo={geography}",
            "https://techcrunch.com/feed/",
        ]
        if extra_raw:
            feeds.extend([f.strip() for f in extra_raw.split(",") if f.strip()])

        hn_url = f"https://hn.algolia.com/api/v1/search?query={industry}&tags=story&hitsPerPage=10"

        items = []
        async with httpx.AsyncClient(timeout=30, headers={"User-Agent": "MarketBot/1.0"}) as client:
            tasks = [client.get(url) for url in feeds] + [client.get(hn_url)]
            responses = await asyncio.gather(*tasks, return_exceptions=True)

        for i, resp in enumerate(responses[:-1]):
            url = feeds[i]
            if isinstance(resp, Exception):
                logger.warning("market_trends: fetch failed for %s: %s", url, resp)
                continue
            items.extend(self._parse_rss(resp.text, url, industry, geography)[:5])

        hn_resp = responses[-1]
        if not isinstance(hn_resp, Exception):
            try:
                for hit in hn_resp.json().get("hits", [])[:10]:
                    content = hit.get("story_text") or hit.get("title", "")
                    items.append({
                        "title": hit.get("title", ""),
                        "source": hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID')}",
                        "raw_text": content[:1000],
                        "industry": industry,
                        "geography": geography,
                    })
            except Exception as exc:
                logger.warning("market_trends: HN parse failed: %s", exc)

        return items[:15]

    def _parse_rss(self, xml_text: str, source_url: str, industry: str, geography: str) -> list[dict]:
        items = []
        try:
            root = ET.fromstring(xml_text)
            ns = {"atom": "http://www.w3.org/2005/Atom"}
            channel = root.find("channel")
            entries = channel.findall("item") if channel is not None else root.findall("atom:entry", ns)
            for entry in entries:
                def _text(tag, default=""):
                    el = entry.find(tag)
                    return el.text.strip() if el is not None and el.text else default

                title = _text("title")
                link = _text("link") or _text("atom:link", ns)
                description = _text("description") or _text("atom:summary", ns) or _text("atom:content", ns)

                if title or description:
                    items.append({
                        "title": title,
                        "source": link,
                        "raw_text": description[:1000],
                        "industry": industry,
                        "geography": geography,
                    })
        except ET.ParseError as exc:
            logger.warning("market_trends: XML parse error for %s: %s", source_url, exc)
        return items

    async def analyse(self, item: dict) -> dict:
        model = self._get_setting("ollama_model", "phi3:mini")
        industry = item.get("industry", "technology")
        geography = item.get("geography", "IN")

        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(
                industry=industry,
                geography=geography,
                title=item.get("title", ""),
                content=item.get("raw_text", ""),
            ),
            timeout=60,
        )

        signal_strength = min(max(int(result.get("signal_strength", 5)), 1), 10)
        industry_relevance = min(max(int(result.get("industry_relevance", 5)), 1), 10)
        score = (signal_strength + industry_relevance) / 20.0

        return {
            "summary": result.get("summary", item.get("title", "")),
            "category": result.get("category", "neutral"),
            "severity": result.get("severity", "low"),
            "score": score,
            "key_points": result.get("key_points", []),
            "source": item.get("source", ""),
            "raw_text": item.get("raw_text", ""),
            "metadata": json.dumps({
                "trend_name": result.get("trend_name", ""),
                "signal_strength": signal_strength,
                "industry_relevance": industry_relevance,
                "geography": geography,
            }),
        }
