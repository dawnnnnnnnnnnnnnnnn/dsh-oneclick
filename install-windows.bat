@echo off
setlocal
title dsh one-click installer

rem This thin launcher starts PowerShell with the real installer.
rem Keep this file ASCII-only so double-clicking always works.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\install.ps1"

echo.
echo Press any key to close this window...
pause >nul
