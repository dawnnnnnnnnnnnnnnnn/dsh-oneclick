@echo off
setlocal
title dsh repair tool

rem Thin launcher for the repair script. ASCII only, so double-clicking always works.
rem The real work is in windows\fix.ps1.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\fix.ps1"

echo.
echo Press any key to close this window...
pause >nul
