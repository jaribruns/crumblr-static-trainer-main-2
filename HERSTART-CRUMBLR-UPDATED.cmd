@echo off
setlocal
title Crumblr Trainer bijgewerkt herstarten
cd /d "C:\Crumblr\crumblr-static-trainer-main"
echo Crumblr Trainer wordt bijgewerkt herstart. Campagnes en resultaten blijven behouden.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Crumblr\crumblr-static-trainer-main\Stop-Crumblr-Trainer.ps1"
if errorlevel 1 (
  echo Stoppen is mislukt. Lees de fout hierboven.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Crumblr\crumblr-static-trainer-main\Start-Crumblr-Trainer.ps1"
if errorlevel 1 (
  echo Starten is mislukt. Lees de fout hierboven.
  pause
  exit /b 1
)
endlocal
