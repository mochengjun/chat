# ZeroTier One Docker网络解决方案
# 通过虚拟网络解决Docker镜像拉取问题

Write-Host "=== ZeroTier One Docker网络配置 ===" -ForegroundColor Green

# 检查ZeroTier是否已安装
Write-Host "`n1. 检查ZeroTier安装状态：" -ForegroundColor Yellow
try {
    $ztService = Get-Service "ZeroTier One" -ErrorAction Stop
    Write-Host "✓ ZeroTier One 已安装" -ForegroundColor Green
    Write-Host "服务状态: $($ztService.Status)"
} catch {
    Write-Host "✗ ZeroTier One 未安装" -ForegroundColor Red
    Write-Host "请先安装: choco install zerotier-one -y" -ForegroundColor Yellow
    exit 1
}

# 启动ZeroTier服务
Write-Host "`n2. 启动ZeroTier服务：" -ForegroundColor Yellow
try {
    Start-Service "ZeroTier One" -ErrorAction Stop
    Write-Host "✓ ZeroTier服务已启动" -ForegroundColor Green
} catch {
    Write-Host "⚠ ZeroTier服务启动失败: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 等待服务初始化
Start-Sleep -Seconds 5

# 获取本机ZeroTier地址
Write-Host "`n3. 获取ZeroTier节点信息：" -ForegroundColor Yellow
try {
    $ztInfo = & "C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat" info
    Write-Host "ZeroTier Info: $ztInfo"
    
    # 提取节点ID
    if ($ztInfo -match '([0-9a-f]{10})') {
        $nodeId = $matches[1]
        Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ 无法获取ZeroTier信息: $($_.Exception.Message)" -ForegroundColor Red
}

# 创建网络加入脚本
Write-Host "`n4. 创建网络配置脚本：" -ForegroundColor Yellow

$networkSetupScript = @"
# ZeroTier网络配置脚本
# 请替换为您的网络ID

# 加入ZeroTier网络
`"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat`" join YOUR_NETWORK_ID

# 等待网络连接
Start-Sleep -Seconds 10

# 验证网络连接
`"C:\Program Files (x86)\ZeroTier\One\zerotier-cli.bat`" listnetworks
"@

$networkSetupScript | Out-File -FilePath "C:\Users\MCJ\source\quest\chat\join_zerotier_network.bat" -Encoding UTF8
Write-Host "已创建网络加入脚本: join_zerotier_network.bat" -ForegroundColor Green

# 创建Docker网络配置
Write-Host "`n5. 创建Docker网络配置：" -ForegroundColor Yellow

$dockerNetworkConfig = @{
    "proxies" = @{
        "default" = @{
            "httpProxy" = "http://127.0.0.1:9993"
            "httpsProxy" = "http://127.0.0.1:9993"
            "noProxy" = "localhost,127.0.0.1,hubproxy.docker.internal"
        }
    }
}

$configPath = "$env:ProgramData\docker\config\daemon.json"
if (Test-Path $configPath) {
    $currentConfig = Get-Content $configPath | ConvertFrom-Json
    # 合并配置
    $mergedConfig = $currentConfig | Add-Member -MemberType NoteProperty -Name "proxies" -Value $dockerNetworkConfig.proxies -PassThru
} else {
    $mergedConfig = $dockerNetworkConfig
}

$mergedConfig | ConvertTo-Json -Depth 4 | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "已更新Docker代理配置" -ForegroundColor Green

Write-Host "`n=== 配置完成 ===" -ForegroundColor Green
Write-Host "下一步操作：" -ForegroundColor Cyan
Write-Host "1. 在ZeroTier Central创建网络并获取网络ID" -ForegroundColor White
Write-Host "2. 编辑 join_zerotier_network.bat，替换 YOUR_NETWORK_ID" -ForegroundColor White
Write-Host "3. 运行 join_zerotier_network.bat 加入网络" -ForegroundColor White
Write-Host "4. 在ZeroTier Central授权此节点" -ForegroundColor White
Write-Host "5. 重启Docker服务" -ForegroundColor White
Write-Host "6. 测试Docker镜像拉取" -ForegroundColor White