from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class TrackedAppSchema(BaseModel):
    id: Optional[int] = None
    app_name: str = Field(..., max_length=100)
    package_or_process: str = Field(..., max_length=255)
    match_pattern: str = Field(..., max_length=255)
    is_active: bool = True

    class Config:
        from_attributes = True


class LimitSchema(BaseModel):
    id: Optional[int] = None
    app_id: Optional[int] = None  # None for combined daily limit
    daily_limit_minutes: int = Field(60, ge=1, le=1440)
    continuous_session_limit_minutes: Optional[int] = Field(None, ge=1, le=720)

    class Config:
        from_attributes = True


class SettingsOut(BaseModel):
    user_id: int
    name: str
    email: str
    has_video: bool
    study_goals: Optional[str] = None
    screenshot_consent: bool
    tracked_apps: List[TrackedAppSchema]
    limits: List[LimitSchema]

    class Config:
        from_attributes = True


class SettingsUpdate(BaseModel):
    study_goals: Optional[str] = None
    screenshot_consent: Optional[bool] = None
    has_video: Optional[bool] = None
    tracked_apps: Optional[List[TrackedAppSchema]] = None
    limits: Optional[List[LimitSchema]] = None

