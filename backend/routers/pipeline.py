from fastapi import APIRouter, BackgroundTasks

router = APIRouter(prefix="/pipeline", tags=["pipeline"])


@router.post("/run")
async def trigger_pipeline(background_tasks: BackgroundTasks):
    from backend.pipeline import run_full_pipeline
    background_tasks.add_task(run_full_pipeline)
    return {"status": "triggered", "pipeline": "full"}
