# IIS Installation and Configuration Script
# For Windows Server - No WSL2 required

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "IIS Installation and Configuration" -ForegroundColor Cyan
Write-Host "Server IP: 8.130.55.126" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Install IIS
Write-Host "Step 1: Installing IIS..." -ForegroundColor Yellow

# Check if IIS is already installed
$iisFeature = Get-WindowsFeature -Name Web-Server -ErrorAction SilentlyContinue

if ($iisFeature -and $iisFeature.Installed) {
    Write-Host "IIS is already installed" -ForegroundColor Green
} else {
    Write-Host "Installing IIS and required features..." -ForegroundColor Yellow
    
    # Install IIS with common features
    $features = @(
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Health",
        "Web-Http-Logging",
        "Web-Request-Monitor",
        "Web-Security",
        "Web-Filtering",
        "Web-Performance",
        "Web-Stat-Compression",
        "Web-Dyn-Compression",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console"
    )
    
    foreach ($feature in $features) {
        $result = Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction SilentlyContinue
        if ($result.Success) {
            Write-Host "  Installed: $feature" -ForegroundColor Green
        }
    }
    
    Write-Host "IIS installation completed" -ForegroundColor Green
}

# 2. Create website directory
Write-Host ""
Write-Host "Step 2: Creating website directory..." -ForegroundColor Yellow

$sitePath = "C:\inetpub\wwwroot\chat"
New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
Write-Host "Website directory: $sitePath" -ForegroundColor Green

# 3. Create default page
Write-Host ""
Write-Host "Step 3: Creating default web page..." -ForegroundColor Yellow

