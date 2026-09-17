param(
    [switch]$Doctor,
    [switch]$NoBrowser,
    [switch]$ResetAgentKeys,
    [string]$DataRoot = ""
)

$ErrorActionPreference = "Stop"

function ConvertFrom-ProtectedValue([string]$Value) {
    $secure = ConvertTo-SecureString $Value
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Read-ProtectedValue([string]$Prompt) {
    while ($true) {
        $secure = Read-Host $Prompt -AsSecureString
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
            if (-not [string]::IsNullOrWhiteSpace($plain)) {
                return @{
                    Plain = $plain
                    Protected = ConvertFrom-SecureString $secure
                }
            }
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
        Write-Host "Deze waarde mag niet leeg zijn." -ForegroundColor Yellow
    }
}

function Find-Python {
    $candidates = @(
        (Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return @{ Command = $candidate; Prefix = @() }
        }
    }
    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) {
        return @{ Command = $python.Source; Prefix = @() }
    }
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        return @{ Command = $launcher.Source; Prefix = @("-3.11") }
    }
    throw "Python 3.11 of nieuwer is niet gevonden. Installeer Python via python.org en vink 'Add Python to PATH' aan."
}

function Find-MT5Terminal {
    $configured = [Environment]::GetEnvironmentVariable("MT5_TERMINAL", "User")
    $candidates = @(
        $configured,
        "C:\Program Files\MetaTrader 5\terminal64.exe",
        "C:\Program Files (x86)\MetaTrader 5\terminal64.exe"
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "MetaTrader 5 is niet gevonden. Installeer MT5 in de standaardmap of stel MT5_TERMINAL als gebruikersvariabele in."
}

function Find-MT5ExpertsDirectory([string]$TerminalPath) {
    $configured = [Environment]::GetEnvironmentVariable("MT5_EXPERTS_DIR", "User")
    if ($configured -and (Test-Path -LiteralPath $configured)) {
        return (Resolve-Path -LiteralPath $configured).Path
    }
    $terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    foreach ($origin in @(Get-ChildItem -LiteralPath $terminalRoot -Filter origin.txt -Recurse -ErrorAction SilentlyContinue)) {
        try {
            $installation = (Get-Content -Raw -LiteralPath $origin.FullName).Trim()
            if ($installation -and (
                [IO.Path]::GetFullPath($installation) -eq [IO.Path]::GetFullPath($TerminalPath) -or
                [IO.Path]::GetFullPath($installation) -eq [IO.Path]::GetFullPath((Split-Path $TerminalPath))
            )) {
                $experts = Join-Path $origin.Directory.FullName "MQL5\Experts"
                if (Test-Path -LiteralPath $experts) { return $experts }
            }
        }
        catch {
            # Ignore unrelated or unreadable MT5 profiles.
        }
    }
    return (Join-Path (Split-Path $TerminalPath) "MQL5\Experts")
}

function Quote-ProcessArgument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Test-LocalPort([int]$Port) {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $pending = $client.ConnectAsync("127.0.0.1", $Port)
        return $pending.Wait(500) -and $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Start-MT5WorkerProcess(
    [string]$PythonCommand,
    [array]$PythonPrefix,
    [string]$TerminalPath,
    [string]$ExpertsPath,
    [string]$WorkerData,
    [string]$Repository,
    [string]$OutputLog,
    [string]$ErrorLog
) {
    $arguments = @($PythonPrefix) + @(
        "-m", "crumblr_trainer.worker",
        "--trainer-url", "http://127.0.0.1:8877",
        "--api-key", "local-loopback-worker",
        "--terminal", (Quote-ProcessArgument $TerminalPath),
        "--experts-directory", (Quote-ProcessArgument $ExpertsPath),
        "--home", (Quote-ProcessArgument $WorkerData),
        "--poll-seconds", "15"
    )
    return Start-Process -FilePath $PythonCommand -ArgumentList $arguments `
        -WorkingDirectory $Repository -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $OutputLog -RedirectStandardError $ErrorLog
}

$trainerData = if ($DataRoot) {
    [IO.Path]::GetFullPath($DataRoot)
} else {
    Join-Path $env:LOCALAPPDATA "Crumblr Trainer Data"
}
$logDirectory = Join-Path $trainerData "logs"
$configDirectory = Join-Path $trainerData "config"
$workerDirectory = Join-Path $trainerData "mt5-worker"
$runDirectory = Join-Path $trainerData "run"
foreach ($directory in @($trainerData, $logDirectory, $configDirectory, $workerDirectory, $runDirectory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$secretPath = Join-Path $configDirectory "agent-secrets.json"
if ($ResetAgentKeys -and (Test-Path -LiteralPath $secretPath)) {
    Remove-Item -LiteralPath $secretPath -Force
}

if (
    -not (Test-Path -LiteralPath $secretPath) -and
    $env:GROQ_API_KEY -and
    $env:CLOUDFLARE_AI_API_KEY -and
    $env:CLOUDFLARE_ACCOUNT_ID
) {
    $groqApiKey = $env:GROQ_API_KEY
    $cloudflareApiKey = $env:CLOUDFLARE_AI_API_KEY
    $cloudflareAccountId = $env:CLOUDFLARE_ACCOUNT_ID
}
elseif (-not (Test-Path -LiteralPath $secretPath)) {
    Write-Host "Eenmalige lokale agentconfiguratie" -ForegroundColor Cyan
    Write-Host "De sleutels worden met Windows DPAPI versleuteld en kunnen alleen door jouw Windows-account worden gelezen."
    $groq = Read-ProtectedValue "Plak de GROQ_API_KEY"
    $cloudflare = Read-ProtectedValue "Plak het Cloudflare Workers AI-token"
    do {
        $cloudflareAccount = (Read-Host "Plak het Cloudflare Account ID").Trim()
    } while (-not $cloudflareAccount)
    @{
        version = 1
        groq_api_key = $groq.Protected
        cloudflare_api_key = $cloudflare.Protected
        cloudflare_account_id = $cloudflareAccount
    } | ConvertTo-Json | Set-Content -LiteralPath $secretPath -Encoding UTF8
    $groqApiKey = $groq.Plain
    $cloudflareApiKey = $cloudflare.Plain
    $cloudflareAccountId = $cloudflareAccount
}
else {
    try {
        $savedSecrets = Get-Content -Raw -LiteralPath $secretPath | ConvertFrom-Json
        $groqApiKey = ConvertFrom-ProtectedValue $savedSecrets.groq_api_key
        $cloudflareApiKey = ConvertFrom-ProtectedValue $savedSecrets.cloudflare_api_key
        $cloudflareAccountId = [string]$savedSecrets.cloudflare_account_id
        if (-not $groqApiKey -or -not $cloudflareApiKey -or -not $cloudflareAccountId) {
            throw "De agentconfiguratie is onvolledig."
        }
    }
    catch {
        throw "De lokale agentconfiguratie kon niet worden gelezen. Start opnieuw met -ResetAgentKeys. Details: $($_.Exception.Message)"
    }
}

$pythonInfo = Find-Python
$pythonCommand = $pythonInfo.Command
$pythonPrefix = $pythonInfo.Prefix
$mt5Terminal = Find-MT5Terminal
$mt5Experts = Find-MT5ExpertsDirectory $mt5Terminal

$env:TRAINER_HOME = $trainerData
$env:TRAINER_MT5_WORKFLOW_ENABLED = "true"
$env:TRAINER_OPERATING_MODE = "standalone"
$env:TRAINER_AGENT_MODE = "dual-agent"
$env:PRIMARY_AGENT_PROVIDER = "groq"
$env:GROQ_API_KEY = $groqApiKey
$env:GROQ_MODEL = "openai/gpt-oss-120b"
$env:REVIEW_AGENT_PROVIDER = "cloudflare"
$env:CLOUDFLARE_AI_API_KEY = $cloudflareApiKey
$env:CLOUDFLARE_AI_BASE_URL = "https://api.cloudflare.com/client/v4/accounts/$cloudflareAccountId/ai/v1"
$env:CLOUDFLARE_AI_MODEL = "@cf/openai/gpt-oss-20b"
$env:MT5_TERMINAL = $mt5Terminal
$env:HOST = "127.0.0.1"
$env:PORT = "8877"
$env:PYTHONUNBUFFERED = "1"
Remove-Item Env:TRAINER_API_KEY -ErrorAction SilentlyContinue
Remove-Item Env:RENDER -ErrorAction SilentlyContinue

$versionText = & $pythonCommand @pythonPrefix --version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Python kon niet worden gestart: $versionText"
}
$versionMatch = [regex]::Match([string]$versionText, "(\d+)\.(\d+)")
if (-not $versionMatch.Success -or [int]$versionMatch.Groups[1].Value -lt 3 -or ([int]$versionMatch.Groups[1].Value -eq 3 -and [int]$versionMatch.Groups[2].Value -lt 11)) {
    throw "Python 3.11 of nieuwer is vereist; gevonden: $versionText"
}

Push-Location $PSScriptRoot
try {
    & $pythonCommand @pythonPrefix -c "import crumblr_trainer.api, crumblr_trainer.worker" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "De Trainer-code kan niet door Python worden geladen."
    }

    $doctorArgs = @($pythonPrefix) + @(
        "-m", "crumblr_trainer.worker",
        "--trainer-url", "http://127.0.0.1:8877",
        "--api-key", "local-loopback-worker",
        "--terminal", $mt5Terminal,
        "--experts-directory", $mt5Experts,
        "--home", $workerDirectory,
        "--doctor"
    )
    $doctorResult = & $pythonCommand @doctorArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "De MT5-controle is mislukt: $doctorResult"
    }
    if ($Doctor) {
        Write-Host "LOKALE TRAINER CONTROLE: GESLAAGD" -ForegroundColor Green
        Write-Host "Python: $versionText"
        Write-Host "MT5: $mt5Terminal"
        Write-Host "Data: $trainerData"
        Write-Host "Agent: Groq + Cloudflare review"
        exit 0
    }

    $healthUrl = "http://127.0.0.1:8877/healthz"
    $dashboardUrl = "http://127.0.0.1:8877/"
    $processPath = Join-Path $runDirectory "processes.json"
    $serverOut = Join-Path $logDirectory "trainer-output.log"
    $serverErr = Join-Path $logDirectory "trainer-error.log"
    $workerOut = Join-Path $logDirectory "mt5-worker-output.log"
    $workerErr = Join-Path $logDirectory "mt5-worker-error.log"
    try {
        if (-not (Test-LocalPort 8877)) { throw "not running" }
        if (-not (Test-Path -LiteralPath $processPath)) {
            throw "Poort 8877 is al in gebruik door een proces dat niet met deze starter is vastgelegd. Sluit dat proces eerst."
        }
        $existing = Get-Content -Raw -LiteralPath $processPath | ConvertFrom-Json
        $serverProcess = Get-Process -Id ([int]$existing.server_pid) -ErrorAction SilentlyContinue
        if (-not $serverProcess -or $serverProcess.Path -ne $pythonCommand) {
            throw "Poort 8877 is in gebruik, maar niet door de vastgelegde lokale Trainer. Sluit dat proces eerst."
        }
        $workerProcess = Get-Process -Id ([int]$existing.worker_pid) -ErrorAction SilentlyContinue
        if (-not $workerProcess -or $workerProcess.Path -ne $pythonCommand) {
            $workerProcess = Start-MT5WorkerProcess $pythonCommand $pythonPrefix $mt5Terminal $mt5Experts $workerDirectory $PSScriptRoot $workerOut $workerErr
            Start-Sleep -Seconds 1
            if ($workerProcess.HasExited) {
                $details = if (Test-Path -LiteralPath $workerErr) { Get-Content -Raw -LiteralPath $workerErr } else { "Geen foutlog beschikbaar." }
                throw "De lokale MT5-worker kon niet worden herstart. Details: $details"
            }
            $existing.worker_pid = $workerProcess.Id
            $existing | ConvertTo-Json | Set-Content -LiteralPath $processPath -Encoding UTF8
            Write-Host "De Trainer draaide al; de MT5-worker is herstart." -ForegroundColor Green
        }
        else {
            Write-Host "De lokale Trainer en MT5-worker draaien al." -ForegroundColor Green
        }
        if (-not $NoBrowser) {
            Start-Process $dashboardUrl
        }
        exit 0
    }
    catch {
        if (Test-LocalPort 8877) { throw }
    }

    $serverArgs = @($pythonPrefix) + @("-m", "crumblr_trainer.api")
    $server = Start-Process -FilePath $pythonCommand -ArgumentList $serverArgs `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr

    $healthy = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        if ($server.HasExited) { break }
        if (Test-LocalPort 8877) {
            $healthy = $true
            break
        }
    }
    if (-not $healthy) {
        if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force }
        $details = if (Test-Path -LiteralPath $serverErr) { Get-Content -Raw -LiteralPath $serverErr } else { "Geen foutlog beschikbaar." }
        throw "De lokale Trainer kon niet starten. Details: $details"
    }

    $worker = Start-MT5WorkerProcess $pythonCommand $pythonPrefix $mt5Terminal $mt5Experts $workerDirectory $PSScriptRoot $workerOut $workerErr
    Start-Sleep -Seconds 1
    if ($worker.HasExited) {
        Stop-Process -Id $server.Id -Force
        $details = if (Test-Path -LiteralPath $workerErr) { Get-Content -Raw -LiteralPath $workerErr } else { "Geen foutlog beschikbaar." }
        throw "De lokale MT5-worker kon niet starten. Details: $details"
    }

    @{
        version = 1
        started_at = (Get-Date).ToString("o")
        server_pid = $server.Id
        worker_pid = $worker.Id
        python = $pythonCommand
        repository = $PSScriptRoot
    } | ConvertTo-Json | Set-Content -LiteralPath $processPath -Encoding UTF8

    Write-Host "Crumblr Trainer lokaal gestart." -ForegroundColor Green
    Write-Host "Dashboard: $dashboardUrl"
    Write-Host "Data: $trainerData"
    Write-Host "Agent: Groq + Cloudflare review"
    Write-Host "MT5: automatische Strategy Tester-worker actief"
    Write-Host "Stoppen: dubbelklik Stop-Crumblr-Trainer.cmd"
    if (-not $NoBrowser) {
        Start-Process $dashboardUrl
    }
}
finally {
    Pop-Location
    $env:GROQ_API_KEY = $null
    $env:CLOUDFLARE_AI_API_KEY = $null
}
