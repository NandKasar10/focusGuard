from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base


class Suggestion(Base):
    __tablename__ = "suggestions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    app_name = Column(String(100), nullable=False)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    context_summary = Column(Text, nullable=True)
    suggestion_text = Column(Text, nullable=False)
    user_reply = Column(String(50), nullable=True)  # followed, snoozed, ignored, or custom string
    action_taken_after = Column(String(50), default="pending", nullable=False)  # closed_app, continued_watching, pending
    follow_up_time = Column(DateTime, nullable=True)

    user = relationship("User", back_populates="suggestions")
    reminders = relationship("Reminder", back_populates="suggestion", cascade="all, delete-orphan")
