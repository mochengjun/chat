# Get current PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Define paths to add
$pathsToAdd = @(
    "C:\Android\Sdk\platform-tools",
    "C:\Android\Sdk\emulator",
    "C:\Android\Sdk\cmdline-tools\latest\bin"
)

# Add each path
foreach ($pathToAdd in $pathsToAdd) {
    if ($currentPath -notlike "*$pathToAdd*") {
        $currentPath = $currentPath + ";" + $pathToAdd
        Write-Host "Added: $pathToAdd" -ForegroundColor Green
    } else {
        Write-Host "Already exists: $pathToAdd" -ForegroundColor Yellow
    }
}

# Save
[Environment]::SetEnvironmentVariable("Path", $currentPath, "User")
Write-Host "`nPATH updated successfully!" -ForegroundColor Cyan
