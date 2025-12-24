@echo off
title DevKit C++
set "ROOT=%~dp0"
call "%ROOT%paths.bat"
call "%SYNPATH_OTHERS%\joinfiles.bat"
cls
set "PATH=%SYNPATH_GIT%\bin;%PATH%"
set "PATH=%SYNPATH_PYTHON%;%PATH%"
set "PATH=%SYNPATH_PYTHON%\Scripts;%PATH%"
set "PATH=%SYNPATH_OTHERS%;%PATH%"
set "PATH=%SYNPATH_CPP%\bin;%PATH%"
cmd.exe /k "echo [Minh Nguyen DevKit C++ Shell Ready] && cd /d %ROOT%"
