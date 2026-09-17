param([string]$DataRoot = "")
$ErrorActionPreference = "Stop"
$trainerData = if ($DataRoot) {
    [IO.Path]::GetFullPath($DataRoot)
} else {
    Join-Path $env:LOCALAPPDATA "Crumblr Trainer Data"
}
$processPath = Join-Path $trainerData "run\processes.json"

if (-not (Test-Path -LiteralPath $processPath)) {
    Write-Host "Geen lokaal gestart Trainer-proces gevonden."
    exit 0
}

$saved = Get-Content -Raw -LiteralPath $processPath | ConvertFrom-Json
$stopped = 0
foreach ($processId in @($saved.worker_pid, $saved.server_pid)) {
    if (-not $processId) { continue }
    $process = Get-Process -Id ([int]$processId) -ErrorAction SilentlyContinue
    if (-not $process) { continue }
    if ($saved.python -and $process.Path -eq $saved.python) {
        Stop-Process -Id ([int]$processId) -Force
        $stopped++
    }
}
Remove-Item -LiteralPath $processPath -Force
Write-Host "Lokale Crumblr Trainer gestopt ($stopped proces(sen)). Data en journal zijn bewaard." -ForegroundColor Green
