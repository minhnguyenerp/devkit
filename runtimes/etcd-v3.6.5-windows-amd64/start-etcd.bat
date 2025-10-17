@echo off
setlocal

rem --- Configuration (renamed to avoid ETCD_* prefix) ---
set "BASE_DIR=%~dp0"
set "ETCD_BIN=%BASE_DIR%etcd.exe"
set "DATA_DIR=%BASE_DIR%data"
set "LOG_OUT=%BASE_DIR%etcd.out.log"
set "LOG_ERR=%BASE_DIR%etcd.err.log"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

rem --- Unblock binaries if blocked by SmartScreen ---
for %%F in (etcd.exe etcdctl.exe etcdutl.exe) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p = Join-Path -Path '%BASE_DIR%' -ChildPath '%%F'; if (Test-Path $p) { if (Get-Item -LiteralPath $p -Stream Zone.Identifier -EA SilentlyContinue) { Unblock-File -LiteralPath $p } }"
)

rem --- Avoid duplicate instance ---
tasklist /FI "IMAGENAME eq etcd.exe" | find /I "etcd.exe" >nul && (
  echo [INFO] etcd is already running.
  exit /b 0
)

echo [INFO] Starting etcd in background via PowerShell...

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%ETCD_BIN%' -ArgumentList @('--name','%COMPUTERNAME%','--data-dir','%DATA_DIR%','--listen-client-urls','http://127.0.0.1:2379','--advertise-client-urls','http://127.0.0.1:2379','--listen-peer-urls','http://127.0.0.1:2380') -WorkingDirectory '%BASE_DIR%' -WindowStyle Hidden -RedirectStandardOutput '%LOG_OUT%' -RedirectStandardError '%LOG_ERR%'"

if errorlevel 1 (
  echo [ERROR] Failed to start etcd. Check logs:
  echo   OUT_LOG: %LOG_OUT%
  echo   ERR_LOG: %LOG_ERR%
  exit /b 1
)

echo [OK] etcd started in background.
echo [LOG] OUT_LOG: %LOG_OUT%
echo [LOG] ERR_LOG: %LOG_ERR%
exit /b 0
