# Diagnostic wrapper for mergeReleaseNativeLibs file-lock failures (debug session b52c59)
param(
  [string]$BuildCommand = "flutter build apk --release"
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$LogPath = Join-Path $Root "debug-b52c59.log"
$TargetDir = Join-Path $Root "build\app\intermediates\merged_native_libs\release\mergeReleaseNativeLibs\out"
$SessionId = "b52c59"
$RunId = "pre-fix"

function Write-AgentLog {
  param(
    [string]$HypothesisId,
    [string]$Location,
    [string]$Message,
    [hashtable]$Data = @{}
  )
  $payload = [ordered]@{
    sessionId    = $SessionId
    runId        = $RunId
    hypothesisId = $HypothesisId
    location     = $Location
    message      = $Message
    data         = $Data
    timestamp    = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  }
  $line = ($payload | ConvertTo-Json -Compress -Depth 8)
  Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
}

function Get-JvmSnapshot {
  $procs = @()
  Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javac.exe' OR Name='dart.exe' OR Name='flutter.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = $_.CommandLine
    $kind = "other"
    if ($cmd -match "GradleDaemon") { $kind = "gradle-daemon" }
    elseif ($cmd -match "KotlinCompileDaemon") { $kind = "kotlin-daemon" }
    elseif ($cmd -match "Android Studio") { $kind = "android-studio-jbr" }
    $procs += @{
      pid  = $_.ProcessId
      name = $_.Name
      kind = $kind
      cmd  = if ($cmd -and $cmd.Length -gt 180) { $cmd.Substring(0, 180) } else { $cmd }
    }
  }
  return $procs
}

function Test-TargetDirLock {
  $result = @{
    exists           = (Test-Path -LiteralPath $TargetDir)
    childCount       = 0
    deleteOk         = $null
    deleteError      = $null
    lockedSampleFiles = @()
  }
  if (-not $result.exists) { return $result }

  $children = @(Get-ChildItem -LiteralPath $TargetDir -Recurse -Force -ErrorAction SilentlyContinue)
  $result.childCount = $children.Count

  foreach ($f in ($children | Where-Object { -not $_.PSIsContainer } | Select-Object -First 5)) {
    try {
      $fs = [System.IO.File]::Open($f.FullName, "Open", "ReadWrite", "None")
      $fs.Close()
      $result.lockedSampleFiles += @{ path = $f.FullName; locked = $false }
    } catch {
      $result.lockedSampleFiles += @{ path = $f.FullName; locked = $true; error = $_.Exception.Message }
    }
  }

  try {
    Remove-Item -LiteralPath $TargetDir -Recurse -Force -ErrorAction Stop
    $result.deleteOk = $true
    $result.existsAfterDelete = (Test-Path -LiteralPath $TargetDir)
  } catch {
    $result.deleteOk = $false
    $result.deleteError = $_.Exception.Message
    $result.existsAfterDelete = (Test-Path -LiteralPath $TargetDir)
  }
  return $result
}

# #region agent log
Write-AgentLog -HypothesisId "A" -Location "debug-merge-native-libs.ps1:start" -Message "Pre-build JVM snapshot" -Data @{
  jvm = @(Get-JvmSnapshot)
  gradleDaemonCount = @((Get-JvmSnapshot) | Where-Object { $_.kind -eq "gradle-daemon" }).Count
  kotlinDaemonCount = @((Get-JvmSnapshot) | Where-Object { $_.kind -eq "kotlin-daemon" }).Count
}
# #endregion

# #region agent log
Write-AgentLog -HypothesisId "B" -Location "debug-merge-native-libs.ps1:pre-lock-test" -Message "Pre-build target dir lock/delete probe" -Data (Test-TargetDirLock)
# #endregion

# #region agent log
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
Write-AgentLog -HypothesisId "C" -Location "debug-merge-native-libs.ps1:defender" -Message "Windows Defender realtime status" -Data @{
  realtimeEnabled = if ($defender) { $defender.RealTimeProtectionEnabled } else { $null }
  antivirusEnabled = if ($defender) { $defender.AntivirusEnabled } else { $null }
}
# #endregion

Set-Location $Root
Write-Host "Running: $BuildCommand"
Write-Host "Logging to: $LogPath"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$buildOutput = & cmd /c "$BuildCommand 2>&1"
$exitCode = $LASTEXITCODE
$sw.Stop()
$buildText = ($buildOutput | Out-String)

# #region agent log
Write-AgentLog -HypothesisId "A" -Location "debug-merge-native-libs.ps1:post-build" -Message "Build finished" -Data @{
  exitCode = $exitCode
  elapsedMs = $sw.ElapsedMilliseconds
  failedMergeNativeLibs = ($buildText -match "mergeReleaseNativeLibs")
  unableToDelete = ($buildText -match "Unable to delete directory")
  tail = (($buildOutput | Select-Object -Last 40) -join "`n")
}
# #endregion

# #region agent log
Write-AgentLog -HypothesisId "D" -Location "debug-merge-native-libs.ps1:post-jvm" -Message "Post-build JVM snapshot" -Data @{
  jvm = @(Get-JvmSnapshot)
  gradleDaemonCount = @((Get-JvmSnapshot) | Where-Object { $_.kind -eq "gradle-daemon" }).Count
}
# #endregion

# #region agent log
Write-AgentLog -HypothesisId "E" -Location "debug-merge-native-libs.ps1:post-lock-test" -Message "Post-build target dir lock/delete probe" -Data (Test-TargetDirLock)
# #endregion

if ($exitCode -ne 0) {
  Write-Host "BUILD FAILED (exit $exitCode). Diagnostics written to $LogPath"
  exit $exitCode
}

Write-Host "BUILD SUCCEEDED. Diagnostics written to $LogPath"
exit 0
