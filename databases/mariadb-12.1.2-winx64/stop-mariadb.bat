@echo off
setlocal EnableExtensions
rem title Stop MariaDB Server

set "ROOT=%~dp0"
set "BINDIR=%ROOT%bin"

echo [STOP] Attempting clean shutdown...
"%BINDIR%\mariadb-admin.exe" -uroot -h127.0.0.1 -P3306 --protocol=tcp shutdown >nul 2>&1

if errorlevel 1 (
  echo [WARN] Clean shutdown failed or server not responding.
  echo [INFO] Killing any running mariadbd.exe processes...
  taskkill /F /IM mariadbd.exe >nul 2>&1 && (
    echo [OK] Process killed.
  ) || (
    echo [INFO] No mariadbd.exe process found.
  )
) else (
  echo [OK] MariaDB stopped cleanly.
)
exit /b 0
