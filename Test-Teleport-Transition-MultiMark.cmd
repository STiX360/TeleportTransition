@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-test.ps1" -PureMultiMarkArchive "%USERPROFILE%\Downloads\puremultimark-57313-2-5-1776680162.zip" %*
if errorlevel 1 pause
