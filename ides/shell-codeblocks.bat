set "ROOT=%~dp0"
call "%ROOT%shell.bat"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%CD%"
start "" codeblocks.exe "%TARGET%"
exit /b