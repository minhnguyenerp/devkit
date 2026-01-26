# ---------------------------------------------------------------------------------------------
#   Copyright (c) Microsoft Corporation. All rights reserved.
#   Licensed under the MIT License. See License.txt in the project root for license information.
# ---------------------------------------------------------------------------------------------

# Prevent installing more than once per session
if ((Test-Path variable:global:__VSCodeState) -and $null -ne $Global:__VSCodeState.OriginalPrompt) {
	return;
}

# Disable shell integration when the language mode is restricted
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
	return;
}

$Global:__VSCodeState = @{
	OriginalPrompt = $function:Prompt
	LastHistoryId = -1
	IsInExecution = $false
	EnvVarsToReport = @()
	Nonce = $null
	IsStable = $null
	IsA11yMode = $null
	IsWindows10 = $false
}

# Store the nonce in a regular variable and unset the environment variable. It's by design that
# anything that can execute PowerShell code can read the nonce, as it's basically impossible to hide
# in PowerShell. The most important thing is getting it out of the environment.
$Global:__VSCodeState.Nonce = $env:VSCODE_NONCE
$env:VSCODE_NONCE = $null

$Global:__VSCodeState.IsStable = $env:VSCODE_STABLE
$env:VSCODE_STABLE = $null

$Global:__VSCodeState.IsA11yMode = $env:VSCODE_A11Y_MODE
$env:VSCODE_A11Y_MODE = $null

$__vscode_shell_env_reporting = $env:VSCODE_SHELL_ENV_REPORTING
$env:VSCODE_SHELL_ENV_REPORTING = $null
if ($__vscode_shell_env_reporting) {
	$Global:__VSCodeState.EnvVarsToReport = $__vscode_shell_env_reporting.Split(',')
}
Remove-Variable -Name __vscode_shell_env_reporting -ErrorAction SilentlyContinue

$osVersion = [System.Environment]::OSVersion.Version
$Global:__VSCodeState.IsWindows10 = $IsWindows -and $osVersion.Major -eq 10 -and $osVersion.Minor -eq 0 -and $osVersion.Build -lt 22000
Remove-Variable -Name osVersion -ErrorAction SilentlyContinue

if ($env:VSCODE_ENV_REPLACE) {
	$Split = $env:VSCODE_ENV_REPLACE.Split(":")
	foreach ($Item in $Split) {
		$Inner = $Item.Split('=', 2)
		[Environment]::SetEnvironmentVariable($Inner[0], $Inner[1].Replace('\x3a', ':'))
	}
	$env:VSCODE_ENV_REPLACE = $null
}
if ($env:VSCODE_ENV_PREPEND) {
	$Split = $env:VSCODE_ENV_PREPEND.Split(":")
	foreach ($Item in $Split) {
		$Inner = $Item.Split('=', 2)
		[Environment]::SetEnvironmentVariable($Inner[0], $Inner[1].Replace('\x3a', ':') + [Environment]::GetEnvironmentVariable($Inner[0]))
	}
	$env:VSCODE_ENV_PREPEND = $null
}
if ($env:VSCODE_ENV_APPEND) {
	$Split = $env:VSCODE_ENV_APPEND.Split(":")
	foreach ($Item in $Split) {
		$Inner = $Item.Split('=', 2)
		[Environment]::SetEnvironmentVariable($Inner[0], [Environment]::GetEnvironmentVariable($Inner[0]) + $Inner[1].Replace('\x3a', ':'))
	}
	$env:VSCODE_ENV_APPEND = $null
}

# Register Python shell activate hooks
# Prevent multiple activation with guard
if (-not $env:VSCODE_PYTHON_AUTOACTIVATE_GUARD) {
	$env:VSCODE_PYTHON_AUTOACTIVATE_GUARD = '1'
	if ($env:VSCODE_PYTHON_PWSH_ACTIVATE -and $env:TERM_PROGRAM -eq 'vscode') {
		$activateScript = $env:VSCODE_PYTHON_PWSH_ACTIVATE
		Remove-Item Env:VSCODE_PYTHON_PWSH_ACTIVATE

		try {
			Invoke-Expression $activateScript
			$Global:__VSCodeState.OriginalPrompt = $function:Prompt
		}
		catch {
			$activationError = $_
			Write-Host "`e[0m`e[7m * `e[0;103m VS Code Python powershell activation failed with exit code $($activationError.Exception.Message) `e[0m"
		}
	}
}

