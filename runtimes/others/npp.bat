@echo off
setlocal

if "%~1"=="" (
  set "target=%CD%"
) else (
  if "%~1"=="." (
    set "target=%CD%"
  ) else (
    set "target=%~1"
  )
)

start "" notepad++.exe -openFoldersAsWorkspace "%target%"

endlocal
