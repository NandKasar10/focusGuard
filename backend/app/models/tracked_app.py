from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base


class TrackedApp(Base):
    __tablename__ = "tracked_apps"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    app_name = Column(String(100), nullable=False)
    package_or_process = Column(String(255), nullable=False)
    match_pattern = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="tracked_apps")
    limits = relationship("Limit", back_populates="tracked_app", cascade="all, delete-orphan")
    usage_logs = relationship("UsageLog", back_populates="tracked_app", cascade="all, delete-orphan")
