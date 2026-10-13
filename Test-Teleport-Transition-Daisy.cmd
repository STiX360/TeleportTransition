@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-test.ps1" -Engine "%~dp0.runtime\kyne-source\engine\openmw.exe" -DaisyMultiMarkArchive "%USERPROFILE%\Downloads\Daisys Lua Multimark-53260-2-1775664221.zip" %*
if errorlevel 1 pause
