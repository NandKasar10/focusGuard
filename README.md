# FocusGuard 🛡️
> **A Cross-Platform Digital-Wellbeing & AI Intervention MVP**  
> *Built with Flutter (Windows + Android), FastAPI (Python), PostgreSQL, and Google Gemini Vision.*

FocusGuard is designed to solve digital distraction with psychological accountability. When you cross your daily or continuous usage limits on distracting apps (e.g. YouTube, Instagram, Facebook), FocusGuard immediately interrupts by:
1. Auto-playing **your OWN pre-recorded motivational video** (stored strictly in private local storage).
2. Presenting an **AI-powered Hinglish reality check** based on your active screen context and study goals.
3. Tracking your response, scheduling timed follow-up reminders, and monitoring whether you actually closed the app.

---

## 🏗️ Architecture & Privacy-First Design

```
+-----------------------------------------------------------+
|               Flutter Client (Android & Windows)          |
|  - Windows: Win32 API Window Detection + Screen Capture   |
|  - Android: UsageStatsManager + Overlay + MediaProjection |
|  - Local Storage: SQLite (sqflite / sqflite_common_ffi)   |
|  - Secure Storage: flutter_secure_storage (JWTs)          |
|  - Video: Local app-private motivational video storage    |
+-----------------------------+-----------------------------+
                              |
                    REST API (FastAPI)
                              |
+-----------------------------v-----------------------------+
|                     FastAPI Backend                        |
|  - Auth: JWT (Access & Refresh), Passlib/Bcrypt           |
|  - AI Guidance: Gemini Vision (Processed in RAM only)     |
|  - Endpoints: /auth, /settings, /usage, /guidance, etc.   |
|  - SQLAlchemy 2.0 ORM + Alembic Migrations                |
+-----------------------------+-----------------------------+
                              |
+-----------------------------v-----------------------------+
|                  PostgreSQL Database                      |
|  Tables: users, tracked_apps, limits, usage_logs,         |
|          suggestions, reminders                           |
+-----------------------------------------------------------+
```

### 🔒 Privacy & Security Highlights
- **Zero Video Persistence on Server**: Your motivational video is recorded/selected on your device and saved **only** in app-private local storage (`getApplicationDocumentsDirectory()`). The server only records a boolean flag `has_video = true`.
- **Zero Screenshot Persistence on Server**: When a limit triggers and screenshot consent is enabled, the in-memory image bytes are passed to the Gemini Vision model in RAM and discarded immediately. No images are ever saved to disk or database.
- **Explicit Consent**: Granular consent toggles during onboarding and in settings for both usage tracking and screenshot capture.
- **Right to be Forgotten**: A dedicated `DELETE /api/v1/settings/data` endpoint allows you to wipe all telemetry and logs from the server anytime.
- **Rate Limiting & Password Hashing**: Bcrypt salt hashing, JWT access/refresh token rotation, and in-memory sliding window rate limiting.

---

## 📂 Project Structure

```
.
├── docker-compose.yml          # PostgreSQL 16 container definition
├── PLAN.md                     # Architectural and implementation plan
├── README.md                   # Setup guide and documentation
│
├── backend/                    # FastAPI Backend
│   ├── alembic/                # Alembic migration environment & scripts
│   │   ├── versions/
│   │   │   └── 001_initial_schema.py
│   │   └── env.py
│   ├── alembic.ini             # Alembic configuration
│   ├── app/
│   │   ├── api/
│   │   │   ├── deps.py         # OAuth2 Bearer token dependencies
│   │   │   └── v1/
│   │   │       ├── auth.py     # /register, /login, /refresh, /me
│   │   │       ├── guidance.py # /guidance (Vision AI), /suggestions/{id}/reply
│   │   │       ├── settings.py # /settings (GET, PUT, DELETE data)
│   │   │       ├── summary.py  # /summary/daily?date=
│   │   │       └── usage.py    # /usage/sync
│   │   ├── core/
│   │   │   ├── config.py       # Pydantic BaseSettings (.env loader)
│   │   │   ├── database.py     # SQLAlchemy engine & session maker
│   │   │   └── security.py     # Bcrypt & JWT encoding/decoding
│   │   ├── models/             # SQLAlchemy ORM models
│   │   │   ├── limit.py
│   │   │   ├── reminder.py
│   │   │   ├── suggestion.py
│   │   │   ├── tracked_app.py
│   │   │   ├── usage_log.py
│   │   │   └── user.py
│   │   ├── schemas/            # Pydantic v2 schemas
│   │   ├── services/
│   │   │   └── ai_guidance.py  # Gemini Vision analysis & Hinglish prompt engine
│   │   └── main.py             # FastAPI entrypoint, CORS, rate limiting
│   ├── tests/                  # Pytest automated test suite
│   │   ├── conftest.py
│   │   ├── test_auth.py
│   │   └── test_guidance_and_summary.py
│   ├── .env.example
│   └── requirements.txt
│
└── app/                        # Flutter Client (Android + Windows)
    ├── android/                # Android native source & UsageStats permissions
    ├── windows/                # Windows native runner & Win32 window APIs
    ├── lib/
    │   ├── core/
    │   │   ├── api_client.dart # HTTP client with auto JWT refresh
    │   │   ├── constants.dart  # API routes & app configuration
    │   │   ├── database_helper.dart # Local SQLite database
    │   │   ├── notification_service.dart # Reminder & summary alerts
    │   │   └── storage_service.dart # Secure storage & shared preferences
    │   ├── models/             # Dart data models
    │   ├── providers/          # State management (Auth, Usage, Summary)
    │   ├── screens/
    │   │   ├── auth/           # Login & Register screens
    │   │   ├── home/           # Dashboard with live usage & Simulator
    │   │   ├── onboarding/     # Permissions & Video Recording
    │   │   ├── overlay/        # Fullscreen Motivational Video Overlay
    │   │   ├── settings/       # App limits, goals, consent & wipe data
    │   │   └── summary/        # Daily timeline, streak & compliance stats
    │   ├── services/
    │   │   ├── intervention_manager.dart # Coordinates trigger, video, and reply
    │   │   ├── screen_capture_service.dart # In-memory screenshot capture
    │   │   ├── usage_monitor_service.dart  # Background 3s active app detector
    │   │   └── window_detector_service.dart# Win32 & Android foreground detector
    │   └── main.dart           # App root & Auth gate
    ├── pubspec.yaml
    └── test/widget_test.dart
```

