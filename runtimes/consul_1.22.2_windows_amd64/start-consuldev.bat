@echo off
setlocal

rem --- Configuration ---
set "BASE_DIR=%~dp0"
set "CONSUL_EXE=%BASE_DIR%consul.exe"
set "DATA_DIR=%BASE_DIR%data"
set "LOG_OUT=%BASE_DIR%consul.out.log"
set "LOG_ERR=%BASE_DIR%consul.err.log"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

rem --- Unblock binaries if blocked by Windows SmartScreen ---
for %%F in (consul.exe) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p = Join-Path -Path '%BASE_DIR%' -ChildPath '%%F'; if (Test-Path $p) { if (Get-Item -LiteralPath $p -Stream Zone.Identifier -EA SilentlyContinue) { Unblock-File -LiteralPath $p } }"
)

rem --- Check if Consul is already running ---
tasklist /FI "IMAGENAME eq consul.exe" | find /I "consul.exe" >nul
if %errorlevel%==0 (
    echo [INFO] Consul is already running.
    exit /b 0
)

echo [INFO] Starting Consul in background (dev mode)...

rem --- Run Consul agent in dev mode, hidden via PowerShell ---
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%CONSUL_EXE%' -ArgumentList @('agent','-dev','-data-dir','%DATA_DIR%','-client','0.0.0.0','-ui') -WorkingDirectory '%BASE_DIR%' -WindowStyle Hidden -RedirectStandardOutput '%LOG_OUT%' -RedirectStandardError '%LOG_ERR%'"

if errorlevel 1 (
  echo [ERROR] Failed to start Consul. Check logs:
  echo   OUT: %LOG_OUT%
  echo   ERR: %LOG_ERR%
  exit /b 1
)

curl http://127.0.0.1:8500/v1/status/leader

echo [OK] Consul started in background (dev mode).
echo [WEB UI] http://127.0.0.1:8500
echo [LOG] OUT: %LOG_OUT%
echo [LOG] ERR: %LOG_ERR%
exit /b 0
