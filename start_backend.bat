@echo off
title FocusGuard Backend Server
echo ===================================================
echo Starting FocusGuard Backend (FastAPI + SQLite/Postgres)
echo ===================================================
cd /d "%~dp0backend"
if exist venv\Scripts\python.exe (
    call venv\Scripts\activate.bat
    python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
) else (
    echo Python virtual environment not found in backend\venv!
    echo Please run setup first.
    pause
)

