import asyncio
import logging

logger = logging.getLogger(__name__)


async def run_full_pipeline():
    """
    Run all 6 market intelligence agents in dependency order.

    Stage 0 — CompetitorDiscovery must finish before Stage 1 CIA reads competitors table.
    Stage 1 — Parallel I/O; Ollama semaphore serializes LLM inference automatically.
    Stage 2 — Synthesis agents read Stage 1 insights from DB.
    """
    from backend.agents.competitor_discovery import CompetitorDiscoveryAgent
    from backend.agents.market_trends import MarketTrendsAgent
    from backend.agents.competitor_intelligence import CompetitorIntelligenceAgent
    from backend.agents.demand_lead_signals import DemandLeadSignalsAgent
    from backend.agents.strategy import StrategyAgent
    from backend.agents.alerts_agent import AlertsAgent

    logger.info("pipeline: Stage 0 — CompetitorDiscovery")
    try:
        await CompetitorDiscoveryAgent().run()
    except Exception as exc:
        logger.error("pipeline: Stage 0 failed: %s — continuing", exc)

    logger.info("pipeline: Stage 1 — MarketTrends + CompetitorIntelligence + DemandLeadSignals (parallel)")
    stage1_results = await asyncio.gather(
        MarketTrendsAgent().run(),
        CompetitorIntelligenceAgent().run(),
        DemandLeadSignalsAgent().run(),
        return_exceptions=True,
    )
    for i, result in enumerate(stage1_results):
        if isinstance(result, Exception):
            names = ["market_trends", "competitor_intelligence", "demand_lead_signals"]
            logger.error("pipeline: Stage 1 agent %s failed: %s", names[i], result)

    logger.info("pipeline: Stage 2 — Strategy + Alerts (parallel)")
    stage2_results = await asyncio.gather(
        StrategyAgent().run(),
        AlertsAgent().run(),
        return_exceptions=True,
    )
    for i, result in enumerate(stage2_results):
        if isinstance(result, Exception):
            names = ["strategy", "alerts_agent"]
            logger.error("pipeline: Stage 2 agent %s failed: %s", names[i], result)

    logger.info("pipeline: full pipeline complete")
