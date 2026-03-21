@echo off
REM ============================================================
REM Android SDK and Emulator Installation Script
REM ============================================================

echo.
echo ============================================================
echo    Android SDK and Emulator Installation
echo ============================================================
echo.

set "ANDROID_SDK_ROOT=C:\Android\Sdk"
set "ANDROID_CMDLINE_TOOLS=%ANDROID_SDK_ROOT%\cmdline-tools"

REM Create directories
echo [Step 1/5] Creating directories...
if not exist "C:\Android" mkdir "C:\Android"
if not exist "%ANDROID_SDK_ROOT%" mkdir "%ANDROID_SDK_ROOT%"
if not exist "%ANDROID_CMDLINE_TOOLS%" mkdir "%ANDROID_CMDLINE_TOOLS%"
echo   [OK] Directories created

REM Download command-line tools
echo.
echo [Step 2/5] Downloading Android Command-line Tools...
set "CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip"
set "CMDLINE_TOOLS_ZIP=%ANDROID_SDK_ROOT%\cmdline-tools.zip"

curl -L -o "%CMDLINE_TOOLS_ZIP%" "%CMDLINE_TOOLS_URL%"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to download command-line tools
    goto :error_exit
)
echo   [OK] Download completed

REM Extract command-line tools
echo.
echo [Step 3/5] Extracting command-line tools...
powershell -Command "Expand-Archive -Path '%CMDLINE_TOOLS_ZIP%' -DestinationPath '%ANDROID_CMDLINE_TOOLS%' -Force"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to extract command-line tools
    goto :error_exit
)
del "%CMDLINE_TOOLS_ZIP%"
echo   [OK] Extraction completed

REM Set environment variables
echo.
echo [Step 4/5] Setting environment variables...
setx ANDROID_SDK_ROOT "%ANDROID_SDK_ROOT%" >nul
setx PATH "%%PATH%%;%ANDROID_SDK_ROOT%\platform-tools;%ANDROID_SDK_ROOT%\emulator;%ANDROID_CMDLINE_TOOLS%\cmdline-tools\bin" >nul
echo   [OK] Environment variables set

REM Install SDK packages
echo.
echo [Step 5/5] Installing Android SDK packages...
set "SDKMANAGER=%ANDROID_CMDLINE_TOOLS%\cmdline-tools\bin\sdkmanager.bat"

REM Accept licenses and install packages
echo y | call "%SDKMANAGER%" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" "system-images;android-34;google_apis;x86_64"
if %ERRORLEVEL% neq 0 (
    echo   [WARNING] SDK package installation may have issues
)

echo.
echo ============================================================
echo    Installation Complete!
echo ============================================================
echo.
echo Next steps:
echo 1. Restart your terminal to apply environment variables
echo 2. Run: avdmanager create avd -n Pixel_6_API_34 -k "system-images;android-34;google_apis;x86_64" -d pixel_6
echo 3. Run: emulator -avd Pixel_6_API_34
echo.
goto :end

:error_exit
echo.
echo [ERROR] Installation failed
pause
exit /b 1

:end
pause
