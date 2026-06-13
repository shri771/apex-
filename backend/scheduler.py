import pytz
from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler(timezone=pytz.utc)

AGENT_NAMES = {
    "marketing", "product", "sales", "strategy",
    "competitor_discovery", "market_trends", "competitor_intelligence",
    "demand_lead_signals", "alerts_agent",
}


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

    try:
        from backend.agents.competitor_discovery import CompetitorDiscoveryAgent
        competitor_discovery_run = CompetitorDiscoveryAgent().run
    except ImportError:
        competitor_discovery_run = _make_stub("competitor_discovery")

    try:
        from backend.agents.market_trends import MarketTrendsAgent
        market_trends_run = MarketTrendsAgent().run
    except ImportError:
        market_trends_run = _make_stub("market_trends")

    try:
        from backend.agents.competitor_intelligence import CompetitorIntelligenceAgent
        competitor_intelligence_run = CompetitorIntelligenceAgent().run
    except ImportError:
        competitor_intelligence_run = _make_stub("competitor_intelligence")

    try:
        from backend.agents.demand_lead_signals import DemandLeadSignalsAgent
        demand_lead_signals_run = DemandLeadSignalsAgent().run
    except ImportError:
        demand_lead_signals_run = _make_stub("demand_lead_signals")

    try:
        from backend.agents.alerts_agent import AlertsAgent
        alerts_agent_run = AlertsAgent().run
    except ImportError:
        alerts_agent_run = _make_stub("alerts_agent")

    try:
        from backend.pipeline import run_full_pipeline
        pipeline_run = run_full_pipeline
    except ImportError:
        pipeline_run = _make_stub("full_pipeline")

    scheduler.add_job(
        competitor_discovery_run, "cron", hour=6,
        id="competitor_discovery", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        market_trends_run, "interval", hours=6,
        id="market_trends", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        competitor_intelligence_run, "interval", hours=12,
        id="competitor_intelligence", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        demand_lead_signals_run, "interval", hours=8,
        id="demand_lead_signals", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        alerts_agent_run, "interval", hours=6,
        id="alerts_agent", misfire_grace_time=300, replace_existing=True,
    )
    scheduler.add_job(
        pipeline_run, "cron", hour=7,
        id="full_pipeline", misfire_grace_time=300, replace_existing=True,
    )

    return scheduler


def get_scheduler() -> AsyncIOScheduler:
    return scheduler
