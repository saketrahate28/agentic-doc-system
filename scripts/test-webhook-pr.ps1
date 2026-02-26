<#
.SYNOPSIS
    Dynamically test the n8n PR-merge webhook. All values are auto-generated or passed as params.

.PARAMETER WebhookUrl     Required. n8n production webhook URL.
.PARAMETER AuthToken      Required. X-Auth-Token value (set in n8n Webhook node).
.PARAMETER JiraId         Optional. Jira story key e.g. DEMO-1. Auto-reads from git branch/commit if omitted.
.PARAMETER PageId         Optional. Confluence page ID. Defaults to env var or 688129.
.PARAMETER PrTitle        Optional. PR title. Auto-generated from current branch + JiraId if omitted.
.PARAMETER Author         Optional. PR author. Defaults to current git user.
.PARAMETER DbFiles        Optional. Comma-separated DB file paths. Auto-detected from git diff if omitted.
.PARAMETER DryRun         Switch. Print payload without sending it.

.EXAMPLE
    # Fully automatic — reads everything from git
    .\test-webhook-pr.ps1 -WebhookUrl "https://xxxx.ngrok-free.app/webhook/doc-sync" -AuthToken "mysecret123"

.EXAMPLE
    # Override specific values
    .\test-webhook-pr.ps1 -WebhookUrl "..." -AuthToken "..." -JiraId "DEMO-3" -Author "John Doe"
#>

param(
    [Parameter(Mandatory = $true)]  [string]$WebhookUrl,
    [Parameter(Mandatory = $true)]  [string]$AuthToken,
    [string]$JiraId = "",
    [string]$PageId = "",
    [string]$PrTitle = "",
    [string]$Author = "",
    [string]$DbFiles = "",
    [switch]$DryRun
)

# ─── Auto-detect from git ─────────────────────────────────────────────────────

function Get-GitValue([string]$command) {
    try { return (Invoke-Expression "git $command 2>$null").Trim() } catch { return "" }
}

# Jira ID: extract from branch name or last commit message (e.g. DEMO-1, SCRUM-42)
if (-not $JiraId) {
    $branch = Get-GitValue "rev-parse --abbrev-ref HEAD"
    $commit = Get-GitValue "log -1 --pretty=%s"
    $pattern = "[A-Z]+-[0-9]+"
    $JiraId = ([regex]::Match("$branch $commit", $pattern)).Value
    if (-not $JiraId) { $JiraId = "NO-JIRA-ID" }
}

# Author: current git user
if (-not $Author) {
    $Author = Get-GitValue "config user.name"
    if (-not $Author) { $Author = $env:USERNAME }
}

# Page ID: env var or default
if (-not $PageId) {
    $PageId = if ($env:CONFLUENCE_PAGE_ID) { $env:CONFLUENCE_PAGE_ID } else { "688129" }
}

# PR title: auto-generate
if (-not $PrTitle) {
    $lastCommit = Get-GitValue "log -1 --pretty=%s"
    $PrTitle = if ($lastCommit) { $lastCommit } else { "$JiraId - Code changes" }
}

# DB files: detect .sql or migration files from last git diff
if (-not $DbFiles) {
    try {
        $changed = (git diff --name-only HEAD~1 HEAD 2>$null)
        $dbMatches = $changed | Where-Object { $_ -match '\.(sql)$|[Dd]atabase|[Mm]igration|[Ss]cripts?' }
        $DbFiles = if ($dbMatches) { $dbMatches -join " | " } else { "No DB scripts detected in diff" }
    }
    catch {
        $DbFiles = "No DB scripts detected in diff"
    }
}

# Auto mock PR number from run count
$PrNumber = Get-Random -Minimum 10 -Maximum 999
$Branch = Get-GitValue "rev-parse --abbrev-ref HEAD"
$RepoUrl = Get-GitValue "remote get-url origin"
$Repo = if ($RepoUrl -match "github\.com[:/](.+?)(?:\.git)?$") { $matches[1] } else { "local/repo" }
$PrUrl = "https://github.com/$Repo/pull/$PrNumber"

# DB SQL diff for context
$rawDiff = try { (git diff HEAD~1 HEAD -- "*.sql" 2>$null | Select-Object -First 50) -join "`n" } catch { "" }
if (-not $rawDiff) { $rawDiff = "-- Simulated SQL: CREATE TABLE IF NOT EXISTS ${JiraId}_log (id INT PRIMARY KEY, action VARCHAR(100), ts DATETIME);" }
$DbDiffB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($rawDiff))

# ─── Build payload ────────────────────────────────────────────────────────────

$payload = [ordered]@{
    jira_id        = $JiraId
    author         = $Author
    reviewer       = "Morgan Housel"
    pr_number      = "$PrNumber"
    pr_title       = $PrTitle
    pr_url         = $PrUrl
    branch         = $Branch
    db_files       = $DbFiles
    has_db_changes = ($DbFiles -notlike "*No DB*").ToString().ToLower()
    db_diff_base64 = $DbDiffB64
    repository     = $Repo
    page_id        = $PageId
    timestamp      = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 3

# ─── Display summary ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PR Merge -> Confluence Table (Dynamic Test)   " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Jira Story : $JiraId"    -ForegroundColor Yellow
Write-Host "Author     : $Author"    -ForegroundColor Yellow
Write-Host "Reviewer   : Morgan Housel" -ForegroundColor Yellow
Write-Host "PR         : #$PrNumber - $PrTitle" -ForegroundColor Yellow
Write-Host "Branch     : $Branch"    -ForegroundColor Yellow
Write-Host "DB Files   : $DbFiles"   -ForegroundColor Yellow
Write-Host "Page ID    : $PageId"    -ForegroundColor Yellow
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN - Payload (not sent):" -ForegroundColor Magenta
    Write-Host $payload
    exit 0
}

# ─── Send webhook ─────────────────────────────────────────────────────────────

Write-Host "Sending to n8n..." -ForegroundColor Green

try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post `
        -Body $payload `
        -ContentType "application/json" `
        -Headers @{ "X-Auth-Token" = $AuthToken }

    Write-Host ""
    Write-Host "SUCCESS - Webhook accepted!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now check:" -ForegroundColor Cyan
    Write-Host "  1. n8n Executions tab: http://localhost:5678" -ForegroundColor White
    Write-Host "  2. Confluence page: https://pikachu28.atlassian.net/wiki/spaces/ED1/pages/$PageId" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
