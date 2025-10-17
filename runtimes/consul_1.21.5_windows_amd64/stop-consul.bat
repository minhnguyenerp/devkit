@echo off
setlocal
echo [INFO] Stopping Consul...
taskkill /F /IM consul.exe >nul 2>&1
if %errorlevel%==0 (
  echo [OK] Consul stopped.
) else (
  echo [WARN] Consul not running.
)
exit /b 0
