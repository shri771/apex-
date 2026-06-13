import json
import logging

import httpx

from .base import BaseAgent

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = "You are a demand generation and lead scoring analyst. Respond only with valid JSON."

USER_PROMPT_TEMPLATE = """You are a Demand and Lead Signal Agent for a startup/SMB.

Analyse the content below and determine if it represents a demand or lead signal for the product described.

Return ONLY a JSON object with these exact fields:
{{
  "summary": "one-sentence summary of the signal and its relevance",
  "category": "opportunity|neutral|threat",
  "severity": "high|medium|low",
  "score": 0.0,
  "urgency": "hot|warm|cold",
  "company_mentioned": "company or person name, or 'unknown'",
  "outreach_angle": "one-line suggested outreach message angle",
  "signal_type": "pain_point|funding|icp_match|technographic|other",
  "key_points": ["point1", "point2"]
}}

urgency: hot=needs solution now, warm=actively researching, cold=future interest.
score: buying intent probability 0.0-1.0.
severity: high if hot lead, medium if warm, low if cold/noise.

Product: {product_description}
ICP Keywords: {icp_keywords}

Source type: {source_type}
Keyword that surfaced this: {keyword}

Content:
{content}"""


class DemandLeadSignalsAgent(BaseAgent):
    agent_name = "demand_lead_signals"

    async def fetch_sources(self) -> list[dict]:
        product_desc = self._get_setting("user_product_description", "")
        icp_raw = self._get_setting("user_icp_keywords", "")

        if not product_desc and not icp_raw:
            logger.warning("demand_lead_signals: user_product_description and user_icp_keywords are both empty — skipping")
            return []

        keywords = [k.strip() for k in icp_raw.split(",") if k.strip()]
        if not keywords and product_desc:
            # fall back to using product description itself as a single keyword
            keywords = [product_desc[:80]]

        items = []
        async with httpx.AsyncClient(
            timeout=30,
            headers={"User-Agent": "LeadBot/1.0"},
            follow_redirects=True,
        ) as client:
            for kw in keywords[:5]:  # cap at 5 keywords to limit total requests
                reddit_items = await self._fetch_reddit(client, kw, product_desc, icp_raw)
                hn_pain_items = await self._fetch_hn_pain(client, kw, product_desc, icp_raw)
                hn_funding_items = await self._fetch_hn_funding(client, kw, product_desc, icp_raw)
                items.extend(reddit_items)
                items.extend(hn_pain_items)
                items.extend(hn_funding_items)

        return items

    async def _fetch_reddit(self, client: httpx.AsyncClient, kw: str, product_desc: str, icp_raw: str) -> list[dict]:
        items = []
        try:
            url = f"https://www.reddit.com/r/all/search.json?q={kw}&sort=new&limit=10&t=week"
            resp = await client.get(url)
            resp.raise_for_status()
            children = resp.json().get("data", {}).get("children", [])
            for child in children:
                post = child.get("data", {})
                content = (post.get("selftext") or post.get("title", ""))[:800]
                if content:
                    items.append({
                        "source_type": "reddit",
                        "source": f"https://reddit.com{post.get('permalink', '')}",
                        "raw_text": content,
                        "keyword": kw,
                        "product_description": product_desc,
                        "icp_keywords": icp_raw,
                    })
        except httpx.ConnectError:
            logger.warning("demand_lead_signals: cannot connect to Reddit, skipping kw=%s", kw)
        except Exception as exc:
            logger.warning("demand_lead_signals: Reddit fetch failed for kw=%s: %s", kw, exc)
        return items

    async def _fetch_hn_pain(self, client: httpx.AsyncClient, kw: str, product_desc: str, icp_raw: str) -> list[dict]:
        items = []
        try:
            url = f"https://hn.algolia.com/api/v1/search?query={kw}&tags=ask_hn,show_hn&hitsPerPage=5"
            resp = await client.get(url)
            resp.raise_for_status()
            for hit in resp.json().get("hits", []):
                content = hit.get("story_text") or hit.get("title", "")
                if content:
                    items.append({
                        "source_type": "hn_pain",
                        "source": hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID')}",
                        "raw_text": content[:800],
                        "keyword": kw,
                        "product_description": product_desc,
                        "icp_keywords": icp_raw,
                    })
        except Exception as exc:
            logger.warning("demand_lead_signals: HN pain fetch failed for kw=%s: %s", kw, exc)
        return items

    async def _fetch_hn_funding(self, client: httpx.AsyncClient, kw: str, product_desc: str, icp_raw: str) -> list[dict]:
        items = []
        try:
            url = f"https://hn.algolia.com/api/v1/search?query={kw}+funding&tags=story&hitsPerPage=5"
            resp = await client.get(url)
            resp.raise_for_status()
            for hit in resp.json().get("hits", []):
                content = hit.get("story_text") or hit.get("title", "")
                if content:
                    items.append({
                        "source_type": "hn_funding",
                        "source": hit.get("url") or f"https://news.ycombinator.com/item?id={hit.get('objectID')}",
                        "raw_text": content[:800],
                        "keyword": kw,
                        "product_description": product_desc,
                        "icp_keywords": icp_raw,
                    })
        except Exception as exc:
            logger.warning("demand_lead_signals: HN funding fetch failed for kw=%s: %s", kw, exc)
        return items

    async def analyse(self, item: dict) -> dict:
        model = self._get_setting("ollama_model", "phi3:mini")

        result = await self.ollama_client.generate(
            model=model,
            system=SYSTEM_PROMPT,
            user=USER_PROMPT_TEMPLATE.format(
                product_description=item.get("product_description", ""),
                icp_keywords=item.get("icp_keywords", ""),
                source_type=item.get("source_type", "unknown"),
                keyword=item.get("keyword", ""),
                content=item.get("raw_text", ""),
            ),
            timeout=60,
        )

        return {
            "summary": result.get("summary", ""),
            "category": result.get("category", "neutral"),
            "severity": result.get("severity", "low"),
            "score": float(result.get("score", 0.0)),
            "key_points": result.get("key_points", []),
            "source": item.get("source", ""),
            "raw_text": item.get("raw_text", ""),
            "metadata": json.dumps({
                "urgency": result.get("urgency", "cold"),
                "company_mentioned": result.get("company_mentioned", "unknown"),
                "outreach_angle": result.get("outreach_angle", ""),
                "signal_type": result.get("signal_type", "other"),
                "source_type": item.get("source_type", ""),
                "keyword": item.get("keyword", ""),
            }),
        }
