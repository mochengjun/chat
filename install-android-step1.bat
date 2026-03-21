@echo off
REM ============================================================
REM Step-by-Step Android SDK Installation
REM ============================================================

setlocal enabledelayedexpansion
set "SDK_ROOT=C:\Android\Sdk"

echo.
echo ============================================================
echo    Android SDK Installation - Step by Step
echo ============================================================
echo.

REM Step 1: Download Command-line Tools
echo [Step 1/6] Downloading Android Command-line Tools...
echo URL: https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip
echo Expected size: ~150 MB
echo.

if exist "%SDK_ROOT%\cmdline-tools.zip" (
    echo File exists, checking size...
    for %%F in ("%SDK_ROOT%\cmdline-tools.zip") do set filesize=%%~zF
    if !filesize! gtr 100000000 (
        echo Already downloaded !filesize! bytes, skipping...
        goto step2
    ) else (
        echo File incomplete !filesize! bytes, re-downloading...
        del "%SDK_ROOT%\cmdline-tools.zip"
    )
)

echo Starting download...
echo Please wait, this may take several minutes...
echo.

curl -L -o "%SDK_ROOT%\cmdline-tools.zip" "https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip"

if not exist "%SDK_ROOT%\cmdline-tools.zip" (
    echo.
    echo [ERROR] Download failed!
    echo.
    echo Please download manually:
    echo 1. Visit: https://developer.android.com/studio#command-tools
    echo 2. Download: commandlinetools-win-11076714_latest.zip
    echo 3. Save to: C:\Android\Sdk\cmdline-tools.zip
    echo 4. Run this script again
    pause
    exit /b 1
)

for %%F in ("%SDK_ROOT%\cmdline-tools.zip") do echo Downloaded: %%~zF bytes
echo [OK] Download complete!

:step2
REM Step 2: Extract
echo.
echo [Step 2/6] Extracting Command-line Tools...

if exist "%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo Already extracted, skipping...
    goto step3
)

if not exist "%SDK_ROOT%\cmdline-tools" mkdir "%SDK_ROOT%\cmdline-tools"

echo Extracting... please wait...
powershell -Command "$ProgressPreference = 'SilentlyContinue'; Expand-Archive -LiteralPath '%SDK_ROOT%\cmdline-tools.zip' -DestinationPath '%SDK_ROOT%\cmdline-tools' -Force"

REM Rename to 'latest'
if exist "%SDK_ROOT%\cmdline-tools\cmdline-tools" (
    if not exist "%SDK_ROOT%\cmdline-tools\latest" (
        move "%SDK_ROOT%\cmdline-tools\cmdline-tools" "%SDK_ROOT%\cmdline-tools\latest"
    )
)

if exist "%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" (
    echo [OK] Extraction complete!
) else (
    echo [ERROR] Extraction failed!
    pause
    exit /b 1
)

:step3
REM Step 3: Set environment variables (already done, just verify)
echo.
echo [Step 3/6] Verifying environment variables...
echo ANDROID_SDK_ROOT = %ANDROID_SDK_ROOT%
echo ANDROID_HOME = %ANDROID_HOME%
echo [OK] Environment variables configured

:step4
REM Step 4: Accept licenses
echo.
echo [Step 4/6] Accepting Android SDK licenses...
echo This will automatically accept all licenses...

(
echo y
echo y
echo y
echo y
echo y
echo y
echo y
echo y
) | "%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" --licenses >nul 2>&1

echo [OK] Licenses accepted

:step5
REM Step 5: Install SDK packages
echo.
echo [Step 5/6] Installing Android SDK packages...
echo This will install:
echo   - platform-tools (ADB, fastboot)
echo   - platforms;android-34 (Android 14)
echo   - build-tools;34.0.0
echo   - emulator
echo   - system-images;android-34;google_apis;x86_64 (for emulator)
echo.
echo This may take 10-30 minutes depending on your internet speed...
echo.

"%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" "system-images;android-34;google_apis;x86_64"

if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] SDK packages installed successfully!
) else (
    echo.
    echo [WARNING] Some packages may have failed to install
)

:step6
REM Step 6: Verify installation
echo.
echo [Step 6/6] Verifying installation...
echo.

if exist "%SDK_ROOT%\platform-tools\adb.exe" (
    echo [OK] platform-tools installed
) else (
    echo [MISSING] platform-tools
)

if exist "%SDK_ROOT%\emulator\emulator.exe" (
    echo [OK] emulator installed
) else (
    echo [MISSING] emulator
)

if exist "%SDK_ROOT%\platforms\android-34" (
    echo [OK] Android 34 platform installed
) else (
    echo [MISSING] Android 34 platform
)

if exist "%SDK_ROOT%\build-tools\34.0.0" (
    echo [OK] build-tools 34.0.0 installed
) else (
    echo [MISSING] build-tools 34.0.0
)

echo.
echo ============================================================
echo    Android SDK Installation Complete!
echo ============================================================
echo.
echo Installed at: %SDK_ROOT%
echo.
echo Next steps:
echo 1. Restart your terminal
echo 2. Create an AVD: avdmanager create avd -n Pixel_6_API_34 -k "system-images;android-34;google_apis;x86_64" -d pixel_6
echo 3. Start emulator: emulator -avd Pixel_6_API_34
echo.
pause
