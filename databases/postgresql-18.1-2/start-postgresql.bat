@echo off
setlocal EnableExtensions
rem title PostgreSQL 18 Portable Starter (hidden via PowerShell, always unblock)

rem --- Paths ---
set "ROOT=%~dp0"
set "BINDIR=%ROOT%bin"
set "DATADIR=%ROOT%data"
set "LOGDIR=%DATADIR%\log"
set "LOGFILE=%LOGDIR%\postgresql.log"

cd /d "%ROOT%"

echo ===============================================
echo   PostgreSQL Portable Starter
echo   BaseDir : %ROOT%
echo   DataDir : %DATADIR%
echo   LogFile : %LOGFILE%
echo ===============================================

for %%F in (postgres.exe initdb.exe) do (
  powershell -NoProfile -Command ^
    "$exe='%BINDIR%\%%F'; if (Test-Path $exe) { if (Get-Item $exe -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '[INFO] %%F blocked. Unblocking...'; Unblock-File -LiteralPath $exe; Write-Host '[OK] %%F unblocked.' } else { Write-Host '[OK] %%F clean.' } }"
)

rem --- Initialize cluster if data folder missing ---
if exist "%DATADIR%" goto have_data
echo [INFO] Data directory not found. Initializing with initdb...
mkdir "%DATADIR%" >nul 2>&1
if not exist "%BINDIR%\initdb.exe" (
  echo [ERR] initdb.exe not found in "%BINDIR%"
  exit /b 1
)
"%BINDIR%\initdb.exe" -D "%DATADIR%" -U postgres -E UTF8 --auth=trust
if errorlevel 1 (
  echo [ERR] initdb failed.
  exit /b 1
)
echo [OK] Cluster initialized.

:have_data
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

echo [START] Launching PostgreSQL (hidden, detached)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%BINDIR%\postgres.exe' -WorkingDirectory '%ROOT%' -ArgumentList '-D','%DATADIR%','-c','logging_collector=on','-c','log_directory=log','-c','log_filename=postgresql.log','-c','log_truncate_on_rotation=on','-c','log_rotation_age=1d' -WindowStyle Hidden"

rem --- Wait up to 15s for readiness ---
set "RETRIES=15"
:wait_ready
"%BINDIR%\pg_isready.exe" -h 127.0.0.1 -p 5432 >nul 2>&1
if not errorlevel 1 goto ready
set /a RETRIES-=1
if %RETRIES% LEQ 0 goto not_ready
timeout /t 1 >nul
goto wait_ready

:ready
echo [OK] PostgreSQL is running (hidden). You can close this window.
echo Connect: "%BINDIR%\psql.exe" -U postgres -h 127.0.0.1 -p 5432
exit /b 0

:not_ready
echo [WARN] Server not ready. Tail of log:
powershell -NoProfile -Command "if (Test-Path '%LOGFILE%') { Get-Content -Path '%LOGFILE%' -Tail 50 }"
exit /b 1
