<#
.SYNOPSIS
    Test the n8n webhook endpoint with a mock payload.

.DESCRIPTION
    Sends a sample git-diff payload to your n8n webhook URL
    to verify the Confluence update pipeline works end-to-end.

.PARAMETER WebhookUrl
    The n8n webhook production URL.

.PARAMETER AuthToken
    The X-Auth-Token header value for webhook authentication.

.PARAMETER PageId
    The Confluence page ID to update. Defaults to 688129 (sandbox).

.EXAMPLE
    .\test-webhook.ps1 -WebhookUrl "https://your.app.n8n.cloud/webhook/doc-sync" -AuthToken "mysecret"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WebhookUrl,

    [Parameter(Mandatory = $true)]
    [string]$AuthToken,

    [string]$PageId = "688129"
)

# Sample diff content (simulates what GitHub Actions would send)
$sampleDiff = @"
diff --git a/src/auth.py b/src/auth.py
index abc1234..def5678 100644
--- a/src/auth.py
+++ b/src/auth.py
@@ -50,6 +50,15 @@ class AuthService:
     def register_user(self, email, name, password, role="viewer"):
         # existing code...
         pass
+
+    def reset_password(self, email: str, new_password: str) -> bool:
+        '''Reset a user's password.
+
+        Args:
+            email: The user's email address.
+            new_password: The new password to set.
+
+        Returns:
+            True if password was reset successfully.
+        '''
+        user = self._find_user_by_email(email)
+        if user is None:
+            raise AuthenticationError("User not found")
+        return True
"@

# Base64 encode the diff
$diffBytes = [System.Text.Encoding]::UTF8.GetBytes($sampleDiff)
$diffBase64 = [Convert]::ToBase64String($diffBytes)

# Build the payload
$payload = @{
    repository     = "your-username/agentic-doc-system"
    commit_message = "feat: add password reset [DocUpdate: $PageId]"
    author         = "Test User"
    page_id        = $PageId
    diff_base64    = $diffBase64
    timestamp      = (Get-Date -Format "o")
    run_url        = "https://github.com/test/actions/runs/0"
} | ConvertTo-Json -Depth 3

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  n8n Webhook Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target:   $WebhookUrl" -ForegroundColor Yellow
Write-Host "Page ID:  $PageId" -ForegroundColor Yellow
Write-Host ""
Write-Host "Sending payload..." -ForegroundColor Green

try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -ContentType "application/json" -Headers @{
        "X-Auth-Token" = $AuthToken
    }
    Write-Host ""
    Write-Host "SUCCESS! Response:" -ForegroundColor Green
    $response | ConvertTo-Json -Depth 5 | Write-Host
}
catch {
    Write-Host ""
    Write-Host "FAILED! Error:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Check n8n execution log for this workflow" -ForegroundColor White
Write-Host "  2. Open Confluence page: https://pikachu28.atlassian.net/wiki/spaces/ED1/pages/$PageId" -ForegroundColor White
Write-Host "  3. Verify the page content was updated" -ForegroundColor White
Write-Host "  4. Check page version history incremented" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
