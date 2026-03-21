@echo off
echo Downloading Android Command-line Tools...
echo This may take several minutes...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076714_latest.zip' -OutFile 'C:\Android\Sdk\cmdline-tools.zip' -UseBasicParsing"

if exist "C:\Android\Sdk\cmdline-tools.zip" (
    for %%F in ("C:\Android\Sdk\cmdline-tools.zip") do set size=%%~zF
    echo.
    echo Download completed!
    echo File size: %size% bytes
    if %size% gtr 100000000 (
        echo Status: OK
    ) else (
        echo Status: Incomplete - please download manually
    )
) else (
    echo Download failed
)

echo.
pause
