import os
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from backend.db.database import get_db
from backend.db.models import Brief

router = APIRouter(prefix="/briefs", tags=["briefs"])


@router.get("")
def list_briefs(db: Session = Depends(get_db)):
    return db.query(Brief).order_by(Brief.week_start.desc()).all()


@router.get("/{brief_id}/download")
def download_brief(brief_id: int, db: Session = Depends(get_db)):
    brief = db.get(Brief, brief_id)
    if not brief:
        raise HTTPException(status_code=404, detail="Brief not found")
    if not os.path.isfile(brief.file_path):
        raise HTTPException(status_code=404, detail="Brief file not found on disk")
    filename = os.path.basename(brief.file_path)
    return FileResponse(
        path=brief.file_path,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=filename,
    )
