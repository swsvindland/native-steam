<#
.SYNOPSIS
  Cold-start benchmark for the Native Steam WinUI 3 client (used in CI).

.DESCRIPTION
  For each run: start NativeSteam.exe fresh, time how long until its main window
  is visible, let it settle, record memory, then kill it. Writes one JSON object
  per run (same shape as bench/macos/launchbench) to -Out.

.EXAMPLE
  ./clients/windows/scripts/coldstart.ps1 -Runs 10 -Out bench/results/windows-ci.jsonl
#>
param(
    [int]$Runs = 10,
    [string]$Configuration = 'Release',
    [string]$Platform = 'x64',
    [string]$Out = 'bench/results/windows-ci.jsonl',
    [int]$SettleSeconds = 8
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$exe = Get-ChildItem -Path (Join-Path $root "NativeSteam/bin/$Platform/$Configuration") -Recurse -Filter NativeSteam.exe |
    Select-Object -First 1
if (-not $exe) { throw "NativeSteam.exe not found; build $Configuration|$Platform first" }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NsWin {
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
"@

$outPath = Join-Path (Get-Location) $Out
New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null
if (Test-Path $outPath) { Remove-Item $outPath }

for ($run = 1; $run -le $Runs; $run++) {
    Get-Process NativeSteam -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -PassThru
    $ttw = $null
    while ($sw.Elapsed.TotalSeconds -lt 45) {
        $proc.Refresh()
        if ($proc.HasExited) { throw "run ${run}: process exited with code $($proc.ExitCode)" }
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero -and [NsWin]::IsWindowVisible($proc.MainWindowHandle)) {
            $ttw = $sw.Elapsed.TotalMilliseconds
            break
        }
        Start-Sleep -Milliseconds 5
    }
    if ($null -eq $ttw) { throw "run ${run}: no visible window within 45 s" }

    Start-Sleep -Seconds $SettleSeconds
    $proc.Refresh()
    $privateMiB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 1)
    $workingMiB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
    $proc | Stop-Process -Force

    $record = [ordered]@{
        app = 'native-steam-winui'; mode = 'cold'; run = $run
        ttw_ms = [math]::Round($ttw, 1)
        private_mib = $privateMiB; working_set_mib = $workingMiB
        runner = $env:RUNNER_NAME; os = [System.Environment]::OSVersion.VersionString
        cpus = [System.Environment]::ProcessorCount
    }
    $line = $record | ConvertTo-Json -Compress
    Add-Content -Path $outPath -Value $line
    Write-Host ("cold #{0}: window {1:N0} ms, private {2} MiB, working set {3} MiB" -f $run, $ttw, $privateMiB, $workingMiB)
}
