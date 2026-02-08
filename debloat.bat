@echo off
REM Boring Phone — Debloat Script (Windows)
REM https://github.com/YOUR_USERNAME/boring-phone
REM
REM Usage: double-click or run from cmd: debloat.bat
REM Tested on: Redmi Note 15 (HyperOS 2 / Android 15)

setlocal enabledelayedexpansion

REM --- Find ADB ---
set ADB=
where adb >nul 2>nul && set ADB=adb
if "%ADB%"=="" if exist "%USERPROFILE%\platform-tools\adb.exe" set ADB=%USERPROFILE%\platform-tools\adb.exe
if "%ADB%"=="" if exist "C:\adb\platform-tools\adb.exe" set ADB=C:\adb\platform-tools\adb.exe
if "%ADB%"=="" (
    echo ❌ ADB not found. Place platform-tools in your home directory or C:\adb\
    echo    Download: https://developer.android.com/tools/releases/platform-tools
    pause
    exit /b 1
)

REM --- Setup logging ---
set TIMESTAMP=%date:~-4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOG_DIR=%USERPROFILE%\boring-phone-logs
set LOG_FILE=%LOG_DIR%\debloat_%TIMESTAMP%.log
set RESTORE_FILE=%LOG_DIR%\restore_%TIMESTAMP%.bat
set SNAPSHOT_FILE=%LOG_DIR%\packages_before_%TIMESTAMP%.txt

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo.
echo   ┌──────────────────────────────────┐
echo   │         📱 Boring Phone          │
echo   │   Make your phone boring again   │
echo   └──────────────────────────────────┘
echo.

REM --- Connection check ---
echo 🔍 Checking phone connection...
%ADB% devices | findstr /C:"device" >nul 2>nul
if errorlevel 1 (
    echo ❌ Phone not detected.
    echo.
    echo    Checklist:
    echo    1. USB cable plugged in?
    echo    2. 'File transfer' mode selected on phone?
    echo    3. USB debugging enabled?
    echo    4. Authorized this computer?
    pause
    exit /b 1
)
echo ✅ Phone connected.
echo.

REM --- Snapshot ---
echo 📸 Saving package snapshot...
%ADB% shell pm list packages > "%SNAPSHOT_FILE%"
echo    Saved to: %SNAPSHOT_FILE%
echo.

REM --- Initialize restore script ---
echo @echo off > "%RESTORE_FILE%"
echo REM Auto-generated restore script >> "%RESTORE_FILE%"
echo set ADB=%ADB% >> "%RESTORE_FILE%"
echo. >> "%RESTORE_FILE%"

REM --- Initialize log ---
echo Boring Phone — Debloat log > "%LOG_FILE%"
echo Timestamp: %TIMESTAMP% >> "%LOG_FILE%"
echo --- >> "%LOG_FILE%"

set REMOVED=0
set SKIPPED=0

REM ============================================================
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🔴 STAGE 1: Removing distraction sources
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

call :remove com.mi.globalbrowser "Mi Browser"
call :remove com.android.chrome "Chrome"
call :remove com.google.android.youtube "YouTube"
call :remove com.google.android.googlequicksearchbox "Google Search / Discover"
call :remove com.google.android.apps.magazines "Google News"
call :remove com.facebook.katana "Facebook"
call :remove com.facebook.system "Facebook System"
call :remove com.facebook.appmanager "Facebook App Manager"
call :remove com.facebook.services "Facebook Services"
call :remove com.zhiliaoapp.musically "TikTok"
call :remove com.netflix.mediaclient "Netflix"
call :remove com.spotify.music "Spotify"
call :remove com.google.android.apps.tachyon "Google Duo / Meet"
call :remove com.google.android.videos "Google TV"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ⏸️  STAGE 1 COMPLETE
echo.
echo    Pick up your phone and test:
echo    - Open WhatsApp
echo    - Open Gmail
echo    - Try to find a browser
echo.
echo    All good? Press any key for Stage 2.
echo    Something wrong? Close this window.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
pause >nul

REM ============================================================
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🟡 STAGE 2: Removing Xiaomi bloatware
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

call :remove com.miui.msa.global "Xiaomi Ad Engine"
call :remove com.miui.analytics "Xiaomi Analytics"
call :remove com.miui.systemAdSolution "System Ad Solution"
call :remove com.xiaomi.joyose "Joyose (Telemetry)"
call :remove com.xiaomi.mipicks "GetApps"
call :remove com.miui.contentcatcher "Content Recommendations"
call :remove com.miui.personalassistant "Personal Assistant"
call :remove com.mi.globalminusscreen "App Vault"
call :remove com.miui.videoplayer "Mi Video"
call :remove com.miui.player "Mi Music"
call :remove com.miui.android.fashiongallery "Wallpaper Carousel"
call :remove com.xiaomi.aicr "Xiaomi AI Engine"
call :remove com.miui.voiceassist "Mi Voice Assistant"
call :remove com.xiaomi.gamecenter.sdk.service "Game Center SDK"
call :remove com.xiaomi.gamecenter "Game Center"
call :remove com.miui.yellowpage "Yellow Pages"
call :remove com.xiaomi.midrop "ShareMe"
call :remove com.miui.nextpay "Mi Pay"
call :remove com.miui.bugreport "Bug Report Tool"
call :remove com.miui.hybrid "Hybrid Apps Engine"
call :remove cn.wps.xiaomi.abroad.lite "WPS Office Lite"

echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.
echo    ✨ Your phone is now boring. That's the point.
echo.
echo    Removed: %REMOVED% apps
echo    Skipped: %SKIPPED% (not on this phone)
echo.
echo    Files saved in: %LOG_DIR%
echo    To undo: run restore_%TIMESTAMP%.bat
echo.
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
pause
exit /b 0

REM --- Remove function ---
:remove
set PKG=%~1
set LABEL=%~2
for /f "tokens=*" %%a in ('%ADB% shell pm uninstall -k --user 0 %PKG% 2^>^&1') do set RESULT=%%a
echo %RESULT% | findstr /C:"Success" >nul 2>nul
if not errorlevel 1 (
    echo    ✅ %LABEL%
    echo REMOVED: %PKG% — %LABEL% >> "%LOG_FILE%"
    echo %ADB% shell cmd package install-existing %PKG% >> "%RESTORE_FILE%"
    set /a REMOVED+=1
) else (
    echo    ⏭️  %LABEL% (not on this phone)
    echo SKIPPED: %PKG% — %LABEL% >> "%LOG_FILE%"
    set /a SKIPPED+=1
)
exit /b
