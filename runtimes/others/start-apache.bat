@echo off
setlocal EnableExtensions EnableDelayedExpansion

if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "WEBROOT=%~1"

set "RAW_PATH=%~1"
if "%RAW_PATH%"=="." (
    set "WEBROOT=%CD%"
) else (
    pushd "%RAW_PATH%" 2>nul
    if errorlevel 1 (
        echo [ERROR] Directory not exists: "%RAW_PATH%"
        exit /b 2
    )
    set "WEBROOT=!CD!"
    popd
)

set "HTTP_PORT=%~2"

REM 1. Tìm đường dẫn Apache và PHP
for /f "delims=" %%H in ('where httpd.exe') do set "HTTPD_PATH=%%H"
for %%I in ("%HTTPD_PATH%\..\..") do set "SRVROOT=%%~fI"
for /f "delims=" %%P in ('where php.exe') do set "PHP_DIR=%%~dpP"
set "PHP_MODULE=%PHP_DIR%php8apache2_4.dll"

if not exist "%PHP_MODULE%" (
    echo [ERROR] Module not found: %PHP_MODULE%
    exit /b 5
)

REM Chuyển đổi đường dẫn sang dấu /
set "SRVROOT_S=%SRVROOT:\=/%"
set "DOCROOT_S=%WEBROOT:\=/%"
set "PHP_DIR_S=%PHP_DIR:\=/%"
set "PHP_MODULE_S=%PHP_MODULE:\=/%"

set "BASE=%LOCALAPPDATA%\apache-php-instances"
set "INST=%BASE%\%HTTP_PORT%"
if not exist "%INST%\logs" mkdir "%INST%\logs"
if not exist "%INST%\tmp" mkdir "%INST%\tmp"
set "CFG=%INST%\httpd.conf"
set "INST_S=%INST:\=/%"

REM 2. Dọn dẹp port cũ
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :%HTTP_PORT% ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1

(
  echo Define SRVROOT "%SRVROOT_S%"
  echo ServerRoot "${SRVROOT}"
  echo.
  echo Listen %HTTP_PORT%
  echo ServerName localhost:%HTTP_PORT%
  echo.
  echo ErrorLog "%INST_S%/logs/error.log"
  echo CustomLog "%INST_S%/logs/access.log" common
  echo.
  echo LoadModule access_compat_module modules/mod_access_compat.so
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
  echo LoadModule dir_module modules/mod_dir.so
  echo LoadModule env_module modules/mod_env.so
  echo LoadModule include_module modules/mod_include.so
  echo LoadModule isapi_module modules/mod_isapi.so
  echo LoadModule log_config_module modules/mod_log_config.so
  echo LoadModule mime_module modules/mod_mime.so
  echo LoadModule negotiation_module modules/mod_negotiation.so
  echo LoadModule setenvif_module modules/mod_setenvif.so
  echo LoadModule proxy_module modules/mod_proxy.so
  echo LoadModule rewrite_module modules/mod_rewrite.so
  echo LoadModule php_module "%PHP_MODULE_S%"
  echo PHPINIDir "%PHP_DIR_S%"
  echo AddType application/x-httpd-php .php
  echo.
  echo DocumentRoot "%DOCROOT_S%"
  echo DirectoryIndex index.php index.html
  echo.
  echo ^<Directory "%DOCROOT_S%"^>
  echo     AllowOverride All
  echo     Require all granted
  echo ^</Directory^>
  echo.
) > "%CFG%"

REM 4. Khởi chạy
start "APA_PHP8_%HTTP_PORT%" /B "%HTTPD_PATH%" -f "%CFG%"

echo.
echo [OK] Server started at http://localhost:%HTTP_PORT%
exit /b 0

:usage
echo Usage: start-apache.bat "WEBROOT" PORT
exit /b 1
