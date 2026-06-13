import json
import logging
from datetime import datetime, timedelta

import httpx

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a product sentiment analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """Analyse this customer review or product mention and return a JSON object with exactly these fields:
{{
  "summary": "one-sentence summary",
  "category": "threat|opportunity|neutral",
  "severity": "high|medium|low",
  "score": 0.0,
  "feature_requests": ["feature1"],
  "key_points": ["point1"]
}}
score is sentiment from -1.0 (very negative) to +1.0 (very positive).

Source: {source_type}
Content: {content}"""


class ProductAgent(BaseAgent):
    agent_name = "product"

    async def fetch_sources(self) -> list[dict]:
        items = []
        items.extend(await self._fetch_playstore())
        items.extend(await self._fetch_reddit())
        items.extend(await self._fetch_hn())
        return items

    async def _fetch_playstore(self) -> list[dict]:
        app_ids_raw = self._get_setting("product_app_ids", "")
        if not app_ids_raw:
            return []
        app_ids = [a.strip() for a in app_ids_raw.split(",") if a.strip()]
        items = []
        for app_id in app_ids:
            try:
                from google_play_scraper import reviews  # type: ignore
                result, _ = reviews(app_id, count=20, lang="en", country="us")
                for r in result:
                    items.append({
                        "source_type": "playstore",
                        "content": r.get("content", ""),
                        "title": f"Review for {app_id} ({r.get('score', '?')}/5)",
                        "source": f"https://play.google.com/store/apps/details?id={app_id}",
                    })
            except Exception as exc:
                logger.warning("product: playstore fetch failed for %s: %s", app_id, exc)
        return items

    async def _fetch_reddit(self) -> list[dict]:
        subs_raw = self._get_setting("product_subreddits", "")
        if not subs_raw:
            return []
        subs = [s.strip() for s in subs_raw.split(",") if s.strip()]
        items = []
        async with httpx.AsyncClient(timeout=30, headers={"User-Agent": "ProductBot/1.0"}) as client:
            for sub in subs:
                try:
                    url = f"https://www.reddit.com/r/{sub}/new.json?limit=10"
                    resp = await client.get(url)
                    resp.raise_for_status()
                    data = resp.json()
                    for child in data.get("data", {}).get("children", []):
                        post = child.get("data", {})
                        content = (post.get("selftext") or post.get("title", ""))[:800]
                        if content:
                            items.append({
                                "source_type": "reddit",
                                "content": content,
                                "title": post.get("title", ""),
                                "source": f"https://reddit.com{post.get('permalink', '')}",
                            })
                except httpx.ConnectError:
                    logger.warning("product: cannot connect to reddit r/%s, skipping", sub)
                except Exception as exc:
                    logger.warning("product: reddit fetch failed for r/%s: %s", sub, exc)
        return items

    async def _fetch_hn(self) -> list[dict]:
        keywords_raw = self._get_setting("product_keywords", "")
        if not keywords_raw:
            return []
        keywords = [k.strip() for k in keywords_raw.split(",") if k.strip()]
        items = []
        async with httpx.AsyncClient(timeout=30) as client:
            for kw in keywords:
                try:
                    url = f"https://hn.algolia.com/api/v1/search?query={kw}&tags=story&hitsPerPage=5"
                    resp = await client.get(url)
                    resp.raise_for_status()
                    for hit in resp.json().get("hits", []):
                        content = hit.get("story_text") or hit.get("title", "")
                        items.append({
                            "source_type": "hn",
                            "content": content[:800],
                            "title": hit.get("title", kw),
                            "source": hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID')}",
                        })
                except httpx.ConnectError:
                    logger.warning("product: cannot connect to HN Algolia, skipping %s", kw)
                except Exception as exc:
                    logger.warning("product: HN fetch failed for %s: %s", kw, exc)
        return items

    async def analyse(self, item: dict) -> dict:
        user_msg = USER_PROMPT_TEMPLATE.format(
            source_type=item.get("source_type", "unknown"),
            content=item.get("content", item.get("title", "")),
        )
        model = self._get_setting("ollama_model", "phi3:mini")
        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=user_msg,
            timeout=60,
        )

        new_score = float(result.get("score", 0.0))
        severity = result.get("severity", "low")

        # inflection detection: compare to 7-day average for this source_type
        try:
            avg = self._avg_sentiment(item.get("source_type", ""), days=7)
            if avg is not None and abs(new_score - avg) >= 0.2:
                severity = "high"
        except Exception as exc:
            logger.warning("product: inflection check failed: %s", exc)

        return {
            "summary": result.get("summary", item.get("title", "")),
            "category": result.get("category", "neutral"),
            "severity": severity,
            "score": new_score,
            "key_points": result.get("key_points", []),
            "source": item.get("source", ""),
            "raw_text": item.get("content", ""),
            "metadata": json.dumps({
                "feature_requests": result.get("feature_requests", []),
                "source_type": item.get("source_type", ""),
            }),
        }

    def _avg_sentiment(self, source_type: str, days: int) -> float | None:
        from backend.db.database import SessionLocal
        from backend.db.models import Insight
        from sqlalchemy import func

        since = datetime.utcnow() - timedelta(days=days)
        db = SessionLocal()
        try:
            rows = (
                db.query(func.avg(Insight.score))
                .filter(
                    Insight.agent == "product",
                    Insight.created_at >= since,
                    Insight.metadata.contains(source_type),
                )
                .scalar()
            )
            return float(rows) if rows is not None else None
        finally:
            db.close()
