import asyncio
import json
import logging
import xml.etree.ElementTree as ET

import httpx
from bs4 import BeautifulSoup

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a sales intelligence analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """Analyse this business signal and return a JSON object with exactly these fields:
{{
  "summary": "one-sentence summary",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "intent_score": "high|medium|low",
  "score": 0.0,
  "company": "company name or unknown",
  "signal_type": "hiring|announcement|funding|other",
  "key_points": ["point1"]
}}
score is buying intent probability 0.0-1.0.

Source: {source_type}
Company context: {company}
Content: {content}"""


class SalesAgent(BaseAgent):
    agent_name = "sales"

    async def fetch_sources(self) -> list[dict]:
        items = []
        items.extend(await self._fetch_indeed())
        items.extend(await self._fetch_blogs())
        items.extend(await self._fetch_linkedin())
        return items

    async def _fetch_indeed(self) -> list[dict]:
        companies_raw = self._get_setting("sales_companies", "")
        if not companies_raw:
            return []
        companies = [c.strip() for c in companies_raw.split(",") if c.strip()]
        items = []
        async with httpx.AsyncClient(timeout=30, headers={"User-Agent": "SalesBot/1.0"}) as client:
            for company in companies:
                try:
                    url = f"https://www.indeed.com/rss?q={company}&l="
                    resp = await client.get(url)
                    resp.raise_for_status()
                    for item in self._parse_rss_items(resp.text, source_type="indeed", company=company):
                        items.append(item)
                except httpx.ConnectError:
                    logger.warning("sales: cannot connect to Indeed for %s, skipping", company)
                except Exception as exc:
                    logger.warning("sales: Indeed fetch failed for %s: %s", company, exc)
        return items

    async def _fetch_blogs(self) -> list[dict]:
        feeds_raw = self._get_setting("sales_blog_feeds", "")
        if not feeds_raw:
            return []
        feeds = [f.strip() for f in feeds_raw.split(",") if f.strip()]
        items = []
        async with httpx.AsyncClient(timeout=30, headers={"User-Agent": "SalesBot/1.0"}) as client:
            for url in feeds:
                try:
                    resp = await client.get(url)
                    resp.raise_for_status()
                    for item in self._parse_rss_items(resp.text, source_type="blog", company=""):
                        items.append(item)
                except httpx.ConnectError:
                    logger.warning("sales: cannot connect to blog feed %s, skipping", url)
                except Exception as exc:
                    logger.warning("sales: blog feed failed %s: %s", url, exc)
        return items

    async def _fetch_linkedin(self) -> list[dict]:
        companies_raw = self._get_setting("sales_companies", "")
        if not companies_raw:
            return []
        companies = [c.strip() for c in companies_raw.split(",") if c.strip()]
        items = []
        async with httpx.AsyncClient(
            timeout=30,
            headers={
                "User-Agent": "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36",
            },
            follow_redirects=True,
        ) as client:
            for company in companies:
                try:
                    url = f"https://www.linkedin.com/jobs/search?keywords={company}&location="
                    resp = await client.get(url)
                    soup = BeautifulSoup(resp.text, "html.parser")
                    for card in soup.select("li.result-card")[:5]:
                        title_el = card.select_one("h3.result-card__title")
                        desc_el = card.select_one("p.result-card__snippet")
                        title = title_el.get_text(strip=True) if title_el else ""
                        desc = desc_el.get_text(strip=True) if desc_el else ""
                        if title:
                            items.append({
                                "source_type": "linkedin",
                                "company": company,
                                "content": f"{title}. {desc}",
                                "title": title,
                                "source": url,
                            })
                except httpx.ConnectError:
                    logger.warning("sales: cannot connect to LinkedIn for %s, skipping", company)
                except Exception as exc:
                    logger.warning("sales: LinkedIn scrape failed for %s: %s", company, exc)
                # rate limit: 1 request per 10 s per company
                await asyncio.sleep(10)
        return items

    def _parse_rss_items(self, xml_text: str, source_type: str, company: str) -> list[dict]:
        items = []
        try:
            root = ET.fromstring(xml_text)
            channel = root.find("channel")
            entries = channel.findall("item") if channel is not None else []
            for entry in entries[:10]:
                def _text(tag):
                    el = entry.find(tag)
                    return el.text.strip() if el is not None and el.text else ""

                title = _text("title")
                link = _text("link")
                description = _text("description")[:800]
                if title or description:
                    items.append({
                        "source_type": source_type,
                        "company": company,
                        "content": f"{title}. {description}",
                        "title": title,
                        "source": link,
                    })
        except ET.ParseError as exc:
            logger.warning("sales: RSS parse error: %s", exc)
        return items

    async def analyse(self, item: dict) -> dict:
        user_msg = USER_PROMPT_TEMPLATE.format(
            source_type=item.get("source_type", "unknown"),
            company=item.get("company", "unknown"),
            content=item.get("content", item.get("title", "")),
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
            "source": item.get("source", ""),
            "raw_text": item.get("content", ""),
            "metadata": json.dumps({
                "intent_score": result.get("intent_score", "low"),
                "company": result.get("company", item.get("company", "")),
                "signal_type": result.get("signal_type", "other"),
                "source_type": item.get("source_type", ""),
            }),
        }

    async def run(self):
        # delegate full fetch→analyse→store loop to base, then annotate top-5 leads
        await super().run()
        self._annotate_top_leads()

    def _annotate_top_leads(self):
        from backend.db.database import SessionLocal
        from backend.db.models import AgentRun, Insight

        db = SessionLocal()
        try:
            last_run = (
                db.query(AgentRun)
                .filter(AgentRun.agent == "sales", AgentRun.status == "success")
                .order_by(AgentRun.finished_at.desc())
                .first()
            )
            if last_run is None:
                return

            insights = (
                db.query(Insight)
                .filter(Insight.agent == "sales", Insight.run_id == last_run.id)
                .order_by(Insight.score.desc())
                .limit(5)
                .all()
            )

            top_leads = []
            for ins in insights:
                meta = {}
                try:
                    meta = json.loads(ins.metadata or "{}")
                except Exception:
                    pass
                top_leads.append({
                    "id": ins.id,
                    "company": meta.get("company", ""),
                    "signal_type": meta.get("signal_type", ""),
                    "intent_score": meta.get("intent_score", "low"),
                    "score": ins.score,
                    "summary": ins.summary,
                })

            if insights:
                first = insights[0]
                existing_meta = {}
                try:
                    existing_meta = json.loads(first.metadata or "{}")
                except Exception:
                    pass
                existing_meta["top_leads"] = top_leads
                first.metadata = json.dumps(existing_meta)
                db.commit()
        finally:
            db.close()
