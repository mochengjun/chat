@echo off
echo ========================================
echo Flutter Installation Verification
echo ========================================
echo.

echo [1/5] Checking Flutter directory...
if exist "C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\flutter.bat" (
    echo [OK] Flutter found
) else (
    echo [ERROR] Flutter not found
    pause
    exit /b 1
)

echo.
echo [2/5] Checking Dart SDK...
if exist "C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\cache\dart-sdk\bin\dart.exe" (
    echo [OK] Dart SDK found
    C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\cache\dart-sdk\bin\dart.exe --version
) else (
    echo [ERROR] Dart SDK not found
    pause
    exit /b 1
)

echo.
echo [3/5] Checking Git repository...
cd C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter
git log -1 --oneline >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Git repository initialized
) else (
    echo [ERROR] Git repository not initialized
    pause
    exit /b 1
)

echo.
echo [4/5] Running Flutter doctor...
echo This may take a few minutes...
C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\flutter.bat doctor

echo.
echo [5/5] Checking Flutter version...
C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\flutter.bat --version

echo.
echo ========================================
echo Verification Complete!
echo ========================================
echo.
echo Flutter is installed at:
echo C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter
echo.
echo To use Flutter, add to PATH:
echo setx PATH "%%PATH%%;C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin"
echo.
pause
