from datetime import date, datetime
from typing import List, Optional, Dict
from pydantic import BaseModel
from app.schemas.guidance import SuggestionOut


class AppUsageStat(BaseModel):
    app_name: str
    total_minutes: int
    session_count: int


class DailySummaryOut(BaseModel):
    date: date
    total_screen_time_minutes: int
    total_distracting_time_minutes: int
    app_breakdown: List[AppUsageStat]
    suggestions_count: int
    followed_count: int
    ignored_count: int
    snoozed_count: int
    compliance_percentage: float
    focus_streak_days: int
    timeline: List[SuggestionOut]
    summary_message: str
