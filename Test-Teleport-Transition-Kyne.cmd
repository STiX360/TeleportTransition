@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-kyne-test.ps1" %*
if errorlevel 1 pause
