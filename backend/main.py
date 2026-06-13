from contextlib import asynccontextmanager
from fastapi import FastAPI
from backend.db.database import init_db
from backend.scheduler import setup_scheduler, get_scheduler
from backend.llm.ollama_client import is_available
from backend.routers import insights, alerts, agents, briefs


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    sched = setup_scheduler()
    sched.start()
    yield
    get_scheduler().shutdown(wait=False)


app = FastAPI(
    title="Market Intelligence Backend",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(insights.router)
app.include_router(alerts.router)
app.include_router(agents.router)
app.include_router(briefs.router)


@app.get("/health")
async def health():
    ollama_ok = await is_available()
    return {"status": "ok", "ollama": ollama_ok}
