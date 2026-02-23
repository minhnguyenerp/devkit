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
# MIIu8wYJKoZIhvcNAQcCoIIu5DCCLuACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCxDp4elC29755L
# KJQ2aU67SyQEC8dg7cAK7ki+1MWtkqCCFBcwggYxMIIEGaADAgECAhMzAAAAOb0d
# 20f6nVYAAAEAAAA5MA0GCSqGSIb3DQEBCwUAMIGHMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMTEwLwYDVQQDEyhNaWNyb3NvZnQgTWFya2V0cGxh
# Y2UgUHJvZHVjdGlvbiBDQSAyMDExMB4XDTI1MDYxOTE4NTQxNFoXDTI2MDYxNzE4
# NTQxNFowdDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEeMBwG
# A1UEAxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAtdIdYPZGr5OPIrWkmxTpozsk8RnWxnTYkMnchCH1uxSHAAEG
# RgzhGbD7s32XpJ+XX2hgepvkkQuwVCAWJCw568PSrXoChWYBJVDonwZSphS48Diz
# NuoqhZmp61pqt+p+94Xbli9gtBqk1RBxuEaX6SHbG6JfbIKeOsR6iiMvXsuLoDP4
# G6xf1iBhodE43l7I6mcHnSnmtnrUZCDgrOYN0C4nnf8tExsfcNQ69oX2CyXd3k/2
# f3YFGatRzFjMWY7DKZ5OoUW/igxm7TgspmXgue/JpY1yuO2eOG/Us1LjeNDCa6x9
# UwRMQf3J8X29TQlesnOapdGzP3PRGAGo3/wqlwIDAQABo4IBpjCCAaIwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFBxpSPRkCMknX2x4/vfIokCCS6/5MFQG
# A1UdEQRNMEukSTBHMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRp
# b25zIExpbWl0ZWQxFjAUBgNVBAUTDTIyOTk3OSs1MDUzMDYwHwYDVR0jBBgwFoAU
# nqf5oCNwnxHFaeOhjQr68bD01YAwbAYDVR0fBGUwYzBhoF+gXYZbaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwTWFya2V0cGxh
# Y2UlMjBQcm9kdWN0aW9uJTIwQ0ElMjAyMDExKDEpLmNybDB5BggrBgEFBQcBAQRt
# MGswaQYIKwYBBQUHMAKGXWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y2VydHMvTWljcm9zb2Z0JTIwTWFya2V0cGxhY2UlMjBQcm9kdWN0aW9uJTIwQ0El
# MjAyMDExKDEpLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBZ
# QQS8MMpdKn3gQxAKmAS6isRYEP2Tz9k/l/zIRoSthAYXhpe5DtlKxvuQQcpEzBuw
# G5M89QaiCZaFVfosu9fXh2R4FK4RCJDwm/zV0PWBY7ZBfjgX2+RljYffHJ5GY7YX
# VV4WIh9hMw220sQ0xg3+BCM9qHjUKx1fDUZINcJLTU/dDJQ1cLKvSYISLA9VlC0F
# dArywD+SCpvL0TUQmRY2kw4VzRx3fP0aPLhbDVcUQc9P9Wuwx/dp+2faji+Ug2aD
# y9CgDHqNGQAP9MhZpQYnr78q/s4BHDxdGmTjfvvgBvIrmIM4nq0F921G5CSFatbi
# srUEN2M+Jk3jMfWciiVTvv2y/wE0MXt+R+hJhyhqlObMJSIr0tFles7fD2sBs+5m
# ccBsMCwt7S+gqtlBr5J/9yn07XSkKJlZSAiDx0MvqWVyBBGvu8QDv4saUjNOG7nH
# JSfpaP66cF3shogzmGad2T+il7p0kmvvTgEX2RQ64x252Hur2DlEmYE1GE5b8bLb
# +7rXwFbsdzR+Gytz/MmKQK5c1LaHJT21guU+AbeRKAPbgs6UajiLBPiGamqhG+Y6
# u8VvH71qKGNBrO+3+Fa3IeGh2R/JdedigfKUQX7NyA8wPlLx3HM4+kQJqZIF2dL1
# N0v4QYELCuZ6a8sxFZFslkLb0zQpVewg91s5rblo6DCCBtcwggS/oAMCAQICCmES
# RKIAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDExMB4XDTExMDMyODIxMDkzOVoXDTMxMDMyODIxMTkz
# OVowfTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEnMCUGA1UE
# AxMeTWljcm9zb2Z0IE1hcmtldFBsYWNlIFBDQSAyMDExMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAubUaSwGYVsE3MAnPfvmozUhAB3qxBABgJRW1vDp4
# +tVinXxD32f7k1K89JQ6zDOgS/iDgULC+yFK1K/1Qjac/0M7P6c8v5LSjnWGlERL
# a/qY32j46S7SLQcit3g2jgoTTO03eUG+9yHZUTGV/FJdRYB8uXhrznJBa+Y+yGwi
# QKF+m6XFeBH/KORoKFx+dmMoy9EWJ/m/o9IiUj2kzm9C691+vZ/I2w0Bj93W9SPP
# kV2PCNHlzgfIAoeajWpHmi38Wi3xZHonkzAVBHxPsCBppOoNsWvmAfUM7eBthkSP
# vFruekyDCPNEYhfGqgqtqLkoBebXLZCOVybF7wTQaLvse60//3P003icRcCoQYgY
# 4NAqrF7j80o5U7DkeXxcB0xvengsaKgiAaV1DKkRbpe98wCqr1AASvm5rAJUYMU+
# mXmOieV2EelY2jGrenWe9FQpNXYV1NoWBh0WKoFxttoWYAnF705bIWtSZsz08ZfK
# 6WLX4GXNLcPBlgCzfTm1sdKYASWdBbH2haaNhPapFhQQBJHKwnVW2iXErImhuPi4
# 5W3MVTZ5D9ASshZx69cLYY6xAdIa+89Kf/uRrsGOVZfahDuDw+NI183iAyzC8z/Q
# Rt2P32LYxP0xrCdqVh+DJo2i4NoE8Uk1usCdbVRuBMBQl/AwpOTq7IMvHGElf65C
# qzUCAwEAAaOCAUswggFHMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBQPU8s/
# FmEl/mCJHdO5fOiQrbOU0TAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNV
# HQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQF
# TuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29m
# dC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNf
# MjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5t
# aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNf
# MjIuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCjuZmM8ZVNDgp9wHsL4RY8KJ8nLinv
# xFTphNGCrxaLknkYG5pmMhVlX+UB/tSiW8W13W60nggz9u5xwMx7v/1t/Tgm6g2b
# rVyOKI5A7u6/2SIJwkJKFw953K0YIKVT28w9zl8dSJnmRnyR0G86ncWbF6CLQ6A6
# lBQ9o2mTGVqDr4m35WKAnc6YxUUM1y74mbzFFZr63VHsCcOp3pXWnUqAY1rb6Q6N
# X1b3clncKqLFm0EjKHcQ56grTbwuuB7pMdh/IFCJR01MQzQbDtpEisbOeZUi43YV
# AAHKqI1EO9bRwg3frCjwAbml9MmI4utMW94gWFgvrMxIX+n42RBDIjf3Ot3jkT6g
# t3XeTTmO9bptgblZimhERdkFRUFpVtkocJeLoGuuzP93uH/Yp032wzRH+XmMgujf
# Zv+vnfllJqxdowoQLx55FxLLeTeYfwi/xMSjZO2gNven3U/3KeSCd1kUOFS3AOrw
# Z0UNOXJeW5JQC6Vfd1BavFZ6FAta1fMLu3WFvNB+FqeHUaU3ya7rmtxJnzk29DeS
# qXgGNmVSywBS4NajI5jJIKAA6UhNJlsg8CHYwUOKf5ej8OoQCkbadUxXygAfxCfW
# 2YBbujtI+PoyejRFxWUjYFWO5LeTI62UMyqfOEiqugoYjNxmQZla2s4YHVuqIC34
# R85FQlg9pKQBsDCCBwMwggTroAMCAQICEzMAAABVyAZrOCOXKQkAAAAAAFUwDQYJ
# KoZIhvcNAQELBQAwfTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEnMCUGA1UEAxMeTWljcm9zb2Z0IE1hcmtldFBsYWNlIFBDQSAyMDExMB4XDTIx
# MDkwOTIyNDIzMFoXDTMwMDkwOTIyNTIzMFowgYcxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMTAvBgNVBAMTKE1pY3Jvc29mdCBNYXJrZXRwbGFj
# ZSBQcm9kdWN0aW9uIENBIDIwMTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQDHfQ3P+L0El1S6JNYAz70y3e1i7EZAYcCDVXde/nQdpOKtVr6H4QkBkROv
# 7HBxY0U8lR9C3bUUZKn6CCcN3v3bQuYKu1Ff2G4nIIr8a1cB4iOU8i4YSN7bRr+5
# LvD5hyCfJHqXrJe5LRRGjws5aRAxYuGhQ3ypWPEZYfrIXmmYK+e+udApgxahHUPB
# qcbI2PT1PpkKDgqR7hyzW0CfWzRUwh+YoZpsVvDaEkxcHQe/yGJB5BluYyRm5K9z
# +YQqBvYJkNUisTE/9OImnaZqoujkEuhM5bBV/dNjw7YN37OcBuH0NvlQomLQo+V7
# PA519HVVE1kRQ8pFad6i4YdRWpj/+1yFskRZ5m7y+dEdGyXAiFeIgaM6O1CFrA1L
# bMAvyaZpQwBkrT/etC0hw4BPmW70zSmSubMoHpx/UUTNo3fMUVqx6r2H1xsc4aXT
# pPN5IxjkGIQhPN6h3q5JC+JOPnsfDRg3Ive2Q22jj3tkNiOXrYpmkILk7v+4XUxD
# Erdc/WLZ3sbF27hug7HSVbTCNA46scIqE7ZkgH3M7+8aP3iUBDNcYUWjO1u+P1Q6
# UUzFdShSbGbKf+Z3xpqlwdxQq9kuUahACRQLMFjRUfmAqGXUdMXECRaFPTxl6SB/
# 7IAcuK855beqNPcexVEpkSZxZJbnqjKWbyTk/GA1abW8zgfH2QIDAQABo4IBbzCC
# AWswEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUeBlfau2VIfkw
# k2K+EoAD6hZ05ccwHQYDVR0OBBYEFJ6n+aAjcJ8RxWnjoY0K+vGw9NWAMBkGCSsG
# AQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjASBgNVHRMBAf8ECDAG
# AQH/AgEAMB8GA1UdIwQYMBaAFA9Tyz8WYSX+YIkd07l86JCts5TRMFcGA1UdHwRQ
# ME4wTKBKoEiGRmh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY01hclBDQTIwMTFfMjAxMS0wMy0yOC5jcmwwWwYIKwYBBQUHAQEETzBN
# MEsGCCsGAQUFBzAChj9odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRz
# L01pY01hclBDQTIwMTFfMjAxMS0wMy0yOC5jcnQwDQYJKoZIhvcNAQELBQADggIB
# ACY4RaglNFzKOO+3zgazCsgCvXca79D573wDc0DAj6KzBX9m4rHhAZqzBkfSWvan
# LFilDibWmbGUGbkuH0y29NEoLVHfY64PXmXcBWEWd1xK4QxyKx2VVDq9P9494Z/v
# Xy9OsifTP8Gt2UkhftAQMcvKgGiAHtyRHda8r7oU4cc4ITZnMsgXv6GnMDVuIk+C
# q0Eh93rgzKF2rJ1sJcraH/kgSkgawBYYdJlXXHTkOrfEPKU82BDT5h8SGsXVt5L1
# mwRzjVQRLs1FNPkA+Kqyz0L+UEXJZWldNtHC79XtYh/ysRov4Yu/wLF+c8Pm15IC
# n8EYJUL4ZKmk9ZM7ZcaUV/2XvBpufWE2rcMnS/dPHWIojQ1FTToqM+Ag2jZZ33fl
# 8rJwnnIF/Ku4OZEN24wQLYsOMHh6WKADxkXJhiYUwBe2vCMHDVLpbCY7CbPpQdtB
# YHEkto0MFADdyX50sNVgTKboPyCxPW6GLiR5R+qqzNRzpYru2pTsM6EodSTgcMbe
# aDZI7ssnv+NYMyWstE1IXQCUywLQohNDo6H7/HNwC8HtdsGd5j0j+WOIEO5PyCbj
# n5viNWWCUu7Ko6Qx68NuxHf++swe9YQhufh0hzJnixidTRPkBUgYQ6xubG6I5g/2
# OO1BByOu9/jt5vMTTvctq2YWOhUjoOZPe53eYSzjvNydMYIaMjCCGi4CAQEwgZ8w
# gYcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMTAvBgNVBAMT
# KE1pY3Jvc29mdCBNYXJrZXRwbGFjZSBQcm9kdWN0aW9uIENBIDIwMTECEzMAAAA5
# vR3bR/qdVgAAAQAAADkwDQYJYIZIAWUDBAIBBQCggbAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIKSrtvHnWz0t+05Bo+kPvXdf20Bu5G1KMlK8DmxiNR7vMEQGCisG
# AQQBgjcCAQwxNjA0oBCADgBWAFMAIABDAG8AZABloSCAHmh0dHBzOi8vY29kZS52
# aXN1YWxzdHVkaW8uY29tLzANBgkqhkiG9w0BAQEFAASCAQBx8um6MDljG8kDR3T4
# 5TY6jPRfW6aWCOpDmh+i7KxRfFeNX2p08FOQ3RuRzuQC75Mi4NVpt8gbSnGAGyx3
# f+B4SzkhTVL4Fkn/06GoBBT9jul1HrG04xvdipt4zh4fyFPjOxSsWDh4crQbI+KZ
# yuWqt5YJA/awuxthYY78NmzZ7oYLdfk5yI9MLWGNE3CW8uVjyWdy9uCMrI4xan5H
# BNVVWkdR6BhG6DR+2av6+tWJ7JM7UnG7lcv9zPktVSSjFtwH0xdHAefxIy+Dnk4c
# 6n6B6BVgn1BsCUzS+tMSe9J8nt/7BaWmimx8YgkCBqP1GjSLnTiGJ7sQnsUIIvho
# blFRoYIXsDCCF6wGCisGAQQBgjcDAwExghecMIIXmAYJKoZIhvcNAQcCoIIXiTCC
# F4UCAQMxDzANBglghkgBZQMEAgEFADCCAVoGCyqGSIb3DQEJEAEEoIIBSQSCAUUw
# ggFBAgEBBgorBgEEAYRZCgMBMDEwDQYJYIZIAWUDBAIBBQAEIO22WP1V4wsbYRPM
# KRpJI/xMlRZHL4a/6PIhLVGpVQ7nAgZpc57XbksYEzIwMjYwMjE5MjAwODMxLjA1
# MlowBIACAfSggdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjJBMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIR/jCCBygwggUQ
# oAMCAQICEzMAAAIQq83kFhjvObAAAQAAAhAwDQYJKoZIhvcNAQELBQAwfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjUwODE0MTg0ODEyWhcNMjYxMTEz
# MTg0ODEyWjCB0zELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEt
# MCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMScw
# JQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MkExQS0wNUUwLUQ5NDcxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCNxzirTntnAiCkq7ilNdYt6O9gR25F/7WYiluIkQwVZaZT
# bGmKn7MrvEXEoYHUJyVRcFTT9lBnosbwfSAjvK+iyuw8QjUM8H9dxwYK+zApsApy
# SeA64ZMQ8aTsr+8Rlr2HRe3TZvubaf0x0iOQusWXSkOuIrLPRAcal2H3dfr40Cl8
# TVMvbhWjTGR6gUakvetf2BeEg4Xn0QydN3ajjkVb+jEyBj2rTLSMY7QesItMJmvn
# R7tNlFI1gDLaXIpu8ojYwqU3XAvMm9lttz/8vezWrcnoqFLQoLZU0QiZh0WBWQl6
# PjNmod9JxNvH2GMWAWlWQmXjEflUny3Il1cT369TST0BpPZA/VmbdZCZd51KguOM
# jstbOe4fCegYhcuIkxDM+oqpEgUvfDNysOtl5aC0B0E9uKmCVnkJCezoFqPkxvpr
# 8RkL0bd9olgrlBUd4Tp4uhITCnV3Pla6stc0+ynRVamWmX8UlvyOtFP+M6ge7zmp
# Fx1imAHJT1bshY92u2GbJ+p4DDSiZVY3knFyiBhsujakA0keWwx1afEik3ljAdsY
# Q8K6iwEc+TZd334T+lk9BRHq/4Pzl4Q3kD9kz/GI+nFrx0lnzsGlO+6Lv/a5+VQw
# l/Zhz1ks+AR2FBCjQvAwNJMNPjzLexXs92j6Dmr4yqcnO03/qq3VyBRN7277KQID
# AQABo4IBSTCCAUUwHQYDVR0OBBYEFJ7jb4Wul0XZq9tSGWTzoEtIfmR6MB8GA1Ud
# IwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCGTmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUyMFRp
# bWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4wXAYI
# KwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMv
# TWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeA
# MA0GCSqGSIb3DQEBCwUAA4ICAQC+zis7eijxzM6vE+qedISRRWrvXxDOWsiLLv8R
# bsmZBewmgXEdZQXRTHQ8PIoUNFc8lW/b0XuSkmQEkmZxCDkdBXtuVRcgxZDWpfQp
# 20VBcj8xEvvtn6krnHWNf61tGQDtrkW3u9a5GgASLTYekUfmb8CSH91+xvHzA6l5
# wlti+4e7LhobT+0bM5YULEww2EYAgnip1Xzsmdj+4wGaKh2Wb4bPfntdZbm2Dceu
# 01le5DS1ZS/bq53icYomj+gtkc/vmnhGm3t0x1gpQX0C5UUHDFhlim+CTXa18r7/
# I7Crzj9+NdUJ0zzdCdrC1t6duT+Wdtz0qxmib4ae8DiK0AxSlJcVatxGSp1RAs34
# msbp88GhXz4PxTZDYXheSIJHoRT0nNgrBO68vq3ecW7GeQt02NtODb/K/aPdZoO4
# IrmVI+Cyd0iIfoGS7ZSLcDRpSjoP3P2/5cS4Gz2KhUlo6N//P5SuqDsRKfEbT9PV
# 0pyLu8tDZc2BYVg7786UOO0aiZrWKNfibXg32qCtdO5YQbCALuGEGCneJ38sA5/0
# FJNYDmUGuKWwSh7FcGs6f/XAzeuMbSEizG8Xn9g4rvyZVEZjpjvNgn65e3g5M4UH
# Bp0+/wySWt5Bks+dA+2LCiniuUtRho8KIPhhSpE1sunxKDKj2DSIBxljOdO5z7xD
# xkiuDDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEw
# MB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk
# 4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9c
# T8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWG
# UNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6Gnsz
# rYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2
# LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLV
# wIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTd
# EonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0
# gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFph
# AXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJ
# YfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXb
# GjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJ
# KwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnP
# EP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMw
# UQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9z
# b2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggr
# BgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYw
# DwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoY
# xDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtp
# L2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYB
# BQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0B
# AQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U5
# 18JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgAD
# sAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo
# 32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZ
# iefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZK
# PmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RI
# LLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgk
# ujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9
# af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzba
# ukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/
# OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNZMIIC
# QQIBATCCAQGhgdmkgdYwgdMxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGlt
# aXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjJBMUEtMDVFMC1EOTQ3MSUw
# IwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4D
# AhoDFQA6zJ/ZvquI8qedeUiAgvZ/nc9SwqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA7UG0CTAiGA8yMDI2MDIx
# OTE2MDg0MVoYDzIwMjYwMjIwMTYwODQxWjB3MD0GCisGAQQBhFkKBAExLzAtMAoC
# BQDtQbQJAgEAMAoCAQACAhUUAgH/MAcCAQACAhKTMAoCBQDtQwWJAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMB
# hqAwDQYJKoZIhvcNAQELBQADggEBACJbceljFMlmV12jeGSGJ6+UJbYyWUvXQsZE
# KParjr4c21/vWlOUA4fn+sAT6H/FXpiWmfTOKb+c1Fw0LvaNNtaGWV2NZzCX51V7
# /Wao21lIOzQuLUZImx3oMlc1Dukk7M//iQiioBUp0ymiThnlmBiN0HEwF64Awopf
# zLelojvX1xpKcA1a2i/G0nY9kQ7cTWzGvhB13wncMMzea7/G+GiRP9IGRxgTa8k1
# NrKGv7A90D5yQQYCmkS0bNqnhw0imxR/ZvOKLUmgTtL2Zt/RHtfl2oz2PZFE9cWO
# C0JKwh7ejnChC7TE8F4kR223sZyNVOEoozG5x6ueoO0GyWzamXoxggQNMIIECQIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAhCrzeQWGO85
# sAABAAACEDANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCvDiT4h+J689Rujjmw6ZW3boS3fTk0LFut
# QuddV2QNUjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIMPVIe5+yPNjn1LW
# IdRBj2GewpKsk+Dlr0xzhicaY8fGMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTACEzMAAAIQq83kFhjvObAAAQAAAhAwIgQg7uHStPked8V5VeXc
# gK9BJiLgEfEYPiYgzJ12Y+pSQ80wDQYJKoZIhvcNAQELBQAEggIADkSbWZkHoq5I
# Y06bXuJpsUGNCtp0azmdN3QVzawyLGIA9jR+CifePrz0fQtSmhufZ+BI2e/fhgwF
# hl2Cg5Bqn8oPEhceM9WQyAgcw2csSRwyD7tP4t8CX6ib3WHA+/Ihzw/P8yfwHVYU
# FjFAYOarrjt1oqk6O9Pmd0P2jcjNnc8T75UICPHTA8MOYxGMUbjbgR1HOs9uFnLa
# SL1Rud/w2pihB2DkOJ7vR/gi3Qw+6MLauvVo5QewLGK1DTrIWdgxNufQgGoUY8AY
# OEkfUahIRmHB23cXYrg977ilrYTsQwu3pJD40ZexzeRKi43tf4+0EV0QpLpdNBvP
# 9c9tq4i6Sa0BcGJzDKxKgpOJNZ7GrybCNRF2GcL1+V7HZ6k9z/NeSHbok6B/BT5A
# FGOGfbe36xJEZAizcze4KgOnyi7KLjoc1X7eLD3gAmYMxNtXv31sFdP/GL8K5Uzj
# 0UogfutdYs1iC4XqPxoVgDuUTaFByU+prjlCdsove6oN5Jd4N6ZnG1JNq+1Tgljr
# OhEdNzy6UuDGoJ1c1OAn60gNa62gExo2Wu8St+yZ+xrtjdx8GsaFC33JqZEAkrsh
# e7dVDSs95DlmK0Nu2lR889Ym55nr1A+B8KxOkXUFWMtomVYRLQqLYp4Jr+SoGCxN
# nM+yHuaoz8UM52JfrE+64ThMe9roDSE=
# SIG # End signature block
