@echo off
setlocal
echo [INFO] Stopping etcd...
taskkill /F /IM etcd.exe >nul 2>&1
if %errorlevel%==0 (
  echo [OK] etcd stopped.
) else (
  echo [WARN] etcd not running.
)
exit /b 0
