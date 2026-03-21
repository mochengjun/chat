@echo off
echo Configuring Android SDK Environment Variables...
echo.

echo Setting ANDROID_SDK_ROOT...
setx ANDROID_SDK_ROOT "C:\Android\Sdk" >nul 2>&1

echo Setting ANDROID_HOME...
setx ANDROID_HOME "C:\Android\Sdk" >nul 2>&1

echo Adding Android tools to PATH...
for %%p in (
    "C:\Android\Sdk\platform-tools"
    "C:\Android\Sdk\emulator"
    "C:\Android\Sdk\cmdline-tools\latest\bin"
) do (
    setx PATH "%%PATH%%;%%~p" >nul 2>&1
    echo   Added: %%~p
)

echo.
echo ========================================
echo Environment Variables Configured!
echo ========================================
echo.
echo ANDROID_SDK_ROOT = C:\Android\Sdk
echo ANDROID_HOME = C:\Android\Sdk
echo.
echo PATH updated with:
echo   - platform-tools
echo   - emulator
echo   - cmdline-tools\latest\bin
echo.
echo Please restart your terminal for changes to take effect.
echo.
pause
