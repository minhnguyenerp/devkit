@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===== Settings =====
set "LIST=%~dp0listfile.txt"

rem ===== Check for list file =====
if not exist "%LIST%" (
  echo [ERR] listfile.txt not found at: "%LIST%"
  exit /b 1
)

rem ===== Temporary PowerShell script path =====
set "TMP=%TEMP%\split_45mb.ps1"
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1

rem ===== Create PowerShell splitter (45MB chunks, delete original after verified split) =====
> "%TMP%" echo param([Parameter(Mandatory=$true)][string]$InPath)
>>"%TMP%" echo $ErrorActionPreference = 'Stop'
>>"%TMP%" echo function Split-File45MB([string]$In) {
>>"%TMP%" echo   if (-not (Test-Path -LiteralPath $In -PathType Leaf)) { throw "Input file not found: $In" }
>>"%TMP%" echo   $dir  = Split-Path -LiteralPath $In
>>"%TMP%" echo   $name = [System.IO.Path]::GetFileName($In)
>>"%TMP%" echo   $chunkSize  = 45MB
>>"%TMP%" echo   $bufferSize = 4MB
>>"%TMP%" echo   $ifs = [System.IO.File]::OpenRead($In)
>>"%TMP%" echo   $origLen = $ifs.Length
>>"%TMP%" echo   $created = New-Object System.Collections.Generic.List[string]
>>"%TMP%" echo   try {
>>"%TMP%" echo     $part = 0
>>"%TMP%" echo     while ($ifs.Position -lt $ifs.Length) {
>>"%TMP%" echo       $part++
>>"%TMP%" echo       $out = Join-Path $dir ("{0}.part{1:0000}" -f $name, $part)
>>"%TMP%" echo       $ofs = [System.IO.File]::Create($out)
>>"%TMP%" echo       try {
>>"%TMP%" echo         [int64]$written = 0
>>"%TMP%" echo         $buf = New-Object byte[] $bufferSize
>>"%TMP%" echo         while ( ($written -lt $chunkSize) -and ($ifs.Position -lt $ifs.Length) ) {
>>"%TMP%" echo           $toRead = [int][Math]::Min($bufferSize, [int]($chunkSize - $written))
>>"%TMP%" echo           $remain = [int]([int64]$ifs.Length - [int64]$ifs.Position)
>>"%TMP%" echo           if ($toRead -gt $remain) { $toRead = $remain }
>>"%TMP%" echo           if ($toRead -le 0) { break }
>>"%TMP%" echo           $n = $ifs.Read($buf,0,$toRead)
>>"%TMP%" echo           if ($n -le 0) { break }
>>"%TMP%" echo           $ofs.Write($buf,0,$n)
>>"%TMP%" echo           $written += $n
>>"%TMP%" echo         }
>>"%TMP%" echo       } finally { $ofs.Dispose() }
>>"%TMP%" echo       $created.Add($out) ^| Out-Null
>>"%TMP%" echo       Write-Host "[OK] Created: $out"
>>"%TMP%" echo     }
>>"%TMP%" echo   } finally { $ifs.Dispose() }
>>"%TMP%" echo
>>"%TMP%" echo   # Verify file size
>>"%TMP%" echo   [int64]$sum = 0
>>"%TMP%" echo   foreach ($p in $created) { $sum += (Get-Item -LiteralPath $p).Length }
>>"%TMP%" echo   if ($created.Count -eq 0) { throw "No parts were created." }
>>"%TMP%" echo   if ($sum -ne $origLen) {
>>"%TMP%" echo     throw "Verification failed: sum(parts)=$sum bytes != original=$origLen bytes. Original file NOT deleted."
>>"%TMP%" echo   }
>>"%TMP%" echo
>>"%TMP%" echo   # Delete original only after successful verification
>>"%TMP%" echo   Remove-Item -LiteralPath $In -Force
>>"%TMP%" echo   Write-Host "[OK] Original deleted: $In"
>>"%TMP%" echo }
>>"%TMP%" echo try { Split-File45MB -In $InPath } catch {
>>"%TMP%" echo   Write-Host ("[ERR] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message)
>>"%TMP%" echo   if ($_.InvocationInfo) { Write-Host ("[ERR] " + $_.InvocationInfo.PositionMessage) }
>>"%TMP%" echo   [Environment]::Exit(1)
>>"%TMP%" echo }

rem ===== Iterate list (keep spaces), normalize, resolve, split =====
for /f "usebackq delims=" %%A in ("%LIST%") do (
  set "RAW=%%A"

  rem Trim leading spaces
  for /f "tokens=* delims= " %%Z in ("!RAW!") do set "RAW=%%Z"

  rem Skip empty or comment lines (# or ;)
  if defined RAW if not "!RAW:~0,1!"=="#" if not "!RAW:~0,1!"==";" (

    rem Remove all double quotes
    set "RAW=!RAW:"=!"

    rem Normalize slashes
    set "RAW=!RAW:/=\!"

    rem Resolve to absolute path
    set "FIRST2=!RAW:~0,2!"
    if "!FIRST2:~1,1!"==":" (
      rem Absolute path
      for %%I in ("!RAW!") do set "FULL=%%~fI"
    ) else if "!FIRST2!"=="\\" (
      rem UNC path \\server\share
      for %%I in ("!RAW!") do set "FULL=%%~fI"
    ) else (
      rem Relative to listfile folder
      for %%I in ("%~dp0.\!RAW!") do set "FULL=%%~fI"
    )

    if exist "!FULL!" (
      echo [SPLIT] "!FULL!"
      powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP%" -InPath "!FULL!"
      if errorlevel 1 echo [ERR] Split failed: "!FULL!"
    ) else (
      echo [WARN] File not found, skipped: "!FULL!"
    )
  )
)

rem ===== Cleanup temporary PowerShell file =====
if exist "%TMP%" del /f /q "%TMP%" >nul 2>&1

exit /b 0
