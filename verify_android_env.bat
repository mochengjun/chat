@echo off
setlocal

echo ========================================
echo Android SDK Environment Verification
echo ========================================
echo.

echo Checking Environment Variables:
echo.

REM Check ANDROID_SDK_ROOT
echo ANDROID_SDK_ROOT:
reg query "HKCU\Environment" /v ANDROID_SDK_ROOT 2>nul | findstr "C:" && echo    [OK] || echo    [NOT SET]

echo.
echo ANDROID_HOME:
reg query "HKCU\Environment" /v ANDROID_HOME 2>nul | findstr "C:" && echo    [OK] || echo    [NOT SET]

echo.
echo Checking PATH entries:
setlocal enabledelayedexpansion
set "path_found=0"

reg query "HKCU\Environment" /v Path 2>nul | findstr /I "platform-tools" >nul && (
    echo    [OK] platform-tools in PATH
    set "path_found=1"
)

reg query "HKCU\Environment" /v Path 2>nul | findstr /I "emulator" >nul && (
    echo    [OK] emulator in PATH
    set "path_found=1"
)

reg query "HKCU\Environment" /v Path 2>nul | findstr /I "cmdline-tools" >nul && (
    echo    [OK] cmdline-tools in PATH
    set "path_found=1"
)

if "!path_found!" equ "0" (
    echo    [INFO] Android paths not yet in PATH
)

echo.
echo ========================================
endlocal
pause
