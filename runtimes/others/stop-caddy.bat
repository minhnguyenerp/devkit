@echo off
setlocal

echo [INFO] Terminating ALL Caddy processes...
REM Dừng tất cả tiến trình caddy đang chạy
taskkill /IM caddy.exe /F >nul 2>nul

echo [INFO] Terminating ALL php-cgi processes...
REM Dừng tất cả tiến trình php-cgi đang chạy
taskkill /IM php-cgi.exe /F >nul 2>nul

REM Xóa toàn bộ thư mục tạm chứa Caddyfiles và PIDs
set "BASE=%LOCALAPPDATA%\caddy-php-instances"
if exist "%BASE%" (
    echo [INFO] Cleaning up instance directories in "%BASE%"
    rd /S /Q "%BASE%" >nul 2>nul
)

echo [OK] All Caddy and PHP services have been stopped and cleaned up.
exit /b 0
