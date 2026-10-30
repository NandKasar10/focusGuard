from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.limit import Limit
from app.models.tracked_app import TrackedApp
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


DEFAULT_APPS = [
    {"name": "YouTube", "proc": "chrome.exe,msedge.exe,com.google.android.youtube", "pattern": "*YouTube*"},
    {"name": "Instagram", "proc": "chrome.exe,msedge.exe,com.instagram.android", "pattern": "*Instagram*"},
    {"name": "Facebook", "proc": "chrome.exe,msedge.exe,com.facebook.katana", "pattern": "*Facebook*"},
]


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == req.email.lower()).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists."
        )

    user = User(
        name=req.name,
        email=req.email.lower(),
        password_hash=hash_password(req.password),
        study_goals=req.study_goals or "Crack exams, focus on meaningful work",
        has_video=False,
        screenshot_consent=False,
    )
    db.add(user)
    db.flush()

    # Seed default tracked apps for the new user
    for app_data in DEFAULT_APPS:
        tracked_app = TrackedApp(
            user_id=user.id,
            app_name=app_data["name"],
            package_or_process=app_data["proc"],
            match_pattern=app_data["pattern"],
            is_active=True,
        )
        db.add(tracked_app)

    # Seed default combined limit of 60 minutes
    default_limit = Limit(
        user_id=user.id,
        app_id=None,  # Combined limit
        daily_limit_minutes=60,
        continuous_session_limit_minutes=30,
    )
    db.add(default_limit)
    db.commit()
    db.refresh(user)

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email.lower()).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token_endpoint(req: RefreshRequest, db: Session = Depends(get_db)):
    try:
        payload = decode_token(req.refresh_token)
        user_id_str = payload.get("sub")
        token_type = payload.get("type")
        if user_id_str is None or token_type != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token."
            )
        user_id = int(user_id_str)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token."
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found."
        )

    new_access_token = create_access_token(user.id)
    new_refresh_token = create_refresh_token(user.id)
    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