function Global:__VSCode-Escape-Value([string]$value) {
	# NOTE: In PowerShell v6.1+, this can be written `$value -replace '…', { … }` instead of `[regex]::Replace`.
	# Replace any non-alphanumeric characters.
	[regex]::Replace($value, "[$([char]0x00)-$([char]0x1f)\\\n;]", { param($match)
			# Encode the (ascii) matches as `\x<hex>`
			-Join (
				[System.Text.Encoding]::UTF8.GetBytes($match.Value) | ForEach-Object { '\x{0:x2}' -f $_ }
			)
		})
}

function Global:Prompt() {
	$FakeCode = [int]!$global:?
	# NOTE: We disable strict mode for the scope of this function because it unhelpfully throws an
	# error when $LastHistoryEntry is null, and is not otherwise useful.
	Set-StrictMode -Off
	$LastHistoryEntry = Get-History -Count 1
	$Result = ""
	# Skip finishing the command if the first command has not yet started or an execution has not
	# yet begun
	if ($Global:__VSCodeState.LastHistoryId -ne -1 -and ($Global:__VSCodeState.HasPSReadLine -eq $false -or $Global:__VSCodeState.IsInExecution -eq $true)) {
		$Global:__VSCodeState.IsInExecution = $false
		if ($LastHistoryEntry.Id -eq $Global:__VSCodeState.LastHistoryId) {
			# Don't provide a command line or exit code if there was no history entry (eg. ctrl+c, enter on no command)
			$Result += "$([char]0x1b)]633;D`a"
		}
		else {
			# Command finished exit code
			# OSC 633 ; D [; <ExitCode>] ST
			$Result += "$([char]0x1b)]633;D;$FakeCode`a"
		}
	}
	# Prompt started
	# OSC 633 ; A ST
	$Result += "$([char]0x1b)]633;A`a"
	# Current working directory
	# OSC 633 ; <Property>=<Value> ST
	$Result += if ($pwd.Provider.Name -eq 'FileSystem') { "$([char]0x1b)]633;P;Cwd=$(__VSCode-Escape-Value $pwd.ProviderPath)`a" }

	# Send current environment variables as JSON
	# OSC 633 ; EnvJson ; <Environment> ; <Nonce>
	if ($Global:__VSCodeState.EnvVarsToReport.Count -gt 0) {
		$envMap = @{}
        foreach ($varName in $Global:__VSCodeState.EnvVarsToReport) {
            if (Test-Path "env:$varName") {
                $envMap[$varName] = (Get-Item "env:$varName").Value
            }
        }
        $envJson = $envMap | ConvertTo-Json -Compress
        $Result += "$([char]0x1b)]633;EnvJson;$(__VSCode-Escape-Value $envJson);$($Global:__VSCodeState.Nonce)`a"
	}

	# Before running the original prompt, put $? back to what it was:
	if ($FakeCode -ne 0) {
		Write-Error "failure" -ea ignore
	}
	# Run the original prompt
	$OriginalPrompt += $Global:__VSCodeState.OriginalPrompt.Invoke()
	$Result += $OriginalPrompt

	# Prompt
	# OSC 633 ; <Property>=<Value> ST
	if ($Global:__VSCodeState.IsStable -eq "0") {
		$Result += "$([char]0x1b)]633;P;Prompt=$(__VSCode-Escape-Value $OriginalPrompt)`a"
	}

	# Write command started
	$Result += "$([char]0x1b)]633;B`a"
	$Global:__VSCodeState.LastHistoryId = $LastHistoryEntry.Id
	return $Result
}

# Report prompt type
if ($env:STARSHIP_SESSION_KEY) {
	[Console]::Write("$([char]0x1b)]633;P;PromptType=starship`a")
}
elseif ($env:POSH_SESSION_ID) {
	[Console]::Write("$([char]0x1b)]633;P;PromptType=oh-my-posh`a")
}
elseif ((Test-Path variable:global:GitPromptSettings) -and $Global:GitPromptSettings) {
	[Console]::Write("$([char]0x1b)]633;P;PromptType=posh-git`a")
}

if ($Global:__VSCodeState.IsA11yMode -eq "1") {
	if (-not (Get-Module -Name PSReadLine)) {
		$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
		$specialPsrlPath = Join-Path $scriptRoot 'psreadline'
		Import-Module $specialPsrlPath
		if (Get-Module -Name PSReadLine) {
			Set-PSReadLineOption -EnableScreenReaderMode
		}
	}
}

