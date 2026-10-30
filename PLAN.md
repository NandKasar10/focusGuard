# FocusGuard - Implementation Plan (PLAN.md)

## 1. Project Overview & Architecture
FocusGuard is a cross-platform digital-wellbeing MVP (supporting Android & Windows Desktop) designed to curb distracting app usage. When limits are exceeded, it intervenes by playing the user's own pre-recorded motivational video and offering contextual AI-powered guidance (analyzed on the backend via Gemini Vision without storing the screenshot).

### Architecture Overview
```
+-----------------------------------------------------------+
|                   Flutter Client Application               |
|  - Windows: Win32 API Window Detection + Screen Capture   |
|  - Android: UsageStats + Foreground Service + Overlay     |
|  - Local Storage: SQLite (sqflite_common_ffi/sqflite)     |
|  - Video Player: Local app-private motivational video     |
|  - Secure Storage: flutter_secure_storage (JWTs)          |
+-----------------------------+-----------------------------+
                              |
                     REST API (FastAPI)
                              |
+-----------------------------v-----------------------------+
|                     FastAPI Backend                        |
|  - Auth: JWT (Access & Refresh), Passlib/Bcrypt           |
|  - AI Guidance: Gemini Vision (in-memory, no persistence) |
|  - Endpoints: /auth, /settings, /usage, /guidance, etc.   |
|  - SQLAlchemy ORM + Alembic Migrations                    |
+-----------------------------+-----------------------------+
                              |
+-----------------------------v-----------------------------+
|                  PostgreSQL Database                      |
|  Tables: users, tracked_apps, usage_logs, limits,         |
|          suggestions, reminders                           |
+-----------------------------------------------------------+
```

---

## 2. Technology Stack & Key Dependencies

### Backend:
- **Framework**: FastAPI (Python 3.10+)
- **ORM & Migrations**: SQLAlchemy 2.0 + Alembic + asyncpg / psycopg2
- **Database**: PostgreSQL 16 (via Docker Compose)
- **Security & Auth**: `python-jose` (or `pyjwt`), `passlib[bcrypt]` / `bcrypt`
- **AI Integration**: Google Generative AI (`google-genai` / `google-generativeai`)
- **Testing**: `pytest`, `httpx`

### Frontend (Flutter Client):
- **Platforms**: Windows Desktop (`windows`) & Android (`android`)
- **State Management & DI**: Provider / Riverpod or Bloc
- **Local DB**: `sqflite` + `sqflite_common_ffi` (for Windows desktop SQLite support)
- **Secure Storage**: `flutter_secure_storage`
- **Video Playback**: `video_player` (with Windows support via `video_player_win` or `media_kit`)
- **Camera / File Pickers**: `image_picker` / `file_selector`
- **Screen Capture / Monitoring**:
  - Windows: Win32 FFI bindings (`win32` package or direct user32/gdi32 calls) for active window title/process & desktop screen capture.
  - Android: Platform channels for `UsageStatsManager`, overlay permission (`Settings.ACTION_MANAGE_OVERLAY_PERMISSION`), and MediaProjection screen capture.
- **Local Notifications**: `flutter_local_notifications`

---

## 3. Database Schema Design (PostgreSQL)

1. **`users`**:
   - `id`: UUID / Integer PK
   - `name`: VARCHAR(100)
   - `email`: VARCHAR(255) UNIQUE NOT NULL
   - `password_hash`: VARCHAR(255) NOT NULL
   - `has_video`: BOOLEAN DEFAULT FALSE (metadata only; video is stored locally)
   - `study_goals`: TEXT NULL
   - `screenshot_consent`: BOOLEAN DEFAULT FALSE
   - `created_at`: TIMESTAMP WITH TIME ZONE
   - `updated_at`: TIMESTAMP WITH TIME ZONE

2. **`tracked_apps`**:
   - `id`: UUID / Integer PK
   - `user_id`: FK -> users.id
   - `app_name`: VARCHAR(100) (e.g., "YouTube", "Instagram", "Facebook")
   - `package_or_process`: VARCHAR(255) (e.g., "chrome.exe", "msedge.exe", "com.google.android.youtube")
   - `match_pattern`: VARCHAR(255) (e.g., "*YouTube*", "*Instagram*")
   - `is_active`: BOOLEAN DEFAULT TRUE
   - `created_at`: TIMESTAMP WITH TIME ZONE

3. **`limits`**:
   - `id`: UUID / Integer PK
   - `user_id`: FK -> users.id
   - `app_id`: FK -> tracked_apps.id (NULL if combined/global daily limit)
   - `daily_limit_minutes`: INTEGER DEFAULT 60
   - `continuous_session_limit_minutes`: INTEGER NULL
   - `created_at`: TIMESTAMP WITH TIME ZONE

4. **`usage_logs`**:
   - `id`: UUID / Integer PK
   - `user_id`: FK -> users.id
   - `app_id`: FK -> tracked_apps.id
   - `date`: DATE NOT NULL
   - `total_minutes`: INTEGER DEFAULT 0
   - `session_count`: INTEGER DEFAULT 0
   - `synced_at`: TIMESTAMP WITH TIME ZONE

5. **`suggestions`**:
   - `id`: UUID / Integer PK
   - `user_id`: FK -> users.id
   - `app_name`: VARCHAR(100)
   - `timestamp`: TIMESTAMP WITH TIME ZONE DEFAULT NOW
   - `context_summary`: TEXT (e.g., "Watching 1h YouTube video for 25m at 11:30 PM")
   - `suggestion_text`: TEXT (Hinglish friendly intervention)
   - `user_reply`: VARCHAR(50) (e.g., "followed", "snoozed", "ignored", "custom")
   - `action_taken_after`: VARCHAR(50) (e.g., "closed_app", "continued_watching", "pending")
   - `follow_up_time`: TIMESTAMP WITH TIME ZONE NULL

