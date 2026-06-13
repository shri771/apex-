from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Insight

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("")
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
    return rows


@router.get("/{insight_id}")
def get_insight(insight_id: int, db: Session = Depends(get_db)):
    row = db.get(Insight, insight_id)
    if not row:
        raise HTTPException(status_code=404, detail="Insight not found")
    return row
