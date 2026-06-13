import pytz
from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler(timezone=pytz.utc)

AGENT_NAMES = {"marketing", "product", "sales", "strategy"}


def _make_stub(name: str):
    async def stub_run():
        raise RuntimeError(f"{name} agent not yet implemented")
    stub_run.__name__ = f"{name}_stub_run"
    return stub_run


def setup_scheduler() -> AsyncIOScheduler:
    try:
        from backend.agents.marketing import MarketingAgent
        marketing_run = MarketingAgent().run
    except ImportError:
        marketing_run = _make_stub("marketing")

    try:
        from backend.agents.product import ProductAgent
        product_run = ProductAgent().run
    except ImportError:
        product_run = _make_stub("product")

    try:
        from backend.agents.sales import SalesAgent
        sales_run = SalesAgent().run
    except ImportError:
        sales_run = _make_stub("sales")

    try:
        from backend.agents.strategy import StrategyAgent
        strategy_run = StrategyAgent().run
    except ImportError:
        strategy_run = _make_stub("strategy")

    scheduler.add_job(
        marketing_run, "interval", hours=2,
        id="marketing", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        product_run, "interval", hours=4,
        id="product", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        sales_run, "interval", hours=6,
        id="sales", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        strategy_run, "cron", day_of_week="sun", hour=8,
        id="strategy", misfire_grace_time=300, replace_existing=True,
    )

    return scheduler


def get_scheduler() -> AsyncIOScheduler:
    return scheduler
