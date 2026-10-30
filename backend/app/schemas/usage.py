from datetime import date
from typing import List
from pydantic import BaseModel, Field


class UsageRecordIn(BaseModel):
    app_name: str
    date: date
    total_minutes: int = Field(..., ge=0)
    session_count: int = Field(1, ge=1)


class UsageSyncRequest(BaseModel):
    records: List[UsageRecordIn]


class UsageSyncResponse(BaseModel):
    success: bool
    synced_records: int
    message: str
