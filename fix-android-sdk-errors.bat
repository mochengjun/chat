@echo off
echo ============================================================
echo    Android SDK Installation - Fix All Errors
echo ============================================================
echo.
echo This script will help you fix:
echo 1. Missing Java JDK
echo 2. Failed SDK download
echo 3. Environment setup
echo.
pause

echo.
echo ============================================================
echo Step 1: Java JDK Installation
echo ============================================================
echo.
echo Android SDK requires Java JDK 11 or later.
echo.
echo Please download and install Java JDK:
echo.
echo Option A: Oracle JDK (Recommended)
echo   https://www.oracle.com/java/technologies/downloads/
echo.
echo Option B: OpenJDK (Free, Open Source)
echo   https://adoptium.net/
echo   or https://jdk.java.net/
echo.
echo After installation:
echo 1. Set JAVA_HOME environment variable
echo 2. Add Java bin to PATH
echo 3. Restart terminal
echo.
pause

echo.
echo ============================================================
echo Step 2: Manual SDK Download
echo ============================================================
echo.
echo Since automatic download failed, please download manually:
echo.
echo URL: https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip
echo.
echo Steps:
echo 1. Open the URL in your browser
echo 2. Download the file (Size: ~150 MB)
echo 3. Save to: C:\Android\Sdk\cmdline-tools.zip
echo 4. Verify file size is ~150 MB (not 1.4 KB!)
echo 5. Run this script again
echo.
pause

echo.
echo ============================================================
echo Step 3: Verify Prerequisites
echo ============================================================
echo.

echo Checking Java...
java -version >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Java is installed
    java -version
) else (
    echo [MISSING] Java is not installed or not in PATH
    echo Please install Java JDK first!
)

echo.
echo Checking ZIP file...
if exist "C:\Android\Sdk\cmdline-tools.zip" (
    for %%F in ("C:\Android\Sdk\cmdline-tools.zip") do set size=%%~zF
    echo File exists: !size! bytes
    if !size! gtr 100000000 (
        echo [OK] File size looks correct
    ) else (
        echo [ERROR] File too small - incomplete download
    )
) else (
    echo [MISSING] cmdline-tools.zip not found
)

echo.
pause
