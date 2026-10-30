from datetime import datetime, timezone
from sqlalchemy import Column, Integer, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base


class Limit(Base):
    __tablename__ = "limits"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    app_id = Column(Integer, ForeignKey("tracked_apps.id", ondelete="CASCADE"), nullable=True, index=True)
    daily_limit_minutes = Column(Integer, default=60, nullable=False)
    continuous_session_limit_minutes = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="limits")
    tracked_app = relationship("TrackedApp", back_populates="limits")
