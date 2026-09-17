@echo off
setlocal
title Crumblr Trainer lokaal stoppen
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-Crumblr-Trainer.ps1"
if errorlevel 1 pause
