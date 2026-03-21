@echo off
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo    Android SDK and Emulator Installation (Optimized)
echo ============================================================
echo.

set "ANDROID_SDK_ROOT=C:\Android\Sdk"
set "ANDROID_CMDLINE_TOOLS=%ANDROID_SDK_ROOT%\cmdline-tools\latest"

REM Step 1: Create directories
echo [Step 1/6] Creating directories...
if not exist "C:\Android" mkdir "C:\Android"
if not exist "%ANDROID_SDK_ROOT%" mkdir "%ANDROID_SDK_ROOT%"
echo   [OK] Directories created

REM Step 2: Download command-line tools
echo.
echo [Step 2/6] Downloading Android Command-line Tools...
set "CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip"
set "CMDLINE_TOOLS_ZIP=%ANDROID_SDK_ROOT%\cmdline-tools.zip"

if exist "%CMDLINE_TOOLS_ZIP%" (
    echo   [INFO] File already exists, checking size...
    for %%F in ("%CMDLINE_TOOLS_ZIP%") do set size=%%~zF
    if !size! gtr 100000000 (
        echo   [OK] File size OK, skipping download
        goto :extract
    ) else (
        echo   [WARN] File incomplete, re-downloading...
        del "%CMDLINE_TOOLS_ZIP%"
    )
)

curl -L -o "%CMDLINE_TOOLS_ZIP%" "%CMDLINE_TOOLS_URL%"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to download command-line tools
    echo   [INFO] Please download manually from:
    echo   https://developer.android.com/studio#command-tools
    pause
    exit /b 1
)
echo   [OK] Download completed

:extract
REM Step 3: Extract command-line tools
echo.
echo [Step 3/6] Extracting command-line tools...
if not exist "%ANDROID_SDK_ROOT%\cmdline-tools" mkdir "%ANDROID_SDK_ROOT%\cmdline-tools"
powershell -Command "$ProgressPreference = 'SilentlyContinue'; Expand-Archive -LiteralPath '%CMDLINE_TOOLS_ZIP%' -DestinationPath '%ANDROID_SDK_ROOT%\cmdline-tools' -Force"
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Failed to extract
    pause
    exit /b 1
)

REM Rename to 'latest' if needed
if exist "%ANDROID_SDK_ROOT%\cmdline-tools\cmdline-tools" (
    if not exist "%ANDROID_CMDLINE_TOOLS%" (
        move "%ANDROID_SDK_ROOT%\cmdline-tools\cmdline-tools" "%ANDROID_CMDLINE_TOOLS%"
    )
)

echo   [OK] Extraction completed

REM Step 4: Set environment variables
echo.
echo [Step 4/6] Setting environment variables...
setx ANDROID_SDK_ROOT "%ANDROID_SDK_ROOT%" >nul 2>&1
setx ANDROID_HOME "%ANDROID_SDK_ROOT%" >nul 2>&1
echo   [OK] Environment variables set

REM Step 5: Install SDK packages
echo.
echo [Step 5/6] Installing Android SDK packages...
echo This may take several minutes...
set "SDKMANAGER=%ANDROID_CMDLINE_TOOLS%\bin\sdkmanager.bat"

if not exist "%SDKMANAGER%" (
    echo   [ERROR] SDK Manager not found
    pause
    exit /b 1
)

REM Accept licenses and install packages
(
echo y
echo y
echo y
echo y
echo y
echo y
echo y
echo y
) | call "%SDKMANAGER%" --sdk_root="%ANDROID_SDK_ROOT%" --licenses >nul 2>&1

call "%SDKMANAGER%" --sdk_root="%ANDROID_SDK_ROOT%" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" "system-images;android-34;google_apis;x86_64"
if %ERRORLEVEL% neq 0 (
    echo   [WARNING] Some packages may have failed to install
) else (
    echo   [OK] SDK packages installed
)

REM Step 6: Create AVD
echo.
echo [Step 6/6] Creating Android Virtual Device...
set "AVDMANAGER=%ANDROID_CMDLINE_TOOLS%\bin\avdmanager.bat"

if exist "%AVDMANAGER%" (
    echo no | call "%AVDMANAGER%" create avd -n Pixel_6_API_34 -k "system-images;android-34;google_apis;x86_64" -d pixel_6 --force
    if %ERRORLEVEL% neq 0 (
        echo   [WARNING] AVD creation may have issues
    ) else (
        echo   [OK] AVD created
    )
) else (
    echo   [WARNING] AVD Manager not found
)

echo.
echo ============================================================
echo    Installation Complete!
echo ============================================================
echo.
echo Android SDK Location: %ANDROID_SDK_ROOT%
echo.
echo Next steps:
echo 1. Restart your terminal to apply environment variables
echo 2. Run: start-emulator.bat
echo.
pause
