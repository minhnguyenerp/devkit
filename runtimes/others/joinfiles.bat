@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===== Settings =====
set "LIST=%~dp0listfile.txt"

rem ===== Check list file =====
if not exist "%LIST%" (
  echo [ERR] listfile.txt not found at: "%LIST%"
  exit /b 1
)

rem ===== Fixed temp PS1 path =====
set "TMP=%TEMP%\join_overwrite.ps1"
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1

rem ===== Create PowerShell joiner (auto-detect parts *.part####, overwrite) =====
> "%TMP%" echo param([Parameter(Mandatory=$true)][string]$BasePath)
>>"%TMP%" echo $ErrorActionPreference = 'Stop'
>>"%TMP%" echo function Join-Parts-Overwrite([string]$Base) {
>>"%TMP%" echo   # Derive dir and name; then look for "<name>.part####" in same dir
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
>>"%TMP%" echo }
>>"%TMP%" echo try { Join-Parts-Overwrite -Base $BasePath } catch {
>>"%TMP%" echo   Write-Host ("[ERR] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message)
>>"%TMP%" echo   if ($_.InvocationInfo) { Write-Host ("[ERR] " + $_.InvocationInfo.PositionMessage) }
>>"%TMP%" echo   [Environment]::Exit(1)
>>"%TMP%" echo }

rem ===== Iterate list: first token, normalize slashes, resolve relative to listfile folder, try join =====
for /f "usebackq tokens=1 delims= " %%A in ("%LIST%") do (
  set "RAW=%%~A"
  if defined RAW (
    set "RAW=!RAW:/=\!"
    set "FULL="
    set "FIRST2=!RAW:~0,2!"
    if "!FIRST2:~1,1!"==":" (
      for %%I in ("!RAW!") do set "FULL=%%~fI"
    ) else (
      if "!FIRST2!"=="\\" (
        for %%I in ("!RAW!") do set "FULL=%%~fI"
      ) else (
        for %%I in ("%~dp0!RAW!") do set "FULL=%%~fI"
      )
    )
    echo [CHECK/JOIN] "!FULL!"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP%" -BasePath "!FULL!"
  )
)

rem ===== Cleanup temp PS1 =====
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1

exit /b 0
