@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-test.ps1" -PotiShaders %*
if errorlevel 1 pause
