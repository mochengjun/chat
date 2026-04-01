# Simple HTTP Server for Port Testing
# This creates a basic HTTP listener on ports 80 and 8081

Write-Host "Starting simple HTTP listeners for port testing..."
Write-Host ""

# Create a simple HTTP listener function
function Start-HttpListener {
    param([int]$Port)
    
    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://+:$Port/")
        $listener.Start()
        
        Write-Host "HTTP listener started on port $Port"
        
        # Handle requests in a loop
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $response = $context.Response
            
            $responseString = "Healthy - Port $Port is working! Server: 8.130.55.126"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
            
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        }
    } catch {
        Write-Host "Error on port $Port : $_"
    }
}

# Start listeners on port 80 and 8081
Write-Host "Starting HTTP listener on port 80..."
Start-Job -ScriptBlock {
    param($Port)
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/")
    $listener.Start()
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $response = $context.Response
            $responseString = "Healthy - Port 80 (HTTP) - Server: 8.130.55.126"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } catch {}
    }
} -ArgumentList 80

Write-Host "Starting HTTP listener on port 8081..."
Start-Job -ScriptBlock {
    param($Port)
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/")
    $listener.Start()
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $response = $context.Response
            $responseString = "Healthy - Port 8081 (API) - Server: 8.130.55.126"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
            $response.ContentLength64 = $buffer.Length
            $response.StatusCode = 200
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } catch {}
    }
} -ArgumentList 8081

Start-Sleep -Seconds 3

# Test local endpoints
Write-Host ""
Write-Host "Testing local endpoints..."

try {
    $r = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Port 80: OK - $($r.Content)"
} catch {
    Write-Host "Port 80: Error - $_"
}

try {
    $r = Invoke-WebRequest -Uri "http://localhost:8081/health" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Port 8081: OK - $($r.Content)"
} catch {
    Write-Host "Port 8081: Error - $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "HTTP listeners are running!"
Write-Host "=========================================="
Write-Host ""
Write-Host "External access URLs:"
Write-Host "  http://8.130.55.126/"
Write-Host "  http://8.130.55.126:8081/"
Write-Host ""
Write-Host "Press Ctrl+C to stop..."
Write-Host ""

# Keep running
while ($true) {
    Start-Sleep -Seconds 60
    Write-Host "$(Get-Date) - Service running..."
}
