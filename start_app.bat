@echo off
title FocusGuard Desktop
cd /d "%~dp0dist\FocusGuard-Windows-x64"
if exist FocusGuard.exe (
    start "" FocusGuard.exe
) else (
    echo FocusGuard.exe not found!
    pause
)