# Only send the command executed sequence when PSReadLine is loaded, if not shell integration should
# still work thanks to the command line sequence
$Global:__VSCodeState.HasPSReadLine = $false
if (Get-Module -Name PSReadLine) {
	$Global:__VSCodeState.HasPSReadLine = $true
	[Console]::Write("$([char]0x1b)]633;P;HasRichCommandDetection=True`a")

	$Global:__VSCodeState.OriginalPSConsoleHostReadLine = $function:PSConsoleHostReadLine
	function Global:PSConsoleHostReadLine {
		$CommandLine = $Global:__VSCodeState.OriginalPSConsoleHostReadLine.Invoke()
		$Global:__VSCodeState.IsInExecution = $true

		# Command line
		# OSC 633 ; E [; <CommandLine> [; <Nonce>]] ST
		$Result = "$([char]0x1b)]633;E;"
		$Result += $(__VSCode-Escape-Value $CommandLine)
		# Only send the nonce if the OS is not Windows 10 as it seems to echo to the terminal
		# sometimes
		if ($Global:__VSCodeState.IsWindows10 -eq $false) {
			$Result += ";$($Global:__VSCodeState.Nonce)"
		}
		$Result += "`a"

		# Command executed
		# OSC 633 ; C ST
		$Result += "$([char]0x1b)]633;C`a"

		# Write command executed sequence directly to Console to avoid the new line from Write-Host
		[Console]::Write($Result)

		$CommandLine
	}

	# Set ContinuationPrompt property
	$Global:__VSCodeState.ContinuationPrompt = (Get-PSReadLineOption).ContinuationPrompt
	if ($Global:__VSCodeState.ContinuationPrompt) {
		[Console]::Write("$([char]0x1b)]633;P;ContinuationPrompt=$(__VSCode-Escape-Value $Global:__VSCodeState.ContinuationPrompt)`a")
	}
}

# Set IsWindows property
if ($PSVersionTable.PSVersion -lt "6.0") {
	# Windows PowerShell is only available on Windows
	[Console]::Write("$([char]0x1b)]633;P;IsWindows=$true`a")
}
else {
	[Console]::Write("$([char]0x1b)]633;P;IsWindows=$IsWindows`a")
}

# Set always on key handlers which map to default VS Code keybindings
function Set-MappedKeyHandler {
	param ([string[]] $Chord, [string[]]$Sequence)
	try {
		$Handler = Get-PSReadLineKeyHandler -Chord $Chord | Select-Object -First 1
	}
 catch [System.Management.Automation.ParameterBindingException] {
		# PowerShell 5.1 ships with PSReadLine 2.0.0 which does not have -Chord,
		# so we check what's bound and filter it.
		$Handler = Get-PSReadLineKeyHandler -Bound | Where-Object -FilterScript { $_.Key -eq $Chord } | Select-Object -First 1
	}
	if ($Handler) {
		Set-PSReadLineKeyHandler -Chord $Sequence -Function $Handler.Function
	}
}

function Set-MappedKeyHandlers {
	Set-MappedKeyHandler -Chord Ctrl+Spacebar -Sequence 'F12,a'
	Set-MappedKeyHandler -Chord Alt+Spacebar -Sequence 'F12,b'
	Set-MappedKeyHandler -Chord Shift+Enter -Sequence 'F12,c'
	Set-MappedKeyHandler -Chord Shift+End -Sequence 'F12,d'
}

if ($Global:__VSCodeState.HasPSReadLine) {
	Set-MappedKeyHandlers

	# Prevent AI-executed commands from polluting shell history
	if ($env:VSCODE_PREVENT_SHELL_HISTORY -eq "1") {
		Set-PSReadLineOption -AddToHistoryHandler {
			param([string]$line)
			return $false
		}
		$env:VSCODE_PREVENT_SHELL_HISTORY = $null
	}
}

