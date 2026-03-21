@echo off
REM ============================================================
REM One-Click Android SDK & Emulator Setup
REM ============================================================

echo.
echo ============================================================
echo    Android SDK and Emulator Quick Setup
echo ============================================================
echo.

REM Set variables
set "SDK_ROOT=C:\Android\Sdk"
set "CMDLINE_TOOLS_ZIP=%SDK_ROOT%\cmdline-tools.zip"
set "CMDLINE_TOOLS_DIR=%SDK_ROOT%\cmdline-tools\latest"

REM Step 1: Download Command-line Tools
echo [1/7] Checking Command-line Tools...
if exist "%CMDLINE_TOOLS_ZIP%" (
    for %%F in ("%CMDLINE_TOOLS_ZIP%") do set size=%%~zF
    if !size! gtr 100000000 (
        echo    [SKIP] Already downloaded
        goto step2
    ) else (
        echo    [WARN] Incomplete download, removing...
        del "%CMDLINE_TOOLS_ZIP%"
    )
)

echo    [INFO] Starting download...
echo    [INFO] URL: https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip
echo    [INFO] Size: ~150 MB
echo    [INFO] Please wait...

start /wait powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip' " ^
    "-OutFile 'C:\Android\Sdk\cmdline-tools.zip' -UseBasicParsing"

if not exist "%CMDLINE_TOOLS_ZIP%" (
    echo    [ERROR] Download failed
    echo    [INFO] Please download manually from:
    echo    https://developer.android.com/studio#command-tools
    pause
    exit /b 1
)

for %%F in ("%CMDLINE_TOOLS_ZIP%") do set size=%%~zF
echo    [OK] Downloaded %%~zF bytes

:step2
REM Step 2: Extract
echo.
echo [2/7] Extracting Command-line Tools...
if exist "%CMDLINE_TOOLS_DIR%\bin\sdkmanager.bat" (
    echo    [SKIP] Already extracted
    goto step3
)

if not exist "%SDK_ROOT%\cmdline-tools" mkdir "%SDK_ROOT%\cmdline-tools"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "Expand-Archive -LiteralPath 'C:\Android\Sdk\cmdline-tools.zip' " ^
    "-DestinationPath 'C:\Android\Sdk\cmdline-tools' -Force"

REM Rename to latest
if exist "%SDK_ROOT%\cmdline-tools\cmdline-tools" (
    if not exist "%CMDLINE_TOOLS_DIR%" (
        move "%SDK_ROOT%\cmdline-tools\cmdline-tools" "%CMDLINE_TOOLS_DIR%"
    )
)

if exist "%CMDLINE_TOOLS_DIR%\bin\sdkmanager.bat" (
    echo    [OK] Extraction complete
) else (
    echo    [ERROR] Extraction failed
    pause
    exit /b 1
)

:step3
REM Step 3: Environment Variables
echo.
echo [3/7] Setting environment variables...
setx ANDROID_SDK_ROOT "%SDK_ROOT%" >nul 2>&1
setx ANDROID_HOME "%SDK_ROOT%" >nul 2>&1
echo    [OK] Environment variables set

:step4
REM Step 4: Accept Licenses
echo.
echo [4/7] Accepting Android licenses...
echo    [INFO] This will accept all licenses automatically
(
echo y
echo y
echo y
echo y
echo y
echo y
echo y
echo y
) | "%CMDLINE_TOOLS_DIR%\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" --licenses >nul 2>&1
echo    [OK] Licenses accepted

:step5
REM Step 5: Install SDK Packages
echo.
echo [5/7] Installing Android SDK packages...
echo    [INFO] This may take 10-20 minutes...
echo    [INFO] Installing: platform-tools, android-34, build-tools, emulator, system-image

"%CMDLINE_TOOLS_DIR%\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" ^
    "platform-tools" ^
    "platforms;android-34" ^
    "build-tools;34.0.0" ^
    "emulator" ^
    "system-images;android-34;google_apis;x86_64"

if %ERRORLEVEL% equ 0 (
    echo    [OK] SDK packages installed
) else (
    echo    [WARN] Some packages may have failed
)

:step6
REM Step 6: Create AVD
echo.
echo [6/7] Creating Android Virtual Device...
if exist "%USERPROFILE%\.android\avd\Pixel_6_API_34.avd" (
    echo    [SKIP] AVD already exists
    goto step7
)

echo no | "%CMDLINE_TOOLS_DIR%\bin\avdmanager.bat" create avd ^
    -n Pixel_6_API_34 ^
    -k "system-images;android-34;google_apis;x86_64" ^
    -d pixel_6 ^
    --force >nul 2>&1

if exist "%USERPROFILE%\.android\avd\Pixel_6_API_34.avd" (
    echo    [OK] AVD created
) else (
    echo    [WARN] AVD creation may have issues
)

:step7
REM Step 7: Verify
echo.
echo [7/7] Verifying installation...
echo.

echo Checking SDK Manager...
if exist "%CMDLINE_TOOLS_DIR%\bin\sdkmanager.bat" (
    echo    [OK] SDK Manager
) else (
    echo    [ERROR] SDK Manager not found
)

echo Checking ADB...
if exist "%SDK_ROOT%\platform-tools\adb.exe" (
    echo    [OK] ADB
) else (
    echo    [ERROR] ADB not found
)

echo Checking Emulator...
if exist "%SDK_ROOT%\emulator\emulator.exe" (
    echo    [OK] Emulator
) else (
    echo    [ERROR] Emulator not found
)

echo Checking AVD...
if exist "%USERPROFILE%\.android\avd\Pixel_6_API_34.avd" (
    echo    [OK] AVD
) else (
    echo    [WARN] AVD not found
)

echo.
echo ============================================================
echo    Installation Complete!
echo ============================================================
echo.
echo SDK Location: %SDK_ROOT%
echo AVD Name: Pixel_6_API_34
echo.
echo Next steps:
echo 1. Restart your terminal to apply environment variables
echo 2. Run emulator: start-emulator.bat
echo 3. Or run: emulator -avd Pixel_6_API_34
echo.
pause
