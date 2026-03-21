@echo off
cd /d "%~dp0apps\flutter_app"
echo 清理构建缓存...
flutter clean
echo.
echo 获取依赖...
flutter pub get
echo.
echo 构建 Windows Release...
flutter build windows --release
echo.
if exist "build\windows\x64\runner\Release\sec_chat.exe" (
    echo [OK] 构建成功!
    echo 输出目录：build\windows\x64\runner\Release\
) else (
    echo [错误] 构建失败
    exit /b 1
)
