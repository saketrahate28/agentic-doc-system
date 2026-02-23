<#
.SYNOPSIS
    Test the n8n webhook with a simulated PR merge payload (Use Case A).

.DESCRIPTION
    Sends a mock PR-merge payload to your n8n webhook URL to simulate
    what GitHub Actions sends when a PR with a DEMO-X Jira story is merged.

.PARAMETER WebhookUrl
    The n8n webhook production URL.

.PARAMETER AuthToken
    The X-Auth-Token header value.

.PARAMETER PageId
    The Confluence page ID. Defaults to 688129.

.PARAMETER JiraId
    The Jira story ID. Defaults to DEMO-1.

.EXAMPLE
    .\test-webhook-pr.ps1 -WebhookUrl "https://xxxx.ngrok-free.app/webhook/doc-sync" -AuthToken "mysecret123"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl,

    [Parameter(Mandatory = $true)]
    [string]$AuthToken,

    [string]$PageId = "688129",
    [string]$JiraId = "DEMO-1"
)

# Simulate a DB script change (what GitHub Actions would detect)
$dbFiles = "Database/Scripts/auth/DEMO-1_add_auth_logging.sql | Database/Scripts/auth/DEMO-1_session_table.sql"

# Build payload mimicking what GitHub Actions sends on PR merge
$payload = @{
    jira_id        = $JiraId
    author         = "saketrahate28"
    reviewer       = "Morgan Housel"
    pr_number      = "42"
    pr_title       = "$JiraId Add database authentication logging"
    pr_url         = "https://github.com/saketrahate28/agentic-doc-system/pull/42"
    branch         = "feature/$JiraId-auth-logging"
    db_files       = $dbFiles
    has_db_changes = "true"
    db_diff_base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("CREATE TABLE auth_log (id INT, user_id INT, action VARCHAR(50), timestamp DATETIME);"))
    repository     = "saketrahate28/agentic-doc-system"
    page_id        = $PageId
    timestamp      = (Get-Date -Format "o")
} | ConvertTo-Json -Depth 3

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PR Merge -> Confluence Table Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Jira Story: $JiraId" -ForegroundColor Yellow
Write-Host "Author:     saketrahate28" -ForegroundColor Yellow
Write-Host "Reviewer:   Morgan Housel" -ForegroundColor Yellow
Write-Host "PR:         #42 - $JiraId Add database authentication logging" -ForegroundColor Yellow
Write-Host "DB Files:   $dbFiles" -ForegroundColor Yellow
Write-Host ""
Write-Host "Sending payload to n8n..." -ForegroundColor Green

try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post `
        -Body $payload `
        -ContentType "application/json" `
        -Headers @{ "X-Auth-Token" = $AuthToken }

    Write-Host ""
    Write-Host "SUCCESS! Webhook accepted." -ForegroundColor Green
    Write-Host ""
    Write-Host "Now check:" -ForegroundColor Cyan
    Write-Host "  1. n8n Executions tab — all nodes should be green" -ForegroundColor White
    Write-Host "  2. Confluence page — new row should appear:" -ForegroundColor White
    Write-Host "     https://pikachu28.atlassian.net/wiki/spaces/ED1/pages/$PageId" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "FAILED! Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
