# Android SDK PATH Configuration Script
$androidPaths = @(
    "C:\Android\Sdk\platform-tools",
    "C:\Android\Sdk\emulator",
    "C:\Android\Sdk\cmdline-tools\latest\bin",
    "C:\Android\Sdk\tools",
    "C:\Android\Sdk\tools\bin"
)

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Add each path if not already present
$updated = $false
foreach ($path in $androidPaths) {
    if ($currentPath -notlike "*$path*") {
        $currentPath += ";$path"
        Write-Host "Added to PATH: $path" -ForegroundColor Green
        $updated = $true
    } else {
        Write-Host "Already in PATH: $path" -ForegroundColor Yellow
    }
}

# Save updated PATH
if ($updated) {
    [Environment]::SetEnvironmentVariable("Path", $currentPath, "User")
    Write-Host "`nPATH updated successfully!" -ForegroundColor Cyan
} else {
    Write-Host "`nNo updates needed." -ForegroundColor Cyan
}

Write-Host "`nEnvironment Variables Set:" -ForegroundColor Cyan
Write-Host "ANDROID_SDK_ROOT = C:\Android\Sdk"
Write-Host "ANDROID_HOME = C:\Android\Sdk"
Write-Host "`nPlease restart your terminal for changes to take effect." -ForegroundColor Yellow
