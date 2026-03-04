@echo off
title Context Menu Installer

set "ROOT=%~dp0"
call "%ROOT%paths.bat"

echo ===============================
echo   DevKit Context Menu Setup
echo ===============================
echo.
echo 1. Install context menu
echo 2. Uninstall context menu
echo.
set /p choice=Choose (1 or 2):

if "%choice%"=="1" goto install
if "%choice%"=="2" goto uninstall

echo Invalid choice.
pause
exit /b

:install
echo Installing context menu...

set "PATH=%SYNPATH_SUMATRA_PDF%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit SumatraPDF" /ve /d "DevKit SumatraPDF" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit SumatraPDF" /v Icon /t REG_SZ /d "%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit SumatraPDF\command" /ve /d "\"%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit SumatraPDF" /ve /d "DevKit SumatraPDF" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit SumatraPDF" /v Icon /t REG_SZ /d "%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit SumatraPDF\command" /ve /d "\"%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit SumatraPDF" /ve /d "DevKit SumatraPDF" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit SumatraPDF" /v Icon /t REG_SZ /d "%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit SumatraPDF\command" /ve /d "\"%SYNPATH_SUMATRA_PDF%\SumatraPDF-3.5.2-64.exe\"" /f >nul

set "PATH=%SYNPATH_NPP%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++" /ve /d "DevKit Notepad++" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++" /v Icon /t REG_SZ /d "%SYNPATH_NPP%\notepad++.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++\command" /ve /d "\"%SYNPATH_NPP%\notepad++.exe\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit Notepad++" /ve /d "DevKit Notepad++" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Notepad++" /v Icon /t REG_SZ /d "%SYNPATH_NPP%\notepad++.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Notepad++\command" /ve /d "\"%SYNPATH_NPP%\notepad++.exe\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Notepad++" /ve /d "DevKit Notepad++" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Notepad++" /v Icon /t REG_SZ /d "%SYNPATH_NPP%\notepad++.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Notepad++\command" /ve /d "\"%SYNPATH_NPP%\notepad++.exe\"" /f >nul

set "PATH=%SYNPATH_WINMERGE%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge" /v Icon /t REG_SZ /d "%SYNPATH_WINMERGE%\WinMergeU.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge" /v Icon /t REG_SZ /d "%SYNPATH_WINMERGE%\WinMergeU.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge" /v Icon /t REG_SZ /d "%SYNPATH_WINMERGE%\WinMergeU.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%V\"" /f >nul

set "PATH=%SYNPATH_GEANY%\bin;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Geany" /v Icon /t REG_SZ /d "%SYNPATH_GEANY%\bin\geany.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany" /v Icon /t REG_SZ /d "%SYNPATH_GEANY%\bin\geany.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany" /v Icon /t REG_SZ /d "%SYNPATH_GEANY%\bin\geany.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%V\"" /f >nul

set "PATH=%SYNPATH_ZED%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Zed" /v Icon /t REG_SZ /d "%SYNPATH_ZED%\Zed.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed" /v Icon /t REG_SZ /d "%SYNPATH_ZED%\Zed.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed" /v Icon /t REG_SZ /d "%SYNPATH_ZED%\Zed.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%V\"" /f >nul

set "PATH=%SYNPATH_CODELITE%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit CodeLite" /ve /d "DevKit CodeLite" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeLite" /v Icon /t REG_SZ /d "%SYNPATH_CODELITE%\codelite.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeLite\command" /ve /d "\"%ROOT%ides\shell-codelite.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeLite" /ve /d "DevKit CodeLite" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeLite" /v Icon /t REG_SZ /d "%SYNPATH_CODELITE%\codelite.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeLite\command" /ve /d "\"%ROOT%ides\shell-codelite.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeLite" /ve /d "DevKit CodeLite" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeLite" /v Icon /t REG_SZ /d "%SYNPATH_CODELITE%\codelite.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeLite\command" /ve /d "\"%ROOT%ides\shell-codelite.bat\" \"%%V\"" /f >nul

set "PATH=%SYNPATH_VSCODE%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode" /v Icon /t REG_SZ /d "%SYNPATH_VSCODE%\Code.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode" /v Icon /t REG_SZ /d "%SYNPATH_VSCODE%\Code.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode" /v Icon /t REG_SZ /d "%SYNPATH_VSCODE%\Code.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%V\"" /f >nul

set "PATH=%SYNPATH_CODEBLOCKS%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks" /v Icon /t REG_SZ /d "%SYNPATH_CODEBLOCKS%\codeblocks.exe" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks" /v Icon /t REG_SZ /d "%SYNPATH_CODEBLOCKS%\codeblocks.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks" /v Icon /t REG_SZ /d "%SYNPATH_CODEBLOCKS%\codeblocks.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%V\"" /f >nul


reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell" /v Icon /t REG_SZ /d "%SystemRoot%\System32\cmd.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%1\"" /f >nul

reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell" /v Icon /t REG_SZ /d "%SystemRoot%\System32\cmd.exe" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%V\"" /f >nul

echo Done.
pause
exit /b

:uninstall
echo Removing context menu...

REM --- For all files (*)
reg delete "HKCU\Software\Classes\*\shell\DevKit SumatraPDF" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit Notepad++" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit WinMerge" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit Geany" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit Zed" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit CodeLite" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit VSCode" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\DevKit CodeBlocks" /f >nul 2>&1

REM --- For Directory (folder)
reg delete "HKCU\Software\Classes\Directory\shell\DevKit SumatraPDF" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit Notepad++" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit WinMerge" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit Geany" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit Zed" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit CodeLite" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit VSCode" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\DevKit Shell" /f >nul 2>&1

REM --- For Directory Background (empty area in folder)
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit SumatraPDF" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit Notepad++" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeLite" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell" /f >nul 2>&1

echo Done.
pause
exit /b
