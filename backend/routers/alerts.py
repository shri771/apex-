from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Alert

router = APIRouter(prefix="/alerts", tags=["alerts"])


class AlertOut(BaseModel):
    id: int
    insight_id: Optional[int] = None
    title: str
    body: str
    dismissed: int
    created_at: datetime

    model_config = {"from_attributes": True}


@router.get("", response_model=list[AlertOut])
def list_alerts(db: Session = Depends(get_db)):
    rows = (
        db.query(Alert)
        .filter(Alert.dismissed == 0)
        .order_by(Alert.created_at.desc())
        .all()
    )
    return rows


@router.post("/{alert_id}/dismiss")
def dismiss_alert(alert_id: int, db: Session = Depends(get_db)):
    alert = db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.dismissed = 1
    db.commit()
    return {"status": "dismissed", "id": alert_id}
