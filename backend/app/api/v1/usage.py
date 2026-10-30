from datetime import datetime, timezone
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.tracked_app import TrackedApp
from app.models.usage_log import UsageLog
from app.models.user import User
from app.schemas.usage import UsageSyncRequest, UsageSyncResponse

router = APIRouter(prefix="/usage", tags=["usage"])


@router.post("/sync", response_model=UsageSyncResponse)
def sync_usage_data(
    req: UsageSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    synced_count = 0

    for rec in req.records:
        # Resolve or create tracked app record for user
        tracked_app = (
            db.query(TrackedApp)
            .filter(TrackedApp.user_id == current_user.id, TrackedApp.app_name.ilike(rec.app_name))
            .first()
        )
        if not tracked_app:
            tracked_app = TrackedApp(
                user_id=current_user.id,
                app_name=rec.app_name,
                package_or_process=rec.app_name.lower(),
                match_pattern=f"*{rec.app_name}*",
                is_active=True,
            )
            db.add(tracked_app)
            db.flush()

        # Find existing log for (user_id, app_id, date)
        usage_log = (
            db.query(UsageLog)
            .filter(
                UsageLog.user_id == current_user.id,
                UsageLog.app_id == tracked_app.id,
                UsageLog.date == rec.date,
            )
            .first()
        )

        if usage_log:
            usage_log.total_minutes = rec.total_minutes
            usage_log.session_count = rec.session_count
            usage_log.synced_at = datetime.now(timezone.utc)
        else:
            usage_log = UsageLog(
                user_id=current_user.id,
                app_id=tracked_app.id,
                date=rec.date,
                total_minutes=rec.total_minutes,
                session_count=rec.session_count,
                synced_at=datetime.now(timezone.utc),
            )
            db.add(usage_log)

        synced_count += 1

    db.commit()
    return UsageSyncResponse(
        success=True,
        synced_records=synced_count,
        message=f"Successfully synced {synced_count} usage records.",
    )