---

## 🚀 Getting Started

### Prerequisites
- **Python 3.10+** (Python 3.13 recommended)
- **Flutter SDK 3.13+** (Windows desktop workload and/or Android SDK)
- **Docker** (Optional, for running PostgreSQL; SQLite is supported by default for zero-friction local development)

---

### Step 1: Start PostgreSQL (Docker)
To spin up a PostgreSQL instance with Docker Compose:
```bash
docker compose up -d
```
The database will be available at `localhost:5432` with database `focusguard`.

---

### Step 2: Backend Setup & Migrations
1. Navigate to the `/backend` folder:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   # On macOS/Linux:
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure environment variables:
   Copy `.env.example` to `.env`:
   ```bash
   copy .env.example .env
   ```
   *To use Gemini Vision, set your `GEMINI_API_KEY` in `.env` (optional, smart contextual fallback runs automatically if unset).*
5. Run database migrations:
   ```bash
   alembic upgrade head
   ```
6. Run the automated backend tests:
   ```bash
   pytest -v
   ```
   *(All 10 test suites covering Auth, Guidance, Usage Sync, Settings, and Daily Summary will run and pass).*
7. Start the FastAPI server:
   ```bash
   uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
   ```
   API interactive documentation will be live at: `http://127.0.0.1:8000/docs`

---

### Step 3: Flutter Client Setup (Windows & Android)
1. Navigate to the `/app` folder:
   ```bash
   cd app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Dart analyzer:
   ```bash
   flutter analyze
   ```
4. Run Flutter tests:
   ```bash
   flutter test
   ```
5. Launch the app:
   - **Windows Desktop**:
     ```bash
     flutter run -d windows
     ```
   - **Android Emulator / Device**:
     ```bash
     flutter run -d android
     ```

---

## 🎮 Testing the Complete MVP Flow

To test the entire user journey in under 2 minutes without waiting for a full 60-minute limit:

1. **Register**: Launch the app and create an account (e.g. `aman@example.com`).
2. **Permissions Onboarding**: Review the clear explanation of Usage Stats, Overlay, and Notifications permissions.
3. **Record Motivational Video**:
   - Use your webcam/camera, upload an MP4/MOV, or click **"Use Instant Sample Video"**.
   - Watch the instant preview verifying local playback.
4. **Dashboard**: Notice default tracked apps (**YouTube**, **Instagram**, **Facebook**) with 0m usage and limits.
5. **Debug Simulator**:
   - In the **Debug & Demo Simulator** box at the bottom of the dashboard:
     - Click **"+15m YouTube"** or **"+30m Instagram"** to see live progress bars update.
     - Click **"🔥 Trigger Limit Overlay Now!"**.
6. **Motivational Video & AI Guidance Triggered**:
   - The fullscreen overlay appears immediately.
   - Your local motivational video auto-plays on loop.
   - The AI Study Buddy card delivers a personalized Hinglish reality check (e.g. *"Bhai, 60 min ho chuke hain! Abhi kaam pehle nipta le, 40 min baad reward ke taur pe dekhna."*).
7. **Action Reply**:
   - Click **"Okay, I'll study"** (or **"Snooze 10 min"**).
   - A study reminder notification is automatically scheduled in the background.
   - FocusGuard starts a 2-minute post-intervention check to verify whether you switched away from the distracting app.
8. **Daily Summary**:
   - Tap the top-right Analytics icon (`Daily Summary`).
   - View your total screen time, compliance percentage, focus streak, and full interactive timeline of interventions and actions.

---

## 📡 API Endpoint Reference

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Register new user, seeds default tracked apps & limits |
| `POST` | `/api/v1/auth/login` | Login with email/password, returns access & refresh tokens |
| `POST` | `/api/v1/auth/refresh` | Issue new access token using valid refresh token |
| `GET` | `/api/v1/auth/me` | Fetch authenticated user profile |
| `GET` | `/api/v1/settings` | Get user tracked apps, limits, consent, and goals |
| `PUT` | `/api/v1/settings` | Update tracked apps, limits, consent, and goals |
| `DELETE` | `/api/v1/settings/data` | Privacy: Permanently wipe all telemetry & logs from server |
| `POST` | `/api/v1/usage/sync` | Sync daily usage summary logs from client SQLite |
| `POST` | `/api/v1/guidance` | In-memory screenshot + context -> returns AI Hinglish suggestion |
| `POST` | `/api/v1/suggestions/{id}/reply` | Record user reply ("followed", "snoozed", "ignored") |
| `GET` | `/api/v1/summary/daily?date=` | Daily analytics, focus streak, and timeline |

---

## 🛡️ License
Built for educational and digital wellbeing purposes.

