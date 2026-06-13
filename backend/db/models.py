from datetime import datetime
from sqlalchemy import Column, Integer, Text, Float, DateTime, Date, ForeignKey, Index
from backend.db.database import Base


class Settings(Base):
    __tablename__ = "settings"

    key   = Column(Text, primary_key=True)
    value = Column(Text, nullable=True)


class Insight(Base):
    __tablename__ = "insights"

    id = Column(Integer, primary_key=True, autoincrement=True)
    agent = Column(Text, nullable=False)
    run_id = Column(Integer, ForeignKey("agent_runs.id"), nullable=False)
    source = Column(Text, nullable=False)
    raw_text = Column(Text, nullable=True)
    summary = Column(Text, nullable=False)
    category = Column(Text, nullable=False)   # 'threat'|'opportunity'|'neutral'
    severity = Column(Text, nullable=False)   # 'high'|'medium'|'low'
    score = Column(Float, nullable=True)
    extra_data = Column(Text, nullable=True)  # JSON blob (metadata reserved by SQLAlchemy)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)


class AgentRun(Base):
    __tablename__ = "agent_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    agent = Column(Text, nullable=False)
    started_at = Column(DateTime, nullable=False)
    finished_at = Column(DateTime, nullable=True)
    status = Column(Text, nullable=False)     # 'running'|'success'|'failed'
    findings = Column(Integer, default=0)
    error = Column(Text, nullable=True)


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    insight_id = Column(Integer, ForeignKey("insights.id"), nullable=True)
    title = Column(Text, nullable=False)
    body = Column(Text, nullable=False)
    dismissed = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class Brief(Base):
    __tablename__ = "briefs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    week_start = Column(Date, nullable=False)
    file_path = Column(Text, nullable=False)
    summary = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


Index("idx_insights_agent_created", Insight.agent, Insight.created_at.desc())
Index("idx_alerts_dismissed", Alert.dismissed, Alert.created_at.desc())
Index("idx_agent_runs_agent", AgentRun.agent, AgentRun.started_at.desc())


class Competitor(Base):
    __tablename__ = "competitors"

    id          = Column(Integer, primary_key=True, autoincrement=True)
    name        = Column(Text, nullable=False)
    website     = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    type        = Column(Text, nullable=False)   # 'direct'|'indirect'|'emerging'
    active      = Column(Integer, default=1)     # 1=active, 0=archived
    created_at  = Column(DateTime, default=datetime.utcnow)


Index("idx_competitors_active", Competitor.active, Competitor.created_at.desc())