6. **`reminders`**:
   - `id`: UUID / Integer PK
   - `user_id`: FK -> users.id
   - `suggestion_id`: FK -> suggestions.id NULL
   - `scheduled_time`: TIMESTAMP WITH TIME ZONE NOT NULL
   - `message`: TEXT NOT NULL
   - `status`: VARCHAR(20) DEFAULT 'pending' ("pending", "triggered", "dismissed")
   - `created_at`: TIMESTAMP WITH TIME ZONE

---

## 4. API Endpoints Specification

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Register user with email, name, password |
| `POST` | `/api/v1/auth/login` | Login user, return access_token & refresh_token |
| `POST` | `/api/v1/auth/refresh` | Issue new access token from refresh token |
| `GET` | `/api/v1/settings` | Get user settings (limits, tracked apps, consent) |
| `PUT` | `/api/v1/settings` | Update settings, tracked apps, study goals, consent |
| `POST` | `/api/v1/usage/sync` | Sync daily usage summaries from client |
| `POST` | `/api/v1/guidance` | Upload in-memory screenshot + context -> returns AI Hinglish suggestion |
| `POST` | `/api/v1/suggestions/{id}/reply` | Record user reply & update follow-up action |
| `GET` | `/api/v1/summary/daily` | Get timeline of suggestions, stats, and focus streak |

---

## 5. Client Implementation (Flutter)

### A. Windows Desktop Integration
- **Window Detection**: Use Win32 API (`GetForegroundWindow`, `GetWindowTextW`, `GetWindowThreadProcessId`, `QueryFullProcessImageNameW`) to inspect the active foreground window title every 2-3 seconds.
- Detect browser tab titles (e.g., "YouTube - Google Chrome", "Instagram - Edge") and desktop application processes.
- **Screen Capture**: Use desktop screen capture (Win32 GDI/bitblt or desktop_capturer) to take an in-memory JPEG/PNG screenshot when intervention triggers and user consent is active.
- **Motivational Video**: Play user's pre-recorded video stored in `getApplicationDocumentsDirectory()`.

### B. Android Integration
- **Usage Tracking**: Android `UsageStatsManager` / Accessibility Service & Foreground Service channel.
- **Permissions Onboarding**:
  1. Usage Access (`PACKAGE_USAGE_STATS`)
  2. Overlay Permission (`SYSTEM_ALERT_WINDOW`)
  3. Notification Permission (`POST_NOTIFICATIONS`)
  4. MediaProjection / Screen capture consent dialog.
- **Motivational Overlay**: Full-screen modal or overlay activity that auto-plays the local motivational video.

### C. Testing & Simulation Mode
- "Simulate Usage" Debug Panel:
  - Add 15m / 30m / 60m to any tracked app.
  - Instantly trigger Limit Reached flow.
  - Test AI guidance with sample or real screenshot.
  - Test reply choices ("Okay, I'll study", "Snooze 10 min", "Ignore") and scheduled reminder.

---

## 6. Phased Step-by-Step Implementation

- **Phase 1: Project Setup & Environment**
  - Verify docker, python, flutter tools.
  - Setup `/backend` with FastAPI, SQLAlchemy, Alembic, Docker Compose for Postgres.
  - Setup `/app` Flutter project configured for Windows and Android.

- **Phase 2: Database Models & Alembic Migrations**
  - Implement models, migration scripts, and initial migration run.

- **Phase 3: Backend Authentication & Core Services**
  - JWT utilities, password hashing, auth router (`/register`, `/login`, `/refresh`).
  - Unit tests for auth flow.

- **Phase 4: AI Guidance Engine & Core APIs**
  - Gemini Vision client with structured prompt for Hinglish friendly advice.
  - Temporary in-memory processing: screenshot is analyzed and discarded immediately.
  - Implement `/guidance`, `/usage/sync`, `/settings`, `/suggestions/{id}/reply`, `/summary/daily`.
  - Tests for API endpoints.

- **Phase 5: Flutter Client Setup & Architecture**
  - Setup state management, routing, SQLite database with `sqflite` + `sqflite_common_ffi`.
  - Secure storage wrapper, API client with JWT refresh interceptor.

- **Phase 6: Auth & Onboarding UI**
  - Register, Login, Consent & Permissions onboarding screens.
  - Video recording/picking and saving strictly to app-private directory.

- **Phase 7: Usage Monitoring & Trigger Logic**
  - Windows active window detector background timer.
  - Android usage detection and permission handling.
  - Local SQLite tracking of per-app sessions and daily totals.
  - Trigger logic when limits are crossed.

- **Phase 8: Motivational Overlay & AI Guidance Flow**
  - Fullscreen intervention dialog / overlay auto-playing local video.
  - Capture screen -> call backend `/guidance` -> display Hinglish suggestion card.
  - Action buttons: "Okay, I'll study" (followed), "Snooze 10 min" (snooze), "Ignore" (ignore).
  - Schedule local notification reminder if snooze/follow-up chosen.
  - Post-intervention tracking (detect if user actually closed distracting window within 2 min).

- **Phase 9: Daily Summary & Focus Analytics**
  - Daily timeline view of triggers, user replies, and actions.
  - Stats: total screen time, focus streak, % suggestions followed.
  - Debug "Simulate Usage" toolbar for rapid evaluation.

- **Phase 10: Verification & End-to-End Testing**
  - Run backend automated test suite.
  - Test client build and run on Windows.
  - Verify full end-to-end flow.
  - Documentation and README.md.

