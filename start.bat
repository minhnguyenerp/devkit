@echo off
title DevKit Shell
set "ROOT=%~dp0"
call "%ROOT%paths.bat"
call "%SYNPATH_OTHERS%\joinfiles.bat"
cls
set "PATH=%SYNPATH_GIT%\bin;%PATH%"
set "PATH=%SYNPATH_CONSUL%;%PATH%"
set "PATH=%SYNPATH_CURL%\bin;%PATH%"
set "PATH=%SYNPATH_ETCD%;%PATH%"
set "PATH=%SYNPATH_NPP%;%PATH%"
attrib +r "%SYNPATH_NPP%\config.xml"
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++" /ve /d "DevKit Notepad++" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++\command" /ve /d "\"%SYNPATH_NPP%\notepad++.exe\" \"%%1\"" /f >nul
set "PATH=%ROOT%programs\dbeaver\dbeaver-ce-25.2.4-win32.win32.x86_64;%PATH%"
set "PATH=%ROOT%programs\beekeeper\beekeeper-5.4.10;%PATH%"
set "PATH=%SYNPATH_HEIDISQL%;%PATH%"
set "PATH=%SYNPATH_SQLITESTUDIO%;%PATH%"
set "PATH=%SYNPATH_WINMERGE%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge\command" /ve /d "\"%SYNPATH_WINMERGE%\WinMergeU.exe\" \"%%V\"" /f >nul
set "PATH=%SYNPATH_GEANY%\bin;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%V\"" /f >nul
set "PATH=%SYNPATH_ZED%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%V\"" /f >nul
set "PATH=%SYNPATH_VSCODE%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%V\"" /f >nul
set "PATH=%SYNPATH_CODEBLOCKS%;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%V\"" /f >nul
set "PATH=%SYNPATH_NODE%;%PATH%"
set "PATH=%SYNPATH_PYTHON%;%PATH%"
set "PATH=%SYNPATH_PYTHON%\Scripts;%PATH%"
set "PATH=%SYNPATH_PHP%;%PATH%"
set "PATH=%SYNPATH_JDK%\bin;%PATH%"
set "PATH=%SYNPATH_COMPOSER%;%PATH%"
set "PATH=%SYNPATH_OTHERS%;%PATH%"
set "PATH=%SYNPATH_GO%\bin;%PATH%"
set "GOPATH=%SYNPATH_GO%\gopath"
set "GOCACHE=%SYNPATH_GO%\gocache"
set "GOTELEMETRYDIR=%SYNPATH_GO%\gotelemetry"
set "npm_config_prefix=%SYNPATH_NODE%\node_global"
set "PATH=%SYNPATH_RUST%\rustc\bin;%PATH%"
set "PATH=%SYNPATH_RUST%\cargo\bin;%PATH%"
set "RUSTFLAGS=--sysroot=%SYNPATH_RUST%\rust-std-x86_64-pc-windows-gnu"
set "CARGO_HOME=%SYNPATH_RUST%\cargo"
set "PATH=%npm_config_prefix%;%PATH%"
set "PATH=%SYNPATH_NIM%\bin;%PATH%"
set "PATH=%SYNPATH_ZIG%;%PATH%"
set "PATH=%SYNPATH_CPP%\bin;%PATH%"
set "PATH=%SYNPATH_MARIADB%;%PATH%"
set "PATH=%SYNPATH_MARIADB%\bin;%PATH%"
set "PATH=%SYNPATH_POSGRESQL%;%PATH%"
set "PATH=%SYNPATH_POSGRESQL%\bin;%PATH%"
set "PATH=%SYNPATH_POSGRESQL%\pgAdmin 4\runtime;%PATH%"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%ROOT%"
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%V\"" /f >nul
cmd.exe /k "echo [Minh Nguyen DevKit Shell Ready] && echo code, sqlitestudio, winmergeu, notepad++, heidisql, geany, codeblocks, git gui && cd /d %TARGET%"
