@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===== Settings =====
set "LIST=%~dp0listfile.txt"

rem ===== Check for list file =====
if not exist "%LIST%" (
  echo [ERR] listfile.txt not found at: "%LIST%"
  exit /b 1
)

rem ===== Resolve first line to detect if join is needed =====
set "FIRSTRAW="
for /f "usebackq delims=" %%A in ("%LIST%") do (
  set "FIRSTRAW=%%A"
  goto :got_first
)
:got_first

if not defined FIRSTRAW (
  echo [WARN] listfile.txt is empty.
  echo Nothing to join.
  exit /b 0
)

rem Normalize and resolve path
set "FIRSTRAW=%FIRSTRAW:"=%"
set "FIRSTRAW=%FIRSTRAW:/=\%"

set "FIRSTABS="
set "H2=%FIRSTRAW:~0,2%"
if "%H2:~1,1%"==":" (
  for %%I in ("%FIRSTRAW%") do set "FIRSTABS=%%~fI"
) else if "%H2%"=="\\" (
  for %%I in ("%FIRSTRAW%") do set "FIRSTABS=%%~fI"
) else (
  for %%I in ("%~dp0.\%FIRSTRAW%") do set "FIRSTABS=%%~fI"
)

rem Get folder and filename
set "FIRSTDIR="
set "FIRSTNAME="
for %%I in ("%FIRSTABS%") do (
  set "FIRSTDIR=%%~dpI"
  set "FIRSTNAME=%%~nxI"
)

rem Detect if .part files exist
set "NEEDJOIN="
for %%P in ("%FIRSTDIR%%FIRSTNAME%.part*") do (
  set "NEEDJOIN=1"
  goto :after_probe
)
:after_probe

if not defined NEEDJOIN (
  echo [INFO] No .part files found. Nothing to join.
  exit /b 0
)

rem ===== Temporary PowerShell script path =====
set "TMP=%TEMP%\join_overwrite.ps1"
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1

rem ===== Create PowerShell joiner =====
> "%TMP%" echo param([Parameter(Mandatory=$true)][string]$BasePath)
>>"%TMP%" echo $ErrorActionPreference = 'Stop'
>>"%TMP%" echo function Join-Parts-Overwrite([string]$Base) {
>>"%TMP%" echo   $dir  = Split-Path -Path $Base -Parent
>>"%TMP%" echo   $name = [System.IO.Path]::GetFileName($Base)
>>"%TMP%" echo   if ([string]::IsNullOrWhiteSpace($dir) -or [string]::IsNullOrWhiteSpace($name)) { throw "Invalid base path: $Base" }
>>"%TMP%" echo   $pattern = "$name.part*"
>>"%TMP%" echo   $parts = Get-ChildItem -LiteralPath $dir -File -Filter $pattern ^| Where-Object { $_.Name -match '\.part\d+$' }
>>"%TMP%" echo   if (-not $parts -or $parts.Count -eq 0) { Write-Host "[SKIP] No parts found: $dir\$pattern"; return }
>>"%TMP%" echo   $ordered = $parts ^| Sort-Object { [int](([string]$_.Name) -replace '.*\.part(\d+)$', '$1') }
>>"%TMP%" echo   $outPath = Join-Path $dir $name
>>"%TMP%" echo   if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
>>"%TMP%" echo   $ofs = [System.IO.File]::Create($outPath)
>>"%TMP%" echo   [int64]$total = 0
>>"%TMP%" echo   try {
>>"%TMP%" echo     foreach ($p in $ordered) {
>>"%TMP%" echo       Write-Host ("[JOIN] " + $p.FullName)
>>"%TMP%" echo       $ifs = [System.IO.File]::OpenRead($p.FullName)
>>"%TMP%" echo       try {
>>"%TMP%" echo         $buf = New-Object byte[] 4194304
>>"%TMP%" echo         while (($n = $ifs.Read($buf,0,$buf.Length)) -gt 0) {
>>"%TMP%" echo           $ofs.Write($buf,0,$n)
>>"%TMP%" echo           $total += $n
>>"%TMP%" echo         }
>>"%TMP%" echo       } finally { $ifs.Dispose() }
>>"%TMP%" echo     }
>>"%TMP%" echo   } finally { $ofs.Dispose() }
>>"%TMP%" echo   Write-Host ("[OK] Rebuilt: " + $outPath + " (" + $total + " bytes)")
>>"%TMP%" echo   foreach ($p in $ordered) {
>>"%TMP%" echo     try {
>>"%TMP%" echo       Remove-Item -LiteralPath $p.FullName -Force
>>"%TMP%" echo       Write-Host ("[CLEAN] Deleted: " + $p.FullName)
>>"%TMP%" echo     } catch {
>>"%TMP%" echo       Write-Host ("[WARN] Failed to delete: " + $p.FullName + " - " + $_.Exception.Message)
>>"%TMP%" echo     }
>>"%TMP%" echo   }
>>"%TMP%" echo }
>>"%TMP%" echo try { Join-Parts-Overwrite -Base $BasePath } catch {
>>"%TMP%" echo   Write-Host ("[ERR] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message)
>>"%TMP%" echo   if ($_.InvocationInfo) { Write-Host ("[ERR] " + $_.InvocationInfo.PositionMessage) }
>>"%TMP%" echo   [Environment]::Exit(1)
>>"%TMP%" echo }

rem ===== Iterate list and join each =====
for /f "usebackq delims=" %%A in ("%LIST%") do (
  set "RAW=%%A"
  for /f "tokens=* delims= " %%Z in ("!RAW!") do set "RAW=%%Z"

  if defined RAW if not "!RAW:~0,1!"=="#" if not "!RAW:~0,1!"==";" (
    set "RAW=!RAW:"=!"
    set "RAW=!RAW:/=\!"

    set "FIRST2=!RAW:~0,2!"
    if "!FIRST2:~1,1!"==":" (
      for %%I in ("!RAW!") do set "FULL=%%~fI"
    ) else if "!FIRST2!"=="\\" (
      for %%I in ("!RAW!") do set "FULL=%%~fI"
    ) else (
      for %%I in ("%~dp0.\!RAW!") do set "FULL=%%~fI"
    )

    echo [CHECK/JOIN] "!FULL!"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP%" -BasePath "!FULL!"
  )
)

rem ===== Cleanup =====
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1
echo Done.
exit /b 0
