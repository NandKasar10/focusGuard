from datetime import date, datetime, time, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.suggestion import Suggestion
from app.models.usage_log import UsageLog
from app.models.user import User
from app.schemas.guidance import SuggestionOut
from app.schemas.summary import AppUsageStat, DailySummaryOut

router = APIRouter(prefix="/summary", tags=["summary"])


@router.get("/daily", response_model=DailySummaryOut)
def get_daily_summary(
    target_date: Optional[date] = Query(None, alias="date"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    selected_date = target_date or date.today()
    start_dt = datetime.combine(selected_date, time.min).replace(tzinfo=timezone.utc)
    end_dt = datetime.combine(selected_date, time.max).replace(tzinfo=timezone.utc)

    # 1. Fetch usage logs for that date
    usage_logs = (
        db.query(UsageLog)
        .filter(UsageLog.user_id == current_user.id, UsageLog.date == selected_date)
        .all()
    )

    app_breakdown: List[AppUsageStat] = []
    total_screen_time = 0
    for log in usage_logs:
        app_name = log.tracked_app.app_name if log.tracked_app else "Unknown"
        app_breakdown.append(
            AppUsageStat(
                app_name=app_name,
                total_minutes=log.total_minutes,
                session_count=log.session_count,
            )
        )
        total_screen_time += log.total_minutes

    # 2. Fetch suggestions for that date
    suggestions = (
        db.query(Suggestion)
        .filter(
            Suggestion.user_id == current_user.id,
            Suggestion.timestamp >= start_dt,
            Suggestion.timestamp <= end_dt,
        )
        .order_by(Suggestion.timestamp.asc())
        .all()
    )

    suggestions_count = len(suggestions)
    followed_count = 0
    ignored_count = 0
    snoozed_count = 0

    for s in suggestions:
        reply_lower = (s.user_reply or "").lower()
        action_lower = (s.action_taken_after or "").lower()
        if reply_lower in ["followed", "closed", "study", "okay, i'll study"] or action_lower == "closed_app":
            followed_count += 1
        elif reply_lower in ["snooze", "snoozed"] or action_lower == "snoozed":
            snoozed_count += 1
        elif reply_lower in ["ignore", "ignored"] or action_lower == "continued_watching":
            ignored_count += 1

    compliance = (
        round((followed_count / suggestions_count) * 100, 1)
        if suggestions_count > 0
        else 100.0
    )

    # 3. Calculate focus streak (consecutive days where compliance >= 60% or usage <= limits)
    streak_days = 0
    check_day = selected_date
    for _ in range(30):  # Check up to 30 past days
        day_logs = (
            db.query(UsageLog)
            .filter(UsageLog.user_id == current_user.id, UsageLog.date == check_day)
            .all()
        )
        day_total = sum(l.total_minutes for l in day_logs)
        # If user stayed within reasonable limit (< 90m total distracting time) or had logs
        if day_logs and day_total <= 90:
            streak_days += 1
            check_day = check_day - timedelta(days=1)
        elif not day_logs and check_day == selected_date:
            check_day = check_day - timedelta(days=1)
        else:
            break

    streak_days = max(1, streak_days)

    # Summary notification message in friendly Hinglish
    if compliance >= 80:
        summary_msg = f"Shabash! Aaj {compliance}% guidance follow kiya aur {total_screen_time} min screen time raha. Current streak: {streak_days} din!"
    elif compliance >= 50:
        summary_msg = f"Accha effort! Aaj {suggestions_count} me se {followed_count} baar focus wapas laye. Kal aur behtar karenge!"
    else:
        summary_msg = f"Bhai aaj thoda distraction zyada ho gaya ({total_screen_time} min). Kal subah se nayi shuruat karte hain!"

    return DailySummaryOut(
        date=selected_date,
        total_screen_time_minutes=total_screen_time,
        total_distracting_time_minutes=total_screen_time,
        app_breakdown=app_breakdown,
        suggestions_count=suggestions_count,
        followed_count=followed_count,
        ignored_count=ignored_count,
        snoozed_count=snoozed_count,
        compliance_percentage=compliance,
        focus_streak_days=streak_days,
        timeline=[SuggestionOut.model_validate(s) for s in suggestions],
        summary_message=summary_msg,
    )
