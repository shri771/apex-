import json
from datetime import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session
from sqlalchemy import func
from backend.db.database import get_db
from backend.db.models import Insight, Alert

router = APIRouter(prefix="/insights", tags=["insights"])


# ---------------------------------------------------------------------------
# Pydantic response schema — maps extra_data → metadata for Flutter client
# ---------------------------------------------------------------------------

class InsightOut(BaseModel):
    id: int
    agent: str
    run_id: int
    source: str
    raw_text: Optional[str] = None
    summary: str
    category: str
    severity: str
    score: Optional[float] = None
    metadata: Optional[dict] = None   # Flutter reads this field name
    created_at: datetime
    expires_at: Optional[datetime] = None

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_row(cls, row: Insight) -> "InsightOut":
        meta = None
        if row.extra_data:
            try:
                meta = json.loads(row.extra_data)
            except Exception:
                meta = None
        return cls(
            id=row.id,
            agent=row.agent,
            run_id=row.run_id,
            source=row.source,
            raw_text=row.raw_text,
            summary=row.summary,
            category=row.category,
            severity=row.severity,
            score=row.score,
            metadata=meta,
            created_at=row.created_at,
            expires_at=row.expires_at,
        )


class SnapshotOut(BaseModel):
    threats: int
    opportunities: int
    buying_signals: int
    competitors_tracked: int
    top_recommendation: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("", response_model=List[InsightOut])
def list_insights(
    agent: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    since: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(Insight)
    if agent:
        q = q.filter(Insight.agent == agent)
    if category:
        q = q.filter(Insight.category == category)
    if severity:
        q = q.filter(Insight.severity == severity)
    if since:
        q = q.filter(Insight.created_at >= since)
    rows = q.order_by(Insight.created_at.desc()).limit(limit).all()
    return [InsightOut.from_orm_row(r) for r in rows]


@router.get("/snapshot", response_model=SnapshotOut)
def get_snapshot(db: Session = Depends(get_db)):
    """Aggregated executive market snapshot for the dashboard card."""

    threats = db.query(func.count(Insight.id)).filter(
        Insight.category == "threat"
    ).scalar() or 0

    opportunities = db.query(func.count(Insight.id)).filter(
        Insight.category == "opportunity"
    ).scalar() or 0

    # Buying signals = sales insights with non-null score > 0.5
    buying_signals = db.query(func.count(Insight.id)).filter(
        Insight.agent == "sales",
        Insight.score > 0.5,
    ).scalar() or 0

    # Competitors tracked = distinct non-empty source domains across all insights
    all_sources = db.query(Insight.source).filter(Insight.source != "").all()
    competitor_domains: set[str] = set()
    for (src,) in all_sources:
        try:
            from urllib.parse import urlparse
            host = urlparse(src).netloc
            if host:
                competitor_domains.add(host)
        except Exception:
            pass
    competitors_tracked = max(len(competitor_domains), 0)

    # Top recommendation — pull from most recent strategy insight's metadata
    top_rec = "Review the latest market intelligence data."
    strategy_row = (
        db.query(Insight)
        .filter(Insight.agent == "strategy")
        .order_by(Insight.created_at.desc())
        .first()
    )
    if strategy_row and strategy_row.extra_data:
        try:
            meta = json.loads(strategy_row.extra_data)
            rec = meta.get("top_recommendation", "")
            if rec:
                top_rec = rec
            elif meta.get("recommended_actions"):
                top_rec = meta["recommended_actions"][0].get("action", top_rec)
        except Exception:
            pass

    return SnapshotOut(
        threats=threats,
        opportunities=opportunities,
        buying_signals=buying_signals,
        competitors_tracked=competitors_tracked,
        top_recommendation=top_rec,
    )


@router.get("/{insight_id}", response_model=InsightOut)
def get_insight(insight_id: int, db: Session = Depends(get_db)):
    row = db.get(Insight, insight_id)
    if not row:
        raise HTTPException(status_code=404, detail="Insight not found")
    return InsightOut.from_orm_row(row)
