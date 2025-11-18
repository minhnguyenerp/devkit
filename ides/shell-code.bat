set "ROOT=%~dp0"
call "%ROOT%shell.bat"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%CD%"
start "" Code.exe "%TARGET%"
exit /b