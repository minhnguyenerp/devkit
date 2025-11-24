@echo off
title DevKit Shell
set "ROOT=%~dp0"
call "%ROOT%runtimes\others\joinfiles.bat"
cls
set "PATH=%ROOT%programs\gitclient\PortableGit-2.51.2\bin;%PATH%"
set "PATH=%ROOT%runtimes\consul_1.22.0_windows_amd64;%PATH%"
set "PATH=%ROOT%runtimes\curl-8.17.0_2-win64-mingw\bin;%PATH%"
set "PATH=%ROOT%runtimes\etcd-v3.6.6-windows-amd64;%PATH%"
set "PATH=%ROOT%programs\npp\npp.8.8.7.portable.x64;%PATH%"
attrib +r "%ROOT%programs\npp\npp.8.8.7.portable.x64\config.xml"
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++" /ve /d "DevKit Notepad++" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Notepad++\command" /ve /d "\"%ROOT%programs\npp\npp.8.8.7.portable.x64\notepad++.exe\" \"%%1\"" /f >nul
set "PATH=%ROOT%programs\dbeaver\dbeaver-ce-25.2.4-win32.win32.x86_64;%PATH%"
set "PATH=%ROOT%programs\beekeeper\beekeeper-5.4.10;%PATH%"
set "PATH=%ROOT%programs\heidisql\HeidiSQL_12.13_64_Portable;%PATH%"
set "PATH=%ROOT%programs\sqlitestudio\SQLiteStudio-3.4.17;%PATH%"
set "PATH=%ROOT%programs\winmerge\WinMerge-2.16.52;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit WinMerge\command" /ve /d "\"%ROOT%programs\winmerge\WinMerge-2.16.52\WinMergeU.exe\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit WinMerge\command" /ve /d "\"%ROOT%programs\winmerge\WinMerge-2.16.52\WinMergeU.exe\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge" /ve /d "DevKit WinMerge" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit WinMerge\command" /ve /d "\"%ROOT%programs\winmerge\WinMerge-2.16.52\WinMergeU.exe\" \"%%V\"" /f >nul
set "PATH=%ROOT%ides\Geany-2.1\bin;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany" /ve /d "DevKit Geany" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Geany\command" /ve /d "\"%ROOT%ides\shell-geany.bat\" \"%%V\"" /f >nul
set "PATH=%ROOT%ides\Zed;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed" /ve /d "DevKit Zed" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Zed\command" /ve /d "\"%ROOT%ides\shell-zed.bat\" \"%%V\"" /f >nul
set "PATH=%ROOT%ides\VSCode-win32-x64-1.106.2;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode" /ve /d "DevKit VSCode" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit VSCode\command" /ve /d "\"%ROOT%ides\shell-code.bat\" \"%%V\"" /f >nul
set "PATH=%ROOT%ides\codeblocks-25.03-nosetup;%PATH%"
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\*\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks" /ve /d "DevKit CodeBlocks" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit CodeBlocks\command" /ve /d "\"%ROOT%ides\shell-codeblocks.bat\" \"%%V\"" /f >nul
set "PATH=%ROOT%runtimes\node-v24.11.1-win-x64;%PATH%"
set "PATH=%ROOT%runtimes\python-3.14.0-embed-amd64;%PATH%"
set "PATH=%ROOT%runtimes\python-3.14.0-embed-amd64\Scripts;%PATH%"
set "PATH=%ROOT%runtimes\php-8.4.14-Win32-vs17-x64;%PATH%"
set "PATH=%ROOT%runtimes\jdk-25\bin;%PATH%"
set "PATH=%ROOT%runtimes\composer-2.9.1;%PATH%"
set "PATH=%ROOT%runtimes\others;%PATH%"
set "PATH=%ROOT%compilers\go1.25.4.windows-amd64\bin;%PATH%"
set "GOPATH=%ROOT%compilers\go1.25.4.windows-amd64\gopath"
set "GOCACHE=%ROOT%compilers\go1.25.4.windows-amd64\gocache"
set "GOTELEMETRYDIR=%ROOT%compilers\go1.25.4.windows-amd64\gotelemetry"
set "npm_config_prefix=%ROOT%runtimes\node-v24.11.1-win-x64\node_global"
set "PATH=%ROOT%compilers\rust-1.91.1-x86_64-pc-windows-gnu\rustc\bin;%PATH%"
set "PATH=%ROOT%compilers\rust-1.91.1-x86_64-pc-windows-gnu\cargo\bin;%PATH%"
set "RUSTFLAGS=--sysroot=%ROOT%compilers\rust-1.91.1-x86_64-pc-windows-gnu\rust-std-x86_64-pc-windows-gnu"
set "CARGO_HOME=%ROOT%compilers\rust-1.91.1-x86_64-pc-windows-gnu\cargo"
set "PATH=%npm_config_prefix%;%PATH%"
set "PATH=%ROOT%compilers\nim-2.2.6\bin;%PATH%"
set "PATH=%ROOT%compilers\zig-x86_64-windows-0.16.0-dev.1442+21f9f378f;%PATH%"
set "PATH=%ROOT%compilers\winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64ucrt-13.0.0-r3\bin;%PATH%"
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%ROOT%"
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell" /ve /d "DevKit Shell" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\DevKit Shell\command" /ve /d "\"%ROOT%start.bat\" \"%%V\"" /f >nul
cmd.exe /k "echo [Minh Nguyen DevKit Shell Ready] && echo code, sqlitestudio, winmergeu, notepad++, dbeaver, beekeeper, heidisql, geany, codeblocks, git gui && cd /d %TARGET%"
