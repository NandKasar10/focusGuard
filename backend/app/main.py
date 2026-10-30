import time
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import Dict, List
from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api.v1.auth import router as auth_router
from app.api.v1.guidance import router as guidance_router
from app.api.v1.settings import router as settings_router
from app.api.v1.summary import router as summary_router
from app.api.v1.usage import router as usage_router
from app.core.config import settings
from app.core.database import Base, engine
import app.models  # ensure models are registered


# In-memory sliding window rate limiter
class InMemoryRateLimiter:
    def __init__(self, requests_per_minute: int = 120):
        self.requests_per_minute = requests_per_minute
        self.requests: Dict[str, List[float]] = defaultdict(list)

    def is_rate_limited(self, client_ip: str) -> bool:
        now = time.time()
        window_start = now - 60.0
        # Evict timestamps older than 60s
        self.requests[client_ip] = [t for t in self.requests[client_ip] if t > window_start]
        if len(self.requests[client_ip]) >= self.requests_per_minute:
            return True
        self.requests[client_ip].append(now)
        return False


rate_limiter = InMemoryRateLimiter(settings.RATE_LIMIT_PER_MINUTE)


# Initialize DB tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="FocusGuard API - Digital Wellbeing & AI Intervention Engine",
    version="1.0.0",
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Rate Limiting check
def check_rate_limit(request: Request):
    client_ip = request.client.host if request.client else "127.0.0.1"
    if rate_limiter.is_rate_limited(client_ip):
        return JSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={"detail": "Too many requests. Please slow down."},
        )
    return None


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok", "app": settings.PROJECT_NAME, "version": "1.0.0"}


# Mount routes at both /api/v1/ and root / to support all client conventions
for prefix in [settings.API_V1_STR, ""]:
    app.include_router(auth_router, prefix=prefix)
    app.include_router(settings_router, prefix=prefix)
    app.include_router(usage_router, prefix=prefix)
    app.include_router(guidance_router, prefix=prefix)
    app.include_router(summary_router, prefix=prefix)
