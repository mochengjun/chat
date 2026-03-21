$flutterPath = "C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin"
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($currentPath -notlike "*flutter\bin*") {
    $newPath = $currentPath + ";" + $flutterPath
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Flutter已成功添加到PATH环境变量"
    Write-Host "Flutter路径: $flutterPath"
} else {
    Write-Host "Flutter已在PATH中"
}

Write-Host "`n当前PATH内容:"
[Environment]::GetEnvironmentVariable("Path", "User")
