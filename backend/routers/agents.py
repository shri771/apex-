from fastapi import APIRouter, BackgroundTasks, HTTPException
from sqlalchemy.orm import Session
from backend.db.database import SessionLocal
from backend.db.models import AgentRun
from backend.scheduler import get_scheduler, AGENT_NAMES

router = APIRouter(prefix="/agents", tags=["agents"])


def _last_run(db: Session, agent: str):
    return (
        db.query(AgentRun)
        .filter(AgentRun.agent == agent)
        .order_by(AgentRun.started_at.desc())
        .first()
    )


@router.get("/status")
def agents_status():
    sched = get_scheduler()
    result = {}
    with SessionLocal() as db:
        for name in AGENT_NAMES:
            run = _last_run(db, name)
            job = sched.get_job(name)
            next_run = job.next_run_time.isoformat() if job and job.next_run_time else None
            result[name] = {
                "last_run": {
                    "id": run.id,
                    "started_at": run.started_at.isoformat(),
                    "finished_at": run.finished_at.isoformat() if run.finished_at else None,
                    "status": run.status,
                    "findings": run.findings,
                } if run else None,
                "next_run": next_run,
            }
    return result


async def _trigger_agent(name: str):
    try:
        if name == "marketing":
            from backend.agents.marketing import MarketingAgent
            await MarketingAgent().run()
        elif name == "product":
            from backend.agents.product import ProductAgent
            await ProductAgent().run()
        elif name == "sales":
            from backend.agents.sales import SalesAgent
            await SalesAgent().run()
        elif name == "strategy":
            from backend.agents.strategy import StrategyAgent
            await StrategyAgent().run()
    except ImportError:
        pass  # agent not yet implemented — silently skip


@router.post("/{name}/run")
async def trigger_agent(name: str, background_tasks: BackgroundTasks):
    if name not in AGENT_NAMES:
        raise HTTPException(status_code=404, detail=f"Unknown agent: {name}")
    background_tasks.add_task(_trigger_agent, name)
    return {"status": "triggered", "agent": name}
