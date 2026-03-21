@echo off
echo Fixing Dart SDK location...

cd /d C:\Users\HZHF\Downloads\flutter_windows_3.38.9-stable\flutter\bin\cache

echo Renaming old dart-sdk to dart-sdk.old...
if exist dart-sdk (
    ren dart-sdk dart-sdk.old
)

echo Renaming dart-sdk-new to dart-sdk...
if exist dart-sdk-new (
    ren dart-sdk-new dart-sdk
)

echo Done! Dart SDK is now in the correct location.
echo.
echo You can now run: flutter doctor -v
pause
