@echo off
title Flutter - Medium_Phone_API_37.0
set "ANDROID_HOME=C:\Users\Synergy\AppData\Local\Android\sdk"
set "PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\emulator"
cd /d "%~dp0"

adb devices | findstr /r "emulator-[0-9]*.*device$" >nul
if errorlevel 1 (
  echo Starting emulator Medium_Phone_API_37.0 ...
  start "Android Emulator" emulator -avd Medium_Phone_API_37.0
)

echo Waiting for emulator to boot...
adb wait-for-device
:waitboot
for /f "delims=" %%b in ('adb shell getprop sys.boot_completed 2^>nul') do set "BOOT=%%b"
if not "%BOOT%"=="1" (
  timeout /t 3 /nobreak >nul
  goto waitboot
)
echo Emulator ready.

rem .env picks the backend (BACKEND_MODE=http = the FastAPI/PostgreSQL server
rem shared with the admin dashboard). Without it the app uses its mock backend.
if exist ".env" (
  findstr /b /c:"BACKEND_MODE=http" ".env" >nul && (
    curl -s -o nul http://localhost:8000/health || (
      echo WARNING: the FastAPI backend is not running on port 8000.
      echo Start it first: cd backend ^&^& .venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
    )
  )
  flutter run -d emulator-5554 --dart-define-from-file=.env
) else (
  flutter run -d emulator-5554
)

echo.
echo flutter run exited. Press any key to close.
pause >nul
