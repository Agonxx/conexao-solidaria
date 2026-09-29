<#
.SYNOPSIS
    Dispara N doacoes concorrentes contra a CampanhasApi (via Kong) para
    demonstrar o fluxo de fila: POST /Doacao/Doar -> RabbitMQ -> DoacaoWorker.

.DESCRIPTION
    Faz login (ou cadastra) um doador de teste, descobre uma campanha ativa
    (ou usa a informada), e dispara varias doacoes em paralelo usando um
    RunspacePool (compativel com Windows PowerShell 5.1, sem depender do
    ForEach-Object -Parallel do PowerShell 7).

    Ideia para o video: rodar este script enquanto a tela mostra, lado a
    lado, o RabbitMQ Management UI (fila crescendo e sendo drenada) e o
    dashboard do Grafana (doacoes_processadas_total subindo).

.EXAMPLE
    .\load-test-doacoes.ps1
    .\load-test-doacoes.ps1 -Count 500 -Concurrency 40 -CampanhaId 3
#>

[CmdletBinding()]
param(
    [string]$KongUrl = "http://localhost:15000",
    [int]$CampanhaId = 0,
    [string]$DoadorEmail = "loadtest@conexaosolidaria.local",
    [string]$DoadorSenha = "LoadTest@123",
    [int]$Count = 300,
    [int]$Concurrency = 20,
    [decimal]$ValorMin = 5,
    [decimal]$ValorMax = 100
)

$ErrorActionPreference = "Stop"

function New-ValidCpf {
    # Gera um CPF com digitos verificadores validos (mesmo algoritmo mod 11 da UsersApi).
    $base = 1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 9 }

    $mult1 = 10, 9, 8, 7, 6, 5, 4, 3, 2
    $soma = 0
    for ($i = 0; $i -lt 9; $i++) { $soma += $base[$i] * $mult1[$i] }
    $resto = $soma % 11
    $d1 = if ($resto -lt 2) { 0 } else { 11 - $resto }

    $comD1 = $base + @($d1)
    $mult2 = 11, 10, 9, 8, 7, 6, 5, 4, 3, 2
    $soma = 0
    for ($i = 0; $i -lt 10; $i++) { $soma += $comD1[$i] * $mult2[$i] }
    $resto = $soma % 11
    $d2 = if ($resto -lt 2) { 0 } else { 11 - $resto }

    return (($base + @($d1, $d2)) -join "")
}

function Get-DoadorToken {
    param([string]$BaseUrl, [string]$Email, [string]$Senha)

    try {
        $resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/Usuario/Auth" `
            -ContentType "application/json" `
            -Body (@{ email = $Email; senha = $Senha } | ConvertTo-Json)
        Write-Host "Login ok ($Email)." -ForegroundColor Green
        return $resp.token
    }
    catch {
        Write-Host "Login falhou, cadastrando doador de teste ($Email)..." -ForegroundColor Yellow
        $cpf = New-ValidCpf
        Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/Usuario/Cadastro" `
            -ContentType "application/json" `
            -Body (@{ nomeCompleto = "Doador Load Test"; email = $Email; cpf = $cpf; senha = $Senha } | ConvertTo-Json) | Out-Null

        $resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/Usuario/Auth" `
            -ContentType "application/json" `
            -Body (@{ email = $Email; senha = $Senha } | ConvertTo-Json)
        Write-Host "Cadastro + login ok ($Email)." -ForegroundColor Green
        return $resp.token
    }
}

function Get-CampanhaAtivaId {
    param([string]$BaseUrl)

    $campanhas = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/Campanha/Transparencia"
    if (-not $campanhas -or $campanhas.Count -eq 0) {
        throw "Nenhuma campanha ativa encontrada em /api/Campanha/Transparencia. Crie uma campanha antes de rodar o load test (ou passe -CampanhaId)."
    }
    return $campanhas[0].id
}

# --- Setup ---

$token = Get-DoadorToken -BaseUrl $KongUrl -Email $DoadorEmail -Senha $DoadorSenha

if ($CampanhaId -le 0) {
    $CampanhaId = Get-CampanhaAtivaId -BaseUrl $KongUrl
}
Write-Host "Campanha alvo: Id=$CampanhaId" -ForegroundColor Cyan
Write-Host "Disparando $Count doacoes com concorrencia $Concurrency contra $KongUrl ..." -ForegroundColor Cyan
Write-Host "Dica: abra o RabbitMQ Management (http://localhost:15672) e o Grafana agora, para ver a fila enchendo/esvaziando em tempo real." -ForegroundColor DarkGray

# --- Runspace pool (concorrencia real em PowerShell 5.1) ---

$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [runspacefactory]::CreateRunspacePool(1, $Concurrency, $sessionState, $Host)
$pool.Open()

$scriptBlock = {
    param($BaseUrl, $Token, $IdCampanha, $Valor)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $body = @{ idCampanha = $IdCampanha; valorDoacao = $Valor } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/Doacao/Doar" `
            -Headers @{ Authorization = "Bearer $Token" } `
            -ContentType "application/json" `
            -Body $body | Out-Null
        [pscustomobject]@{ Ok = $true; Ms = $sw.ElapsedMilliseconds; Erro = $null }
    }
    catch {
        [pscustomobject]@{ Ok = $false; Ms = $sw.ElapsedMilliseconds; Erro = $_.Exception.Message }
    }
}

$jobs = New-Object System.Collections.Generic.List[object]
$stopwatchTotal = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 0; $i -lt $Count; $i++) {
    $valor = [Math]::Round((Get-Random -Minimum ([double]$ValorMin) -Maximum ([double]$ValorMax)), 2)

    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($scriptBlock).AddArgument($KongUrl).AddArgument($token).AddArgument($CampanhaId).AddArgument($valor)

    $jobs.Add([pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() })
}

$results = foreach ($job in $jobs) {
    $job.Pipe.EndInvoke($job.Handle)
    $job.Pipe.Dispose()
}

$stopwatchTotal.Stop()
$pool.Close()
$pool.Dispose()

# --- Resumo ---

$ok = ($results | Where-Object Ok).Count
$fail = ($results | Where-Object { -not $_.Ok }).Count
$avgMs = if ($results.Count -gt 0) { [Math]::Round(($results | Measure-Object -Property Ms -Average).Average, 0) } else { 0 }

Write-Host ""
Write-Host "=== Resultado ===" -ForegroundColor Cyan
Write-Host "Total:      $Count"
Write-Host "Sucesso:    $ok" -ForegroundColor Green
Write-Host "Falha:      $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "Tempo total: $([Math]::Round($stopwatchTotal.Elapsed.TotalSeconds, 1)) s"
Write-Host "Latencia media por request: $avgMs ms"
Write-Host "Requests/seg (disparo): $([Math]::Round($Count / $stopwatchTotal.Elapsed.TotalSeconds, 1))"

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Exemplos de erro:" -ForegroundColor Yellow
    $results | Where-Object { -not $_.Ok } | Select-Object -First 5 -ExpandProperty Erro
}

Write-Host ""
Write-Host "Confira agora em /api/Campanha/Transparencia se o ValorArrecadado da campanha $CampanhaId ja reflete todas as doacoes (o Worker processa de forma assincrona, pode levar alguns segundos)." -ForegroundColor DarkGray