$defaultPage = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Secure Chat Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
        .status { background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .api-section { background: #f0f0f0; padding: 15px; border-radius: 5px; margin: 10px 0; }
        code { background: #e0e0e0; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Secure Chat Server</h1>
        <div class="status">
            <strong>Status:</strong> Running<br>
            <strong>Server IP:</strong> 8.130.55.126<br>
            <strong>Time:</strong> <span id="time"></span>
        </div>
        
        <h2>API Endpoints</h2>
        <div class="api-section">
            <h3>Health Check</h3>
            <code>GET /health</code> - Service health status
        </div>
        <div class="api-section">
            <h3>API Base</h3>
            <code>GET /api/v1/</code> - API root endpoint
        </div>
        <div class="api-section">
            <h3>WebSocket</h3>
            <code>WS /api/v1/ws</code> - WebSocket connection
        </div>
        
        <h2>Access URLs</h2>
        <ul>
            <li><a href="/health">Health Check</a></li>
            <li>API: http://8.130.55.126:8081/</li>
        </ul>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
"@

Set-Content -Path "$sitePath\index.html" -Value $defaultPage -Encoding UTF8
Write-Host "Default page created" -ForegroundColor Green

# 4. Create health check file
Write-Host ""
Write-Host "Step 4: Creating health check endpoint..." -ForegroundColor Yellow

$healthContent = @{
    status = "healthy"
    server = "8.130.55.126"
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    services = @{
        http = "running"
        api = "running"
    }
} | ConvertTo-Json

Set-Content -Path "$sitePath\health" -Value $healthContent -Encoding UTF8
Write-Host "Health check endpoint created" -ForegroundColor Green

# 5. Create API directory and files
Write-Host ""
Write-Host "Step 5: Creating API endpoints..." -ForegroundColor Yellow

$apiPath = "$sitePath\api\v1"
New-Item -Path $apiPath -ItemType Directory -Force | Out-Null

$apiResponse = @{
    message = "Secure Chat API v1"
    server = "8.130.55.126"
    endpoints = @(
        "/api/v1/auth - Authentication"
        "/api/v1/users - User management"
        "/api/v1/messages - Messages"
        "/api/v1/ws - WebSocket"
    )
} | ConvertTo-Json

Set-Content -Path "$apiPath\index.html" -Value $apiResponse -Encoding UTF8
Write-Host "API endpoints created" -ForegroundColor Green

# 6. Configure IIS Site
Write-Host ""
Write-Host "Step 6: Configuring IIS website..." -ForegroundColor Yellow

Import-Module WebAdministration -ErrorAction SilentlyContinue

# Remove default site if exists
Remove-Website -Name "Default Web Site" -ErrorAction SilentlyContinue

# Create new site
$siteName = "SecureChat"
$port = 80

# Check if site already exists
$existingSite = Get-Website -Name $siteName -ErrorAction SilentlyContinue
if ($existingSite) {
    Remove-Website -Name $siteName
    Write-Host "Removed existing site" -ForegroundColor Gray
}

# Create application pool
$appPoolName = "SecureChatPool"
if (!(Test-Path "IIS:\AppPools\$appPoolName")) {
    New-WebAppPool -Name $appPoolName
    Write-Host "Created application pool: $appPoolName" -ForegroundColor Green
}

# Create website
New-Website -Name $siteName -Port $port -PhysicalPath $sitePath -ApplicationPool $appPoolName
Write-Host "Created website: $siteName on port $port" -ForegroundColor Green

# Start the site
Start-Website -Name $siteName
Write-Host "Website started" -ForegroundColor Green

# 7. Configure firewall
Write-Host ""
Write-Host "Step 7: Configuring firewall..." -ForegroundColor Yellow

# Ensure port 80 is open
$rule80 = Get-NetFirewallRule -Name "HTTP" -ErrorAction SilentlyContinue
if (!$rule80) {
    New-NetFirewallRule -Name "HTTP" -DisplayName "HTTP (80)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 80
    Write-Host "Opened port 80" -ForegroundColor Green
} else {
    Write-Host "Port 80 already open" -ForegroundColor Green
}

# Ensure port 8081 is open
$rule8081 = Get-NetFirewallRule -Name "API" -ErrorAction SilentlyContinue
if (!$rule8081) {
    New-NetFirewallRule -Name "API" -DisplayName "API (8081)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 8081
    Write-Host "Opened port 8081" -ForegroundColor Green
} else {
    Write-Host "Port 8081 already open" -ForegroundColor Green
}

# 8. Test local access
Write-Host ""
Write-Host "Step 8: Testing local access..." -ForegroundColor Yellow

Start-Sleep -Seconds 3

try {
    $response = Invoke-WebRequest -Uri "http://localhost/" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Port 80 (IIS): OK - Status $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Port 80 (IIS): Error - $_" -ForegroundColor Red
}

try {
    $response = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Health Check: OK" -ForegroundColor Green
} catch {
    Write-Host "Health Check: Error - $_" -ForegroundColor Red
}

# 9. Show status
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "IIS Configuration Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Website Information:" -ForegroundColor White
Write-Host "  Name: $siteName" -ForegroundColor Gray
Write-Host "  Path: $sitePath" -ForegroundColor Gray
Write-Host "  Port: $port" -ForegroundColor Gray
Write-Host ""
Write-Host "External Access URLs:" -ForegroundColor White
Write-Host "  Home:      http://8.130.55.126/" -ForegroundColor Cyan
Write-Host "  Health:    http://8.130.55.126/health" -ForegroundColor Cyan
Write-Host "  API:       http://8.130.55.126/api/v1/" -ForegroundColor Cyan
Write-Host "  API Port:  http://8.130.55.126:8081/" -ForegroundColor Cyan
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor White
Write-Host "  Start:   Start-Website -Name '$siteName'" -ForegroundColor Gray
Write-Host "  Stop:    Stop-Website -Name '$siteName'" -ForegroundColor Gray
Write-Host "  Restart: Restart-WebAppPool -Name '$appPoolName'" -ForegroundColor Gray
Write-Host "  Status:  Get-Website" -ForegroundColor Gray
