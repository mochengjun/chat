$src = "C:\Users\MCJ\source\quest\chat"
$dst = "C:\sec-chat"
$exclude = @('.git', 'node_modules', '.dart_tool', 'build', '.vite')

Write-Host "Copying project to $dst..."

# Ensure destination exists
if (-not (Test-Path $dst)) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
}

# Copy directories and files, excluding large/unnecessary dirs
Get-ChildItem -Path $src -Force | Where-Object { $_.Name -notin $exclude } | ForEach-Object {
    $target = Join-Path $dst $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Path $_.FullName -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Copied dir: $($_.Name)"
    } else {
        Copy-Item -Path $_.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        Write-Host "  Copied file: $($_.Name)"
    }
}

# Also copy web-client node_modules (needed for build context, but dist is enough)
# Actually we need the dist files - ensure they exist
$webDist = Join-Path $src "web-client\dist"
if (Test-Path $webDist) {
    $dstDist = Join-Path $dst "web-client\dist"
    Copy-Item -Path $webDist -Destination $dstDist -Recurse -Force
    Write-Host "  Copied web-client dist"
}

Write-Host "Copy complete!"
