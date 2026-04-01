# Check and Fix Port Listeners
Write-Host "Checking port 80 and 8081..."

# Show current listeners
Write-Host "`nCurrent listeners:"
netstat -ano | findstr ":80 "
netstat -ano | findstr ":8081 "

# Check IIS status
Write-Host "`nIIS Status:"
net start w3svc

# Get IIS site status
Write-Host "`nIIS Sites:"
Get-Website

# Kill any powershell processes that might be running HTTP listeners
Write-Host "`nStopping any PowerShell HTTP listeners..."
Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | Stop-Process -Force -ErrorAction SilentlyContinue

# Reset IIS
Write-Host "`nResetting IIS..."
iisreset

Start-Sleep -Seconds 5

# Final check
Write-Host "`nFinal port status:"
netstat -ano | findstr ":80 "
netstat -ano | findstr ":8081 "

Write-Host "`nTesting IIS..."
try {
    $r = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -TimeoutSec 5
    Write-Host "IIS Response: $($r.StatusCode)"
    Write-Host "Content: $($r.Content.Substring(0, [Math]::Min(100, $r.Content.Length)))"
} catch {
    Write-Host "Error: $_"
}
