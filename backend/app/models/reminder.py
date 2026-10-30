from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    suggestion_id = Column(Integer, ForeignKey("suggestions.id", ondelete="CASCADE"), nullable=True, index=True)
    scheduled_time = Column(DateTime, nullable=False, index=True)
    message = Column(Text, nullable=False)
    status = Column(String(20), default="pending", nullable=False)  # pending, triggered, dismissed
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", back_populates="reminders")
    suggestion = relationship("Suggestion", back_populates="reminders")

