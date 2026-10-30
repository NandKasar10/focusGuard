from datetime import datetime, date, timezone
from sqlalchemy import Column, Integer, Date, ForeignKey, DateTime, UniqueConstraint
from sqlalchemy.orm import relationship
from app.core.database import Base


class UsageLog(Base):
    __tablename__ = "usage_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    app_id = Column(Integer, ForeignKey("tracked_apps.id", ondelete="CASCADE"), nullable=False, index=True)
    date = Column(Date, default=date.today, nullable=False, index=True)
    total_minutes = Column(Integer, default=0, nullable=False)
    session_count = Column(Integer, default=0, nullable=False)
    synced_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="usage_logs")
    tracked_app = relationship("TrackedApp", back_populates="usage_logs")

    __table_args__ = (
        UniqueConstraint("user_id", "app_id", "date", name="uq_user_app_date"),
    )

