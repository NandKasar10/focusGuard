from datetime import datetime, timedelta, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session
from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.reminder import Reminder
from app.models.suggestion import Suggestion
from app.models.user import User
from app.schemas.guidance import GuidanceResponse, ReplyRequest, SuggestionOut
from app.services.ai_guidance import ai_guidance_service

router = APIRouter(tags=["guidance"])


@router.post("/guidance", response_model=GuidanceResponse)
async def generate_ai_guidance(
    app_name: str = Form(...),
    session_minutes: int = Form(0),
    daily_total_minutes: int = Form(0),
    active_window_title: Optional[str] = Form(None),
    video_length_seconds: Optional[int] = Form(None),
    video_watched_seconds: Optional[int] = Form(None),
    screenshot: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Receives an optional in-memory screenshot and usage context.
    Calls Gemini Vision to analyze user activity and generate a supportive
    Hinglish nudge.
    IMPORTANT: The screenshot is processed strictly in-memory and discarded
    immediately. It is NEVER written to disk or the database.
    """
    image_bytes = None
    if screenshot:
        image_bytes = await screenshot.read()

    # Call AI Guidance service
    is_distracting, activity_desc, suggestion_text, action, follow_up_mins = (
        await ai_guidance_service.analyze_screenshot_and_guide(
            image_bytes=image_bytes,
            app_name=app_name,
            session_minutes=session_minutes,
            daily_total_minutes=daily_total_minutes,
            active_window_title=active_window_title,
            study_goals=current_user.study_goals,
            video_length_seconds=video_length_seconds,
            video_watched_seconds=video_watched_seconds,
        )
    )

    now = datetime.now(timezone.utc)
    follow_up_time = now + timedelta(minutes=follow_up_mins)

    # Save suggestion record to DB (only metadata and text, NO image)
    suggestion = Suggestion(
        user_id=current_user.id,
        app_name=app_name,
        timestamp=now,
        context_summary=activity_desc,
        suggestion_text=suggestion_text,
        user_reply=None,
        action_taken_after="pending",
        follow_up_time=follow_up_time,
    )
    db.add(suggestion)
    db.commit()
    db.refresh(suggestion)

    return GuidanceResponse(
        suggestion_id=suggestion.id,
        app_name=app_name,
        is_distracting=is_distracting,
        activity_description=activity_desc,
        suggestion_text=suggestion_text,
        suggested_action=action,
        follow_up_minutes=follow_up_mins,
        timestamp=now,
    )


@router.post("/suggestions/{id}/reply", response_model=SuggestionOut)
def record_suggestion_reply(
    id: int,
    req: ReplyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    suggestion = (
        db.query(Suggestion)
        .filter(Suggestion.id == id, Suggestion.user_id == current_user.id)
        .first()
    )
    if not suggestion:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Suggestion not found."
        )

    suggestion.user_reply = req.user_reply
    if req.action_taken_after:
        suggestion.action_taken_after = req.action_taken_after
    else:
        # Default action mapping based on reply
        if req.user_reply.lower() in ["followed", "closed", "study", "okay, i'll study"]:
            suggestion.action_taken_after = "closed_app"
        elif req.user_reply.lower() in ["ignore", "ignored"]:
            suggestion.action_taken_after = "continued_watching"
        elif req.user_reply.lower() in ["snooze", "snoozed"]:
            suggestion.action_taken_after = "snoozed"

    # Schedule reminder if follow up is requested
    follow_up_m = req.follow_up_minutes or 40
    now = datetime.now(timezone.utc)
    scheduled_time = now + timedelta(minutes=follow_up_m)
    suggestion.follow_up_time = scheduled_time

    reminder_msg = req.custom_reminder_message or (
        f"{follow_up_m} min ho gaye! Ab batao kaam hua kya?"
    )

    reminder = Reminder(
        user_id=current_user.id,
        suggestion_id=suggestion.id,
        scheduled_time=scheduled_time,
        message=reminder_msg,
        status="pending",
    )
    db.add(reminder)
    db.commit()
    db.refresh(suggestion)

    return suggestion
