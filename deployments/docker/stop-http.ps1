# Stop processes on port 80 and 8081
Write-Host "Stopping HTTP listeners..."

# Stop background jobs
Get-Job | Stop-Job -ErrorAction SilentlyContinue
Get-Job | Remove-Job -ErrorAction SilentlyContinue

# Find processes on port 80
$listeners80 = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
foreach ($l in $listeners80) {
    $proc = Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -ne "System") {
        Write-Host "Stopping $($proc.ProcessName) on port 80"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

# Find processes on port 8081
$listeners8081 = Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue
foreach ($l in $listeners8081) {
    $proc = Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -ne "System") {
        Write-Host "Stopping $($proc.ProcessName) on port 8081"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

# Restart IIS
Write-Host "Restarting IIS..."
iisreset /restart

Start-Sleep -Seconds 3
Write-Host "Done!"

# Verify
$listeners = Get-NetTCPConnection -LocalPort 80, 8081 -State Listen -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Current listeners:"
$listeners | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    Write-Host "  Port $($_.LocalPort): $($p.ProcessName)"
}
