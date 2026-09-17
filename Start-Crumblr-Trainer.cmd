@echo off
setlocal
title Crumblr Trainer lokaal starten
cd /d "%~dp0"
echo.
echo Crumblr Trainer, AI-agent en MT5-worker worden lokaal gestart...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Crumblr-Trainer.ps1"
if errorlevel 1 (
  echo.
  echo De Trainer kon niet starten. Lees de fout hierboven.
  pause
)
