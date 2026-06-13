from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Settings

router = APIRouter(prefix="/settings", tags=["settings"])


class SettingUpsert(BaseModel):
    key: str
    value: str


@router.get("")
def list_settings(db: Session = Depends(get_db)):
    rows = db.query(Settings).all()
    return [{"key": r.key, "value": r.value} for r in rows]


@router.post("")
def upsert_setting(payload: SettingUpsert, db: Session = Depends(get_db)):
    row = db.get(Settings, payload.key)
    if row:
        row.value = payload.value
    else:
        row = Settings(key=payload.key, value=payload.value)
        db.add(row)
    db.commit()
    db.refresh(row)
    return {"key": row.key, "value": row.value}
