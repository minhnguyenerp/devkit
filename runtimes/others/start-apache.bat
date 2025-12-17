@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Usage: start-apache.bat "D:\www\myapp\public" 8080
if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "WEBROOT=%~1"
set "HTTP_PORT=%~2"

REM Init command names (resolved via PATH)
if "%PHP_CGI%"=="" set "PHP_CGI=php-cgi"
if "%APACHE_EXE%"=="" set "APACHE_EXE=httpd"

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

REM Resolve Apache httpd.exe path
set "HTTPD_PATH="
where "%APACHE_EXE%" >nul 2>nul
if errorlevel 0 (
  for /f "delims=" %%H in ('where "%APACHE_EXE%"') do set "HTTPD_PATH=%%H"
) else (
  REM Fallback: local Apache Lounge layout
  if exist "%~dp0Apache24\bin\httpd.exe" set "HTTPD_PATH=%~dp0Apache24\bin\httpd.exe"
)

if "%HTTPD_PATH%"=="" (
  echo [ERROR] httpd.exe not found. Put Apache24 next to this .bat or add httpd.exe to PATH.
  exit /b 4
)

REM Compute PHP FastCGI port
set /a PHP_PORT=HTTP_PORT+10000
if %PHP_PORT% GTR 65535 (
  echo [ERROR] HTTP_PORT too high; PHP_PORT would exceed 65535.
  exit /b 5
)

REM Instance dirs
set "BASE=%LOCALAPPDATA%\apache-php-instances"
set "INST=%BASE%\%HTTP_PORT%"
set "CFG=%INST%\httpd.conf"
set "APACHE_PID=%INST%\apache.pid"

mkdir "%INST%\logs" >nul 2>nul
mkdir "%INST%\tmp"  >nul 2>nul

REM Stop old instance if exists (by PID)
if exist "%APACHE_PID%" (
  for /f "usebackq delims=" %%I in ("%APACHE_PID%") do set "OLDPID=%%I"
  if not "!OLDPID!"=="" (
    taskkill /PID !OLDPID! /T /F >nul 2>nul
    REM give it a moment
    ping 127.0.0.1 -n 2 >nul
  )
  del /q "%APACHE_PID%" >nul 2>nul
)

REM Convert paths to forward slashes for Apache config stability
for /f "delims=" %%S in ('powershell -NoProfile -Command "$p='%~dp0Apache24'.TrimEnd('\'); $p -replace '\\','/'"') do set "SRVROOT_SLASH=%%S"
for /f "delims=" %%S in ('powershell -NoProfile -Command "$p='%WEBROOT%'.TrimEnd('\'); $p -replace '\\','/'"') do set "DOCROOT_SLASH=%%S"
for /f "delims=" %%S in ('powershell -NoProfile -Command "$p='%INST%'.TrimEnd('\'); $p -replace '\\','/'"') do set "INST_SLASH=%%S"

REM If SRVROOT doesn't exist (Apache not in script dir), derive SRVROOT from httpd.exe location
if not exist "%~dp0Apache24\conf\httpd.conf" (
  for /f "delims=" %%S in ('powershell -NoProfile -Command "$p=Split-Path -Parent '%HTTPD_PATH%'; $p=Split-Path -Parent $p; $p -replace '\\','/'"') do set "SRVROOT_SLASH=%%S"
)

REM -----------------------------
REM Write httpd.conf (no template)
REM -----------------------------
(
  echo Define SRVROOT "%SRVROOT_SLASH%"
  echo ServerRoot "${SRVROOT}"
  echo.
  echo Listen %HTTP_PORT%
  echo ServerName localhost:%HTTP_PORT%
  echo LogLevel proxy:trace8 proxy_fcgi:trace8
  echo.
  echo PidFile "%INST_SLASH%/apache.pid"
  echo ErrorLog "%INST_SLASH%/logs/error.log"
  echo CustomLog "%INST_SLASH%/logs/access.log" common
  echo.
  echo LoadModule actions_module modules/mod_actions.so
  echo LoadModule alias_module modules/mod_alias.so
  echo LoadModule allowmethods_module modules/mod_allowmethods.so
  echo LoadModule asis_module modules/mod_asis.so
  echo LoadModule auth_basic_module modules/mod_auth_basic.so
  echo LoadModule authn_core_module modules/mod_authn_core.so
  echo LoadModule authn_file_module modules/mod_authn_file.so
  echo LoadModule authz_core_module modules/mod_authz_core.so
  echo LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
  echo LoadModule authz_host_module modules/mod_authz_host.so
  echo LoadModule authz_user_module modules/mod_authz_user.so
  echo LoadModule autoindex_module modules/mod_autoindex.so
  echo LoadModule cgi_module modules/mod_cgi.so
  echo LoadModule dir_module modules/mod_dir.so
  echo LoadModule env_module modules/mod_env.so
  echo LoadModule include_module modules/mod_include.so
  echo LoadModule isapi_module modules/mod_isapi.so
  echo LoadModule log_config_module modules/mod_log_config.so
  echo LoadModule mime_module modules/mod_mime.so
  echo LoadModule negotiation_module modules/mod_negotiation.so
  echo LoadModule setenvif_module modules/mod_setenvif.so
  echo LoadModule proxy_module modules/mod_proxy.so
  echo LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
  echo LoadModule access_compat_module modules/mod_access_compat.so
  echo LoadModule rewrite_module modules/mod_rewrite.so
  echo.
  echo TypesConfig conf/mime.types
  echo.
  echo DocumentRoot "%DOCROOT_SLASH%"
  echo ^<Directory "%DOCROOT_SLASH%"^>
  echo     Options Indexes FollowSymLinks
  echo     AllowOverride All
  echo     Require all granted
  echo     AllowOverrideList Options FileInfo AuthConfig Limit
  echo ^</Directory^>
  echo.
  echo DirectoryIndex index.php index.html
  echo.
  echo ^<FilesMatch "\.php$"^>
  echo     SetHandler "proxy:fcgi://127.0.0.1:%PHP_PORT%"
  echo ^</FilesMatch^>
) > "%CFG%"

REM -----------------------------
REM Start php-cgi detached (no console window)
REM -----------------------------
start "php-cgi-%HTTP_PORT%" /B "%PHP_CGI%" -b 127.0.0.1:%PHP_PORT% >nul 2>nul

REM Wait until php-cgi is LISTENING
set /a _tries=0

:wait_php
set /a _tries+=1
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
REM Start Apache hidden and store PID
REM Use -DFOREGROUND so PID is stable for taskkill
REM -----------------------------
echo %HTTPD_PATH%
echo "%CFG%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Start-Process -FilePath '%HTTPD_PATH%' -ArgumentList @('-f','%CFG%','-DFOREGROUND') -WindowStyle Hidden -PassThru; " ^
  "Set-Content -Path '%APACHE_PID%' -Value $p.Id -Encoding ASCII" >nul 2>nul

echo [OK] Serving "%WEBROOT%" on http://localhost:%HTTP_PORT%
echo      PHP FastCGI: 127.0.0.1:%PHP_PORT%
exit /b 0

:usage
echo Usage:
echo   start-apache.bat "WEBROOT" PORT
echo Example:
echo   start-apache.bat "D:\www\myapp\public" 8080
exit /b 1
