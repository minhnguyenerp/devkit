@echo off
setlocal EnableExtensions
rem title Stop PostgreSQL Server

set "ROOT=%~dp0"
set "BINDIR=%ROOT%bin"
set "DATADIR=%ROOT%data"

if not exist "%BINDIR%\pg_ctl.exe" (
  echo [ERR] pg_ctl.exe not found in "%BINDIR%"
  exit /b 1
)

echo [STOP] Stopping PostgreSQL (fast)...
"%BINDIR%\pg_ctl.exe" stop -D "%DATADIR%" -m fast >nul 2>&1
if errorlevel 1 goto kill
echo [OK] PostgreSQL stopped cleanly.
exit /b 0

:kill
echo [WARN] pg_ctl stop failed or server not running. Killing postgres.exe...
taskkill /F /IM postgres.exe >nul 2>&1
if errorlevel 1 (
  echo [INFO] No postgres.exe process found.
) else (
  echo [OK] Process killed.
)
exit /b 0