# SIG # Begin signature block
# MIIuyQYJKoZIhvcNAQcCoIIuujCCLrYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCxDp4elC29755L
# KJQ2aU67SyQEC8dg7cAK7ki+1MWtkqCCFAgwggYiMIIECqADAgECAhMzAAAAOqVM
# eg/pLY5WAAEAAAA6MA0GCSqGSIb3DQEBCwUAMIGHMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTEwLwYDVQQDEyhNaWNyb3NvZnQgTWFya2V0cGxh
# Y2UgUHJvZHVjdGlvbiBDQSAyMDExMB4XDTI1MDYxOTE4NTQxNVoXDTI2MDYxNzE4
# NTQxNVowdDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEeMBwG
# A1UEAxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAt+78Zgve1ubGrUDoN6b38AwwRTsG3Se8MLvV19OCgewrUcuR
# EcXHc5cdJM/anZ826GOGXAjdDRwOZVDMHROsFKj2PICU012e5Hjs+p6vwaBPnnnB
# uUuydZaIp2WNSmN/asrooD6J8uQRHGsPbHXCJ6YpJVQoYSWRRVM84NQGv4eSHs0d
# 5oV3V4YTHoZ8Fd3pCARGU+y26WKuqJZKw1QIJQ8cbeQYG3YYLDGAg7FHme8QdOU6
# lB9j8dyYQ5QKsBTcLaHipJjTOs8Xk97Vlp/UdY5AwzynG9BoPiQhpiyuL+txj+tV
# de6H/sixUoHpHkR4bwbtZ2SEmwVnQ8+RdYhWnQIDAQABo4IBlzCCAZMwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFLGyVe1sw+70Uzk4ufV2dFPjDoVJMEUG
# A1UdEQQ+MDykOjA4MR4wHAYDVQQLExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xFjAU
# BgNVBAUTDTIyOTk3OSs1MDUyOTYwHwYDVR0jBBgwFoAUnqf5oCNwnxHFaeOhjQr6
# 8bD01YAwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwTWFya2V0cGxhY2UlMjBQcm9kdWN0aW9u
# JTIwQ0ElMjAyMDExKDEpLmNybDB5BggrBgEFBQcBAQRtMGswaQYIKwYBBQUHMAKG
# XWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0
# JTIwTWFya2V0cGxhY2UlMjBQcm9kdWN0aW9uJTIwQ0ElMjAyMDExKDEpLmNydDAM
# BgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBBpSDW5NL6rmKT8ftzHOR+
# JbUg6yHKn19WmtZ6eowhPYG8m9cMpGM2+/6eXjX87Pf3UHC0Gqdg/DXnjavS3QAX
# qCLktsYiPdG877xNK3pWA25ZoP6hyIjeh/iFhqCgLDAHERBEb3hghPGep9jTQDxz
# S550721TvdZzLdYuaDKa11J1jxSgX5hKAkWrjHo/rfqSROLcP58zAXeOHPzUKrXW
# mVskEMnczZRTkFBQunCnikWTV8KKap5mNh59Go/Q8TSHvvRudMljYgOQrQZnFQAK
# /v0NOGv81z0jb5yRnK2A+T9SUviNiKtjo7zzproy3vBYdeWWontlFQqhIcSnd1Np
# MjYJEC0PHDS2JdvaJtjyYlPH5+xjAKDQztSazXte0IRyhCnz8dnmJMXzh+zd0hTk
# EuZ8l+3dphYb5CXBVvw7PhkOlAP5zOqPHi9nzuwK/iS4E4iZM5IdI+WY5H6jtzfk
# VxkoaEL6LTMs2bRBgj1eFsi2W/Eiqx0WBjoEFFPRiXTHb0rVLZOM1nbQ4lREsl8d
# pCJhQEBUYt5s6CsPRucMGHP+o4Uy/X2+IWaxxjWNXsc3PEYJGcOgQkp4gbPTQ29h
# YszDwvw9rDlA1X32AENHkJNh7V1EahIdciW/tzKQCf5BIKaYrWAY5Gefp+4iGmcN
# sIiGN7Lh/3VlyxF6dkMPFTCCBtcwggS/oAMCAQICCmESRKIAAAAAAAIwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDExMB4XDTExMDMyODIxMDkzOVoXDTMxMDMyODIxMTkzOVowfTELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEnMCUGA1UEAxMeTWljcm9zb2Z0IE1h
# cmtldFBsYWNlIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKC
# AgEAubUaSwGYVsE3MAnPfvmozUhAB3qxBABgJRW1vDp4+tVinXxD32f7k1K89JQ6
# zDOgS/iDgULC+yFK1K/1Qjac/0M7P6c8v5LSjnWGlERLa/qY32j46S7SLQcit3g2
# jgoTTO03eUG+9yHZUTGV/FJdRYB8uXhrznJBa+Y+yGwiQKF+m6XFeBH/KORoKFx+
# dmMoy9EWJ/m/o9IiUj2kzm9C691+vZ/I2w0Bj93W9SPPkV2PCNHlzgfIAoeajWpH
# mi38Wi3xZHonkzAVBHxPsCBppOoNsWvmAfUM7eBthkSPvFruekyDCPNEYhfGqgqt
# qLkoBebXLZCOVybF7wTQaLvse60//3P003icRcCoQYgY4NAqrF7j80o5U7DkeXxc
# B0xvengsaKgiAaV1DKkRbpe98wCqr1AASvm5rAJUYMU+mXmOieV2EelY2jGrenWe
# 9FQpNXYV1NoWBh0WKoFxttoWYAnF705bIWtSZsz08ZfK6WLX4GXNLcPBlgCzfTm1
# sdKYASWdBbH2haaNhPapFhQQBJHKwnVW2iXErImhuPi45W3MVTZ5D9ASshZx69cL
# YY6xAdIa+89Kf/uRrsGOVZfahDuDw+NI183iAyzC8z/QRt2P32LYxP0xrCdqVh+D
# Jo2i4NoE8Uk1usCdbVRuBMBQl/AwpOTq7IMvHGElf65CqzUCAwEAAaOCAUswggFH
# MBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQPU8s/FmEl/mCJHdO5fOiQrbOU
# 0TAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0T
# AQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBaBgNV
# HR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9w
# cm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsGAQUF
# BwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MA0GCSqGSIb3
# DQEBCwUAA4ICAQCjuZmM8ZVNDgp9wHsL4RY8KJ8nLinvxFTphNGCrxaLknkYG5pm
# MhVlX+UB/tSiW8W13W60nggz9u5xwMx7v/1t/Tgm6g2brVyOKI5A7u6/2SIJwkJK
# Fw953K0YIKVT28w9zl8dSJnmRnyR0G86ncWbF6CLQ6A6lBQ9o2mTGVqDr4m35WKA
# nc6YxUUM1y74mbzFFZr63VHsCcOp3pXWnUqAY1rb6Q6NX1b3clncKqLFm0EjKHcQ
# 56grTbwuuB7pMdh/IFCJR01MQzQbDtpEisbOeZUi43YVAAHKqI1EO9bRwg3frCjw
# Abml9MmI4utMW94gWFgvrMxIX+n42RBDIjf3Ot3jkT6gt3XeTTmO9bptgblZimhE
# RdkFRUFpVtkocJeLoGuuzP93uH/Yp032wzRH+XmMgujfZv+vnfllJqxdowoQLx55
# FxLLeTeYfwi/xMSjZO2gNven3U/3KeSCd1kUOFS3AOrwZ0UNOXJeW5JQC6Vfd1Ba
# vFZ6FAta1fMLu3WFvNB+FqeHUaU3ya7rmtxJnzk29DeSqXgGNmVSywBS4NajI5jJ
# IKAA6UhNJlsg8CHYwUOKf5ej8OoQCkbadUxXygAfxCfW2YBbujtI+PoyejRFxWUj
# YFWO5LeTI62UMyqfOEiqugoYjNxmQZla2s4YHVuqIC34R85FQlg9pKQBsDCCBwMw
# ggTroAMCAQICEzMAAABVyAZrOCOXKQkAAAAAAFUwDQYJKoZIhvcNAQELBQAwfTEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEnMCUGA1UEAxMeTWlj
# cm9zb2Z0IE1hcmtldFBsYWNlIFBDQSAyMDExMB4XDTIxMDkwOTIyNDIzMFoXDTMw
# MDkwOTIyNTIzMFowgYcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xMTAvBgNVBAMTKE1pY3Jvc29mdCBNYXJrZXRwbGFjZSBQcm9kdWN0aW9uIENB
# IDIwMTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDHfQ3P+L0El1S6
# JNYAz70y3e1i7EZAYcCDVXde/nQdpOKtVr6H4QkBkROv7HBxY0U8lR9C3bUUZKn6
# CCcN3v3bQuYKu1Ff2G4nIIr8a1cB4iOU8i4YSN7bRr+5LvD5hyCfJHqXrJe5LRRG
# jws5aRAxYuGhQ3ypWPEZYfrIXmmYK+e+udApgxahHUPBqcbI2PT1PpkKDgqR7hyz
# W0CfWzRUwh+YoZpsVvDaEkxcHQe/yGJB5BluYyRm5K9z+YQqBvYJkNUisTE/9OIm
# naZqoujkEuhM5bBV/dNjw7YN37OcBuH0NvlQomLQo+V7PA519HVVE1kRQ8pFad6i
# 4YdRWpj/+1yFskRZ5m7y+dEdGyXAiFeIgaM6O1CFrA1LbMAvyaZpQwBkrT/etC0h
# w4BPmW70zSmSubMoHpx/UUTNo3fMUVqx6r2H1xsc4aXTpPN5IxjkGIQhPN6h3q5J
# C+JOPnsfDRg3Ive2Q22jj3tkNiOXrYpmkILk7v+4XUxDErdc/WLZ3sbF27hug7HS
# VbTCNA46scIqE7ZkgH3M7+8aP3iUBDNcYUWjO1u+P1Q6UUzFdShSbGbKf+Z3xpql
# wdxQq9kuUahACRQLMFjRUfmAqGXUdMXECRaFPTxl6SB/7IAcuK855beqNPcexVEp
# kSZxZJbnqjKWbyTk/GA1abW8zgfH2QIDAQABo4IBbzCCAWswEgYJKwYBBAGCNxUB
# BAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUeBlfau2VIfkwk2K+EoAD6hZ05ccwHQYD
# VR0OBBYEFJ6n+aAjcJ8RxWnjoY0K+vGw9NWAMBkGCSsGAQQBgjcUAgQMHgoAUwB1
# AGIAQwBBMAsGA1UdDwQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMB8GA1UdIwQY
# MBaAFA9Tyz8WYSX+YIkd07l86JCts5TRMFcGA1UdHwRQME4wTKBKoEiGRmh0dHA6
# Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY01hclBDQTIw
# MTFfMjAxMS0wMy0yOC5jcmwwWwYIKwYBBQUHAQEETzBNMEsGCCsGAQUFBzAChj9o
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY01hclBDQTIwMTFf
# MjAxMS0wMy0yOC5jcnQwDQYJKoZIhvcNAQELBQADggIBACY4RaglNFzKOO+3zgaz
# CsgCvXca79D573wDc0DAj6KzBX9m4rHhAZqzBkfSWvanLFilDibWmbGUGbkuH0y2
# 9NEoLVHfY64PXmXcBWEWd1xK4QxyKx2VVDq9P9494Z/vXy9OsifTP8Gt2UkhftAQ
# McvKgGiAHtyRHda8r7oU4cc4ITZnMsgXv6GnMDVuIk+Cq0Eh93rgzKF2rJ1sJcra
# H/kgSkgawBYYdJlXXHTkOrfEPKU82BDT5h8SGsXVt5L1mwRzjVQRLs1FNPkA+Kqy
# z0L+UEXJZWldNtHC79XtYh/ysRov4Yu/wLF+c8Pm15ICn8EYJUL4ZKmk9ZM7ZcaU
# V/2XvBpufWE2rcMnS/dPHWIojQ1FTToqM+Ag2jZZ33fl8rJwnnIF/Ku4OZEN24wQ
# LYsOMHh6WKADxkXJhiYUwBe2vCMHDVLpbCY7CbPpQdtBYHEkto0MFADdyX50sNVg
# TKboPyCxPW6GLiR5R+qqzNRzpYru2pTsM6EodSTgcMbeaDZI7ssnv+NYMyWstE1I
# XQCUywLQohNDo6H7/HNwC8HtdsGd5j0j+WOIEO5PyCbjn5viNWWCUu7Ko6Qx68Nu
# xHf++swe9YQhufh0hzJnixidTRPkBUgYQ6xubG6I5g/2OO1BByOu9/jt5vMTTvct
# q2YWOhUjoOZPe53eYSzjvNydMYIaFzCCGhMCAQEwgZ8wgYcxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMTAvBgNVBAMTKE1pY3Jvc29mdCBNYXJr
# ZXRwbGFjZSBQcm9kdWN0aW9uIENBIDIwMTECEzMAAAA6pUx6D+ktjlYAAQAAADow
# DQYJYIZIAWUDBAIBBQCggbAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYK
# KwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKSrtvHn
# Wz0t+05Bo+kPvXdf20Bu5G1KMlK8DmxiNR7vMEQGCisGAQQBgjcCAQwxNjA0oBCA
# DgBWAFMAIABDAG8AZABloSCAHmh0dHBzOi8vY29kZS52aXN1YWxzdHVkaW8uY29t
# LzANBgkqhkiG9w0BAQEFAASCAQBR2eJ+r+jG1/QgYJTuzJQFqBDLLaX93zOByM4e
# iJrR5YnJAWVsA7uwuM5GK/E1xprDSQgriQvR+BK8PSZD2gW56VpwtV/O0oB0OF8E
# arL4Joyn5L2ejR4J/2ALL8oBfUOTc0x7weSSQwIwT0gkpUbEpFeJQ9rGQ4w6O5IO
# ZbGPtI6a+v+N2GLbDU/FAZyf0Mh/dDxNSQz4fCXddW5wcCMJpM4IShLONQ1f1YhP
# tX/oBDRXgn/d+gtbg7+6r+jSWWUGeDUzGTNr4io/Q3WcSzzLl2zmQS9BTTcUXz/g
# 7Nx+yhoB3nXckXryJ1bXEtavsMCZRYsTu/Q3reEU0OAv3JKzoYIXlTCCF5EGCisG
# AQQBgjcDAwExgheBMIIXfQYJKoZIhvcNAQcCoIIXbjCCF2oCAQMxDzANBglghkgB
# ZQMEAgEFADCCAVAGCyqGSIb3DQEJEAEEoIIBPwSCATswggE3AgEBBgorBgEEAYRZ
# CgMBMDEwDQYJYIZIAWUDBAIBBQAEIFlN/9iJ3ERdXJMRjG3T2uxpot5ozrNVaV6p
# kTMk7TkbAgZpaRNFx9UYETIwMjYwMTIxMTQxNTUyLjFaMASAAgH0oIHRpIHOMIHL
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRT
# UyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAgh4nVhdksfZUgABAAAC
# CDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0yNTAxMzAxOTQyNTNaFw0yNjA0MjIxOTQyNTNaMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1y3AI5lIz3Ip1nK5BMUUbGRsj
# SnCz/VGs33zvY0NeshsPgfld3/Z3/3dS8WKBLlDlosmXJOZlFSiNXUd6DTJxA9ik
# /ZbCdWJ78LKjbN3tFkX2c6RRpRMpA8sq/oBbRryP3c8Q/gxpJAKHHz8cuSn7ewfC
# LznNmxqliTk3Q5LHqz2PjeYKD/dbKMBT2TAAWAvum4z/HXIJ6tFdGoNV4WURZswC
# St6ROwaqQ1oAYGvEndH+DXZq1+bHsgvcPNCdTSIpWobQiJS/UKLiR02KNCqB4I9y
# ajFTSlnMIEMz/Ni538oGI64phcvNpUe2+qaKWHZ8d4T1KghvRmSSF4YF5DNEJbxa
# CUwsy7nULmsFnTaOjVOoTFWWfWXvBuOKkBcQKWGKvrki976j4x+5ezAP36fq3u6d
# HRJTLZAu4dEuOooU3+kMZr+RBYWjTHQCKV+yZ1ST0eGkbHXoA2lyyRDlNjBQcoeZ
# IxWCZts/d3+nf1jiSLN6f6wdHaUz0ADwOTQ/aEo1IC85eFePvyIKaxFJkGU2Mqa6
# Xzq3qCq5tokIHtjhogsrEgfDKTeFXTtdhl1IPtLcCfMcWOGGAXosVUU7G948F6W9
# 6424f2VHD8L3FoyAI9+r4zyIQUmqiESzuQWeWpTTjFYwCmgXaGOuSDV8cNOVQB6I
# PzPneZhVTjwxbAZlaQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFKMx4vfOqcUTgYOV
# B9f18/mhegFNMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1Ud
# HwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3Js
# L01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggr
# BgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIw
# MTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgw
# DgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQBRszKJKwAfswqdaQPF
# iaYB/ZNAYWDa040XTcQsCaCua5nsG1IslYaSpH7miTLr6eQEqXczZoqeOa/xvDnM
# GifGNda0CHbQwtpnIhsutrKO2jhjEaGwlJgOMql21r7Ik6XnBza0e3hBOu4UBkMl
# /LEX+AURt7i7+RTNsGN0cXPwPSbTFE+9z7WagGbY9pwUo/NxkGJseqGCQ/9K2VMU
# 74bw5e7+8IGUhM2xspJPqnSeHPhYmcB0WclOxcVIfj/ZuQvworPbTEEYDVCzSN37
# c0yChPMY7FJ+HGFBNJxwd5lKIr7GYfq8a0gOiC2ljGYlc4rt4cCed1XKg83f0l9a
# UVimWBYXtfNebhpfr6Lc3jD8NgsrDhzt0WgnIdnTZCi7jxjsIBilH99pY5/h6bQc
# LKK/E6KCP9E1YN78fLaOXkXMyO6xLrvQZ+uCSi1hdTufFC7oSB/CU5RbfIVHXG0j
# 1o2n1tne4eCbNfKqUPTE31tNbWBR23Yiy0r3kQmHeYE1GLbL4pwknqaip1BRn6WI
# UMJtgncawEN33f8AYGZ4a3NnHopzGVV6neffGVag4Tduy+oy1YF+shChoXdMqfhP
# WFpHe3uJGT4GJEiNs4+28a/wHUuF+aRaR0cN5P7XlOwU1360iUCJtQdvKQaNAwGI
# 29KOwS3QGriR9F2jOGPUAlpeEzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkA
# AAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRl
# IEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVow
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX
# 9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1q
# UoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8d
# q6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byN
# pOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2k
# rnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4d
# Pf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgS
# Uei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8
# QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6Cm
# gyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzF
# ER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQID
# AQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQU
# KqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1
# GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0
# bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMA
# QTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbL
# j+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1p
# Y3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0w
# Ni0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIz
# LmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwU
# tj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN
# 3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU
# 5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5
# KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGy
# qVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB6
# 2FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltE
# AY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFp
# AUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcd
# FYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRb
# atGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQd
# VTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1E
# OTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEw
# BwYFKw4DAhoDFQCNkvu0NKcSjdYKyrhJZcsyXOUTNKCBgzCBgKR+MHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7RrRzzAiGA8y
# MDI2MDEyMTA0MTcxOVoYDzIwMjYwMTIyMDQxNzE5WjB3MD0GCisGAQQBhFkKBAEx
# LzAtMAoCBQDtGtHPAgEAMAoCAQACAgxzAgH/MAcCAQACAhJGMAoCBQDtHCNPAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBACxf+8tqiHCE80HVMSCAU2zCAxUi
# 4Bh24YYKpTiqLzGJLt/UI8URdjMfYXm41BIRgGck4y2tG5hHYsANUdAUwP7TSZFR
# SqWMxJF3gl6+SEN0sxtxegG3f1BJyV0vuNpHTHopOrT2gtg3Dg96WOcFfNQejdPk
# MAdajg5B3P9Wf0BSHR8OHc2CySObTZJYtA4Xxd4s4DYAyMeMbdQBbPeULGeT71vb
# uumKdV0ZmReBQ4TkxDFh4+Ks8pVBkXA7QIdc21XIXAWBIG4bjVZmGUlM/Uce3XZ2
# whc9gb5ttn9Et09DGNljiBsqQZ8c0FDMONlogM8aGMClOwKvUsBqPht0CUcxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAgh4
# nVhdksfZUgABAAACCDANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCEirdQf73RF8R4UpRm0i0Hbi1R
# 1ythqcojxCcJOKXxYDCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EII//jm8J
# Ha2W1O9778t9+Ft2Z5NmKqttPk6Q+9RRpmepMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAIIeJ1YXZLH2VIAAQAAAggwIgQgiMhw9kMy
# EuV8ErAO96n7UyIoCGTFpl8X/G3Er2TpkZcwDQYJKoZIhvcNAQELBQAEggIANbte
# cEVM+Fbgg61lRUi7FUqd0BqCmTiImJdy74qJjBjieaod+mcIUsytkk93l0wCdM32
# Jr9hKBm5ekPCo6v+h1l6UOiPh1OfR381v3onvUkEUd/px1BSW1LqEqEFYqLbCyv+
# s0MM6Jb2ZGRYGSVd4cvj/RuQQM142pHgaoEMqeDnDe4xc5ne7MkEfgVA/R1Dy3Nl
# AIDhHEVW1uQjiBjwfeaV7aA7ERrZNbKTRwMUwBwCzDv8tji2RfVHelmLo/d3ZY6S
# Vg4OJ6IyXlmgnVuDCmlx8rCPoNDHyjBNHAadYlOX31ai+qGETDKYoHBbU13fWUBr
# DKBlOz9ORKlaPPpupKI4DILC2gcnm/4e8MAMXYGpeHSGNU7LCdJ9+vH6dOPaLA4N
# Ugf2LIorwacje11L3IgfqPjA1OD0Q/JxGEXF1WCEY6nQ09anPz4Ze4NeRG4zDCYF
# 6Bb2QCwZIBTYtZ3Hk0HhiDAZZ3L5+V0X9GTxJEQCWiIlInC15AMa4nRnrOdqtLJd
# pjbRUzpQZWyIV9p1ABhlvfnFPtQpJbFFVqtl/giN1zlW9DdFU5AQ17S/3P3HC1Tn
# oHJbnGbgadFkX4seX3vGfZHVJMLN5H4FxYWIs4B9MdUnp/7bsEF1cj2kzUUil7X0
# /r1rlJgbvMjIX98VghJtH7hPFFzCUnGDsaXi8zQ=
# SIG # End signature block
