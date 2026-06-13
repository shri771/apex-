import logging
import xml.etree.ElementTree as ET

import httpx

from .base import BaseAgent

logger = logging.getLogger(__name__)

DEFAULT_FEEDS = [
    "https://techcrunch.com/feed/",
    "https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN",
]

SYSTEM_PROMPT = "You are a market intelligence analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """Analyse this market content and return a JSON object with exactly these fields:
{{
  "summary": "one-sentence summary",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "key_points": ["point1", "point2"]
}}

Title: {title}
Content: {content}"""


class MarketingAgent(BaseAgent):
    agent_name = "marketing"

    async def fetch_sources(self) -> list[dict]:
        feeds = self._get_setting("marketing_feeds", DEFAULT_FEEDS)
        if isinstance(feeds, str):
            import json
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
            # handle both RSS <channel><item> and Atom <entry>
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
        return {
            "summary": result.get("summary", item.get("title", "")),
            "category": result.get("category", "neutral"),
            "severity": result.get("severity", "low"),
            "score": float(result.get("score", 0.5)),
            "key_points": result.get("key_points", []),
            "source": item.get("link", item.get("source_url", "")),
            "raw_text": item.get("description", ""),
            "metadata": None,
        }
