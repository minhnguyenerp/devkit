@echo off
setlocal

rem --- Configuration ---
set "BASE_DIR=%~dp0"
set "CONSUL_EXE=%BASE_DIR%consul.exe"
rem set "DATA_DIR=%TEMP%\consul-data-%USERNAME%"
set "DATA_DIR=%BASE_DIR%data"
set "LOG_OUT=%BASE_DIR%consul.out.log"
set "LOG_ERR=%BASE_DIR%consul.err.log"
set "HTTP_ADDR=127.0.0.1"
set "HTTP_PORT=8500"

rem --- Ensure directory structure exists (including raft/wal) ---
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
if not exist "%DATA_DIR%\raft\wal" mkdir "%DATA_DIR%\raft\wal"

rem --- Unblock consul.exe if SmartScreen blocked it ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Join-Path '%BASE_DIR%' 'consul.exe'; if (Test-Path $p) { if (Get-Item -LiteralPath $p -Stream Zone.Identifier -EA SilentlyContinue) { Unblock-File -LiteralPath $p } }"

rem --- Avoid duplicate instance ---
tasklist /FI "IMAGENAME eq consul.exe" | find /I "consul.exe" >nul
if %errorlevel%==0 (
    echo [INFO] Consul is already running.
    exit /b 0
)

echo [INFO] Starting Consul SERVER (single node) in background...

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%CONSUL_EXE%' -ArgumentList @('agent','-server','-bootstrap-expect','1','-data-dir','%DATA_DIR%','-client','%HTTP_ADDR%','-http-port','%HTTP_PORT%','-bind','127.0.0.1','-ui') -WorkingDirectory '%BASE_DIR%' -WindowStyle Hidden -RedirectStandardOutput '%LOG_OUT%' -RedirectStandardError '%LOG_ERR%'"

if errorlevel 1 (
  echo [ERROR] Failed to start Consul. Check logs:
  echo   OUT_LOG: %LOG_OUT%
  echo   ERR_LOG: %LOG_ERR%
  exit /b 1
)

curl http://127.0.0.1:8500/v1/status/leader

echo start-consul need to run 3 times if you are first time run this
echo [OK] Consul server started in background.
echo [WEB UI] http://%HTTP_ADDR%:%HTTP_PORT%/ui/
echo [LOG] OUT_LOG: %LOG_OUT%
echo [LOG] ERR_LOG: %LOG_ERR%
exit /b 0
