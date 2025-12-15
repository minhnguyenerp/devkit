@echo off
setlocal EnableExtensions
rem title MariaDB 12 Portable Starter (background hidden)

rem --- Base paths ---
set "ROOT=%~dp0"
set "BINDIR=%ROOT%bin"
set "DATADIR=%ROOT%data"
set "CONF=%ROOT%my.ini"
set "ERRLOG=%DATADIR%\mariadb-error-log.err"

cd /d "%ROOT%"

echo ===============================================
echo   MariaDB Portable Starter
echo   BaseDir : %ROOT%
echo   DataDir : %DATADIR%
echo   Config  : %CONF%
echo   ErrLog  : %ERRLOG%
echo ===============================================

for %%F in (mariadbd.exe mariadb-install-db.exe) do (
  powershell -NoProfile -Command ^
    "$exe='%BINDIR%\%%F'; if (Test-Path $exe) { if (Get-Item $exe -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Write-Host '[INFO] %%F blocked. Unblocking...'; Unblock-File -LiteralPath $exe; Write-Host '[OK] %%F unblocked.' } else { Write-Host '[OK] %%F clean.' } }"
)

rem --- Initialize if data folder missing ---
if not exist "%DATADIR%" (
  echo [INFO] Data directory not found. Running mariadb-install-db...
  md "%DATADIR%" >nul 2>&1

  if not exist "%BINDIR%\mariadb-install-db.exe" (
    echo [ERR] mariadb-install-db.exe not found in "%BINDIR%".
    exit /b 1
  )

  "%BINDIR%\mariadb-install-db.exe" --datadir "%DATADIR%"
  if errorlevel 1 (
    echo [ERR] mariadb-install-db failed. Aborting.
    exit /b 1
  )
  echo [OK] Initialization completed.
) else (
  echo [OK] Data directory already initialized.
)

echo [START] Launching MariaDB server (hidden, detached)...

rem --- Run mariadbd hidden (detached) ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%BINDIR%\mariadbd.exe' -ArgumentList '--defaults-file=%CONF%','--log-error=%ERRLOG%' -WindowStyle Hidden"

rem --- Wait up to ~15s for readiness ---
for /l %%I in (1,1,15) do (
  "%BINDIR%\mariadb-admin.exe" -uroot -h127.0.0.1 -P3306 --protocol=tcp ping >nul 2>&1 && goto ready
  timeout /t 1 >nul
)

echo [WARN] Server did not respond in time. Check error log:
if exist "%ERRLOG%" powershell -NoProfile -Command "Get-Content -Path '%ERRLOG%' -Tail 50"
goto end

:ready
echo [OK] MariaDB server is running.
echo You can safely close this window; the server will keep running.
echo To stop it later, run: stop-mariadb

:end
exit /b 0
