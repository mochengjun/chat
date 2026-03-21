@echo off
chcp 65001 >nul
echo ========================================
echo 性能优化快速验证脚本
echo ========================================
echo.

cd /d c:\Users\HZHF\source\chat\web-client

echo [1/3] 清理构建缓存...
if exist dist rd /s /q dist
if exist node_modules\.vite rd /s /q node_modules\.vite
echo ✓ 缓存已清理
echo.

echo [2/3] 执行生产环境构建...
call npm run build
if %errorlevel% neq 0 (
    echo ✗ 构建失败
    pause
    exit /b 1
)
echo ✓ 构建完成
echo.

echo [3/3] 分析构建结果...
if exist dist\assets (
    echo.
    echo 📊 包体积统计:
    echo ========================================
    for %%f in (dist\assets\*.js) do (
        for %%A in ("%%f") do (
            echo %%~nxA: %%~zA bytes
        )
    )
    echo ========================================
    echo.
    
    rem 统计文件数量
    set js_count=0
    for %%f in (dist\assets\*.js) do set /a js_count+=1
    
    echo ✓ 共生成 %js_count% 个 JavaScript 文件
    echo.
    
    if %js_count% gtr 1 (
        echo ✅ 代码分割生效！
    ) else (
        echo ⚠️  代码分割未生效，请检查 vite.config.ts 配置
    )
) else (
    echo ✗ 未找到 dist\assets 目录
)

echo.
echo ========================================
echo 验证完成
echo ========================================
echo.
echo 下一步:
echo 1. 运行 npm run dev 启动开发服务器
echo 2. 使用 Chrome DevTools 测量性能指标
echo 3. 查看 test-results/performance-report.md 了解详细报告
echo.
pause
