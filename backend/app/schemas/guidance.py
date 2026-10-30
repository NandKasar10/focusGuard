from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class GuidanceContext(BaseModel):
    app_name: str
    session_minutes: int = 0
    daily_total_minutes: int = 0
    active_window_title: Optional[str] = None
    study_goals: Optional[str] = None
    video_length_seconds: Optional[int] = None
    video_watched_seconds: Optional[int] = None


class GuidanceResponse(BaseModel):
    suggestion_id: int
    app_name: str
    is_distracting: bool
    activity_description: str
    suggestion_text: str
    suggested_action: str  # "close_now", "snooze", "allow"
    follow_up_minutes: Optional[int] = 40
    timestamp: datetime


class ReplyRequest(BaseModel):
    user_reply: str = Field(..., description="'followed', 'snoozed', 'ignored', or custom text")
    action_taken_after: Optional[str] = Field(None, description="'closed_app', 'continued_watching', etc.")
    follow_up_minutes: Optional[int] = None
    custom_reminder_message: Optional[str] = None


class SuggestionOut(BaseModel):
    id: int
    user_id: int
    app_name: str
    timestamp: datetime
    context_summary: Optional[str]
    suggestion_text: str
    user_reply: Optional[str]
    action_taken_after: str
    follow_up_time: Optional[datetime]

    class Config:
        from_attributes = True
