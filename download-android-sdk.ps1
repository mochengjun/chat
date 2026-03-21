$ProgressPreference = 'SilentlyContinue'
$urls = @{
    "CommandLineTools" = "https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip"
}

$destinations = @{
    "CommandLineTools" = "C:\Android\Sdk\cmdline-tools.zip"
}

foreach ($item in $urls.Keys) {
    Write-Host "Downloading $item..."
    try {
        Invoke-WebRequest -Uri $urls[$item] -OutFile $destinations[$item] -ErrorAction Stop
        $file = Get-Item $destinations[$item]
        Write-Host "Success! Size: $([math]::Round($file.Length / 1MB, 2)) MB"
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)"
        Write-Host "Please download manually from: $($urls[$item])"
    }
}

Write-Host "`nDownload complete!"
