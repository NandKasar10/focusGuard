from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.limit import Limit
from app.models.reminder import Reminder
from app.models.suggestion import Suggestion
from app.models.tracked_app import TrackedApp
from app.models.usage_log import UsageLog
from app.models.user import User
from app.schemas.settings import LimitSchema, SettingsOut, SettingsUpdate, TrackedAppSchema

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=SettingsOut)
def get_settings(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    tracked_apps = db.query(TrackedApp).filter(TrackedApp.user_id == current_user.id).all()
    limits = db.query(Limit).filter(Limit.user_id == current_user.id).all()

    return SettingsOut(
        user_id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        has_video=current_user.has_video,
        study_goals=current_user.study_goals,
        screenshot_consent=current_user.screenshot_consent,
        tracked_apps=[TrackedAppSchema.model_validate(app) for app in tracked_apps],
        limits=[LimitSchema.model_validate(lim) for lim in limits],
    )


@router.put("", response_model=SettingsOut)
def update_settings(
    req: SettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.study_goals is not None:
        current_user.study_goals = req.study_goals
    if req.screenshot_consent is not None:
        current_user.screenshot_consent = req.screenshot_consent
    if req.has_video is not None:
        current_user.has_video = req.has_video

    # Update tracked apps if provided
    if req.tracked_apps is not None:
        # Clear existing and replace with user-provided list
        db.query(TrackedApp).filter(TrackedApp.user_id == current_user.id).delete()
        for app in req.tracked_apps:
            new_app = TrackedApp(
                user_id=current_user.id,
                app_name=app.app_name,
                package_or_process=app.package_or_process,
                match_pattern=app.match_pattern,
                is_active=app.is_active,
            )
            db.add(new_app)

    # Update limits if provided
    if req.limits is not None:
        db.query(Limit).filter(Limit.user_id == current_user.id).delete()
        for lim in req.limits:
            new_lim = Limit(
                user_id=current_user.id,
                app_id=lim.app_id,
                daily_limit_minutes=lim.daily_limit_minutes,
                continuous_session_limit_minutes=lim.continuous_session_limit_minutes,
            )
            db.add(new_lim)

    db.commit()
    db.refresh(current_user)

    tracked_apps = db.query(TrackedApp).filter(TrackedApp.user_id == current_user.id).all()
    limits = db.query(Limit).filter(Limit.user_id == current_user.id).all()

    return SettingsOut(
        user_id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        has_video=current_user.has_video,
        study_goals=current_user.study_goals,
        screenshot_consent=current_user.screenshot_consent,
        tracked_apps=[TrackedAppSchema.model_validate(app) for app in tracked_apps],
        limits=[LimitSchema.model_validate(lim) for lim in limits],
    )


@router.delete("/data", status_code=status.HTTP_200_OK)
def delete_all_user_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Privacy-first: Allows the user to wipe all their usage logs, suggestions,
    reminders, and preferences from the server anytime.
    """
    db.query(UsageLog).filter(UsageLog.user_id == current_user.id).delete()
    db.query(Reminder).filter(Reminder.user_id == current_user.id).delete()
    db.query(Suggestion).filter(Suggestion.user_id == current_user.id).delete()
    db.query(Limit).filter(Limit.user_id == current_user.id).delete()
    current_user.has_video = False
    current_user.screenshot_consent = False
    db.commit()
    return {"success": True, "message": "All user data and telemetry successfully deleted."}

