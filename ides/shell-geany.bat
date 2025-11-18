set "ROOT=%~dp0"
call "%ROOT%shell.bat"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%CD%"
start "" geany.exe "%TARGET%"
exit /b