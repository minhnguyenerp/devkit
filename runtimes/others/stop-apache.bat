@echo off
setlocal

echo [INFO] Terminating ALL Apache (httpd) processes...
REM Dừng tất cả tiến trình Apache đang chạy
taskkill /IM httpd.exe /F >nul 2>nul

echo [INFO] Terminating ALL php-cgi processes...
REM Dừng tất cả tiến trình php-cgi đang chạy
taskkill /IM php-cgi.exe /F >nul 2>nul

REM Xóa toàn bộ thư mục instance Apache + PHP
set "BASE=%LOCALAPPDATA%\apache-php-instances"
if exist "%BASE%" (
    echo [INFO] Cleaning up instance directories in "%BASE%"
    rd /S /Q "%BASE%" >nul 2>nul
)

echo [OK] All Apache and PHP services have been stopped and cleaned up.
exit /b 0
