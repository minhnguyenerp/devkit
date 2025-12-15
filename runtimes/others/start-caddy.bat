@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Usage: start-caddy.bat "D:\www\myapp\public" 8080
if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "WEBROOT=%~1"
set "HTTP_PORT=%~2"

REM Init command names (resolved via PATH)
if "%PHP_CGI%"=="" set "PHP_CGI=php-cgi"
if "%CADDY_EXE%"=="" set "CADDY_EXE=caddy"

if not exist "%WEBROOT%" (
  echo [ERROR] Webroot not found: "%WEBROOT%"
  exit /b 2
)

REM Resolve php-cgi path
where "%PHP_CGI%" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] php-cgi.exe not found in PATH.
  exit /b 3
)
for /f "delims=" %%P in ('where "%PHP_CGI%"') do set "PHP_CGI=%%P"

REM Resolve caddy path
where "%CADDY_EXE%" >nul 2>nul
if errorlevel 1 (
  echo [ERROR] caddy.exe not found in PATH.
  exit /b 4
)
for /f "delims=" %%C in ('where "%CADDY_EXE%"') do set "CADDY_EXE=%%C"

REM Compute PHP FastCGI port
set /a PHP_PORT=HTTP_PORT+10000
if %PHP_PORT% GTR 65535 (
  echo [ERROR] HTTP_PORT too high; PHP_PORT would exceed 65535.
  exit /b 5
)

REM Instance dirs
set "BASE=%LOCALAPPDATA%\caddy-php-instances"
set "INST=%BASE%\%HTTP_PORT%"
set "CFG=%INST%\Caddyfile"
set "CADDY_PID=%INST%\caddy.pid"
REM set "PHP_PID=%INST%\php.pid" <-- KHÔNG DÙNG FILE PID CHO PHP

mkdir "%INST%" >nul 2>nul

REM Stop old instance if exists
if exist "%CADDY_PID%" (
  call "%~dp0stop-caddy.bat" %HTTP_PORT% >nul 2>nul
)

REM Write Caddyfile (Global config first, admin off)
(
  REM 1. Ghi cấu hình toàn cục trước (ví dụ: tắt admin API)
  echo {
  echo    admin off
  echo }

  REM 2. Ghi định nghĩa server sau
  echo :%HTTP_PORT% {
  echo     root * "%WEBROOT%"
  echo     encode gzip zstd
  echo     php_fastcgi 127.0.0.1:%PHP_PORT%
  echo     file_server
  echo }
) > "%CFG%"


REM -----------------------------
REM Start php-cgi detached (no console window)
REM -----------------------------
start "php-cgi-%HTTP_PORT%" /B "%PHP_CGI%" -b 127.0.0.1:%PHP_PORT% >nul 2>nul

REM Wait until php-cgi is LISTENING - Vẫn cần chờ cổng mở trước khi khởi động Caddy
set /a _tries=0

:wait_php
set /a _tries+=1

REM Chỉ cần đảm bảo CÓ AI ĐÓ lắng nghe cổng FastCGI là được
netstat -ano | findstr /R /C:":%PHP_PORT% .*LISTENING" >nul

if %errorlevel% equ 0 goto php_ok

if %_tries% GEQ 30 (
  echo [ERROR] php-cgi did not listen on 127.0.0.1:%PHP_PORT%
  exit /b 6
)

ping 127.0.0.1 -n 2 >nul
goto wait_php

:php_ok
REM -----------------------------
REM Start Caddy hidden (Sử dụng lại Powershell để ẩn cửa sổ và lấy PID tin cậy)
REM -----------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Start-Process -FilePath '%CADDY_EXE%' -ArgumentList @('run','--config','%CFG%','--adapter','caddyfile') -WindowStyle Hidden -PassThru; " ^
  "Set-Content -Path '%CADDY_PID%' -Value $p.Id -Encoding ASCII" >nul 2>nul


echo [OK] Serving "%WEBROOT%" on http://localhost:%HTTP_PORT%
echo      PHP FastCGI: 127.0.0.1:%PHP_PORT%
exit /b 0

:usage
echo Usage:
echo   start-caddy.bat "WEBROOT" PORT
echo Example:
echo   start-caddy.bat "D:\www\myapp\public" 8080
exit /b 1
