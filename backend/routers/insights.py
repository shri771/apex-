from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Insight

router = APIRouter(prefix="/insights", tags=["insights"])


class InsightCreate(BaseModel):
    agent: str
    run_id: int
    source: str
    summary: str
    category: str
    severity: str
    raw_text: Optional[str] = None
    score: Optional[float] = None
    extra_data: Optional[str] = None


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


@router.post("")
def create_insight(payload: InsightCreate, db: Session = Depends(get_db)):
    row = Insight(**payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/{insight_id}")
def get_insight(insight_id: int, db: Session = Depends(get_db)):
    row = db.get(Insight, insight_id)
    if not row:
        raise HTTPException(status_code=404, detail="Insight not found")
    return row
