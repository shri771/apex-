from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Competitor

router = APIRouter(prefix="/competitors", tags=["competitors"])


@router.get("")
def list_competitors(db: Session = Depends(get_db)):
    return (
        db.query(Competitor)
        .filter(Competitor.active == 1)
        .order_by(Competitor.created_at.desc())
        .all()
    )


@router.get("/{competitor_id}")
def get_competitor(competitor_id: int, db: Session = Depends(get_db)):
    row = db.get(Competitor, competitor_id)
    if not row:
        raise HTTPException(status_code=404, detail="Competitor not found")
    return row


@router.post("/{competitor_id}/archive")
def archive_competitor(competitor_id: int, db: Session = Depends(get_db)):
    row = db.get(Competitor, competitor_id)
    if not row:
        raise HTTPException(status_code=404, detail="Competitor not found")
    row.active = 0
    db.commit()
    return {"status": "archived", "id": competitor_id}
