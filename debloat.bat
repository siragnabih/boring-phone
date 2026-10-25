@echo off
REM Boring Phone - Debloat Script (Windows)
REM https://github.com/siragnabih/boring-phone
REM
REM Usage: double-click, or run from cmd:  debloat.bat [--dry-run] [--yes] [--distractions-only]
REM Tested on: Redmi Note 15 (HyperOS 2 / Android 15)
REM
REM What gets removed lives in lists\distractions.txt (Stage 1) and lists\xiaomi.txt (Stage 2).
REM Put a # in front of a line there to keep that app.
REM
REM Keep this file ASCII with Windows (CRLF) line endings - .gitattributes takes care of the endings.
REM Batch gotcha: never put a bare ) or ! inside echo text in this file.

setlocal enabledelayedexpansion

set "STAGE1_LIST=%~dp0lists\distractions.txt"
set "STAGE2_LIST=%~dp0lists\xiaomi.txt"

REM --- Options ---
set "DRY_RUN=0"
set "ASSUME_YES=0"
set "DISTRACTIONS_ONLY=0"
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--dry-run" (set "DRY_RUN=1" & shift & goto parse_args)
if /i "%~1"=="-n" (set "DRY_RUN=1" & shift & goto parse_args)
if /i "%~1"=="--yes" (set "ASSUME_YES=1" & shift & goto parse_args)
if /i "%~1"=="-y" (set "ASSUME_YES=1" & shift & goto parse_args)
if /i "%~1"=="--distractions-only" (set "DISTRACTIONS_ONLY=1" & shift & goto parse_args)
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
echo Unknown option: %~1
echo.
call :print_usage
exit /b 1
:usage
call :print_usage
exit /b 0
:args_done

for %%F in ("%STAGE1_LIST%" "%STAGE2_LIST%") do (
    if not exist "%%~F" (
        echo [fail] Missing %%~F
        echo        Keep the lists folder next to debloat.bat.
        pause
        exit /b 1
    )
)

REM --- Find ADB ---
REM Its folder goes on PATH so "adb" works everywhere below, even if the path has spaces.
set "ADB_DIR="
where adb >nul 2>nul && goto adb_found
for %%D in ("%USERPROFILE%\platform-tools" "C:\adb\platform-tools" "C:\adb" "%LOCALAPPDATA%\Android\Sdk\platform-tools") do (
    if not defined ADB_DIR if exist "%%~D\adb.exe" set "ADB_DIR=%%~D"
)
if not defined ADB_DIR (
    echo [fail] ADB not found. Put the platform-tools folder in your home folder or in C:\adb\
    echo        Download: https://developer.android.com/tools/releases/platform-tools
    pause
    exit /b 1
)
set "PATH=%ADB_DIR%;%PATH%"
:adb_found

REM Removing these can break the phone. The script refuses even if you add them to a list.
REM The second line is the essentials checked below.
set "PROTECTED=com.android.systemui com.android.settings com.android.phone com.google.android.gms com.google.android.webview com.miui.home com.mi.android.globallauncher com.miui.securitycenter"
set "PROTECTED=%PROTECTED% com.whatsapp com.whatsapp.w4b com.google.android.gm com.google.android.apps.maps com.google.android.dialer com.android.contacts com.android.dialer com.google.android.apps.messaging com.android.mms com.android.camera com.google.android.GoogleCamera com.android.vending"

REM --- Setup logging ---
REM %date% depends on the region settings, so ask PowerShell for a sortable timestamp.
set "TIMESTAMP="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" 2^>nul`) do set "TIMESTAMP=%%T"
if not defined TIMESTAMP set "TIMESTAMP=run%RANDOM%%RANDOM%"
set "LOG_DIR=%USERPROFILE%\boring-phone-logs"
set "LOG_FILE=%LOG_DIR%\debloat_%TIMESTAMP%.log"
set "RESTORE_FILE=%LOG_DIR%\restore_%TIMESTAMP%.bat"
set "SNAPSHOT_FILE=%LOG_DIR%\packages_before_%TIMESTAMP%.txt"
set "DISABLED_FILE=%TEMP%\boring-phone-disabled.txt"
set "NOW_FILE=%TEMP%\boring-phone-now.txt"
set "BROWSERS_FILE=%TEMP%\boring-phone-browsers.txt"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo.
echo   +----------------------------------+
echo   :          Boring Phone            :
echo   :   Make your phone boring again   :
echo   +----------------------------------+
echo.
if "%DRY_RUN%"=="1" (
    echo DRY RUN - nothing on the phone will be changed.
    echo.
)

REM --- Connection check ---
echo Checking phone connection...
adb start-server >nul 2>nul
set "DEVICE_COUNT=0"
set "DEVICE_LIST="
set "SERIAL="
set "STATE="
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do call :count_device "%%A" "%%B"

if "%DEVICE_COUNT%"=="0" (
    echo [fail] Phone not detected.
    echo.
    echo    Checklist:
    echo    1. USB cable plugged in? Some cables only charge - try another.
    echo    2. 'File transfer' mode selected on phone?
    echo    3. USB debugging enabled? Settings - Additional settings - Developer options
    echo    4. Authorized this computer? Check for a popup on the phone.
    pause
    exit /b 1
)
if not "%DEVICE_COUNT%"=="1" (
    echo [fail] More than one phone or emulator is connected:!DEVICE_LIST!
    echo.
    echo    Pick one, then run this again:  set ANDROID_SERIAL=serial-from-the-list
    pause
    exit /b 1
)
if "%STATE%"=="unauthorized" (
    echo [fail] Phone found, but this computer isn't authorized yet.
    echo        Unlock the phone and tap 'Allow' on the USB debugging popup,
    echo        tick 'Always allow from this computer', then run this again.
    pause
    exit /b 1
)
if not "%STATE%"=="device" (
    echo [fail] Phone found, but its state is '%STATE%'. Unplug it, plug it back in, and run this again.
    pause
    exit /b 1
)
set "ANDROID_SERIAL=%SERIAL%"

call :prop ro.product.manufacturer MANUFACTURER
call :prop ro.product.model MODEL
call :prop ro.build.version.release ANDROID_VERSION
call :prop ro.build.version.incremental OS_VERSION
echo [ok] Connected: !MANUFACTURER! !MODEL! - Android !ANDROID_VERSION!, !OS_VERSION!
set "IS_XIAOMI=0"
for %%M in (Xiaomi Redmi POCO) do if /i "!MANUFACTURER!"=="%%M" set "IS_XIAOMI=1"
if "%IS_XIAOMI%"=="0" (
    echo [info] Not a Xiaomi phone. Stage 1 still works, Stage 2 will mostly skip.
    echo        See 'Adapting for Other Phones' in the README.
)
echo.

REM --- Snapshot ---
echo Saving snapshot of all installed packages...
adb shell pm list packages 2>&1 | sort > "%SNAPSHOT_FILE%"
adb shell pm list packages -d 2>&1 | sort > "%DISABLED_FILE%"
set "PACKAGE_COUNT=0"
for /f %%C in ('findstr /B /C:"package:" "%SNAPSHOT_FILE%" ^| find /c /v ""') do set "PACKAGE_COUNT=%%C"
if "%PACKAGE_COUNT%"=="0" (
    echo [fail] Couldn't read the package list from the phone:
    type "%SNAPSHOT_FILE%"
    pause
    exit /b 1
)
echo    Saved %PACKAGE_COUNT% packages to:
echo    %SNAPSHOT_FILE%
echo.

REM --- Initialize log ---
> "%LOG_FILE%" (
    echo Boring Phone - Debloat log
    echo Timestamp: %TIMESTAMP%
    echo Device: !MANUFACTURER! !MODEL!, serial !SERIAL!, Android !ANDROID_VERSION!, !OS_VERSION!
    echo Packages before: %PACKAGE_COUNT%
    if "%DRY_RUN%"=="1" echo Mode: DRY RUN, nothing changed
    echo ---
)

REM --- Initialize restore script ---
REM Its footer comes first and the restore lines are appended after ":run",
REM so the file works even if you close this window after Stage 1.
if "%DRY_RUN%"=="1" goto restore_ready
> "%RESTORE_FILE%" (
    echo @echo off
    echo REM Auto-generated by Boring Phone on %TIMESTAMP% for !MANUFACTURER! !MODEL!, serial !SERIAL!.
    echo REM Reverses only what that run actually removed. Double-click it, or run it from cmd.
    echo setlocal
    echo set "PATH=!ADB_DIR!;%%PATH%%"
    echo echo Restoring removed apps...
    echo call :run
    echo echo.
    echo echo Done. Each line above should say "installed for user" or "new state: enabled".
    echo echo Apps you installed yourself, not preinstalled, can't come back this way - reinstall those from the Play Store.
    echo pause
    echo exit /b
    echo :run
)
:restore_ready

set "REMOVED=0"
set "DISABLED=0"
set "FAILED=0"
set "SKIPPED=0"

echo Checking your essentials are installed...
call :check_essentials
set "MISSING_BEFORE=!CHECK_MISSING!"
if not "!MISSING_BEFORE!"=="_" (
    echo.
    echo    [info] Install anything missing from the Play Store - now or later, the Play Store stays.
)
echo.

REM ============================================================
echo ================================================
echo  STAGE 1: Removing distraction sources
echo ================================================
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo === STAGE 1: Distraction sources ===

call :run_list "%STAGE1_LIST%"
call :browser_check
if "%DRY_RUN%"=="0" call :sanity_check

if "%DISTRACTIONS_ONLY%"=="1" goto finish
if "%DRY_RUN%"=="1" goto stage2
if "%ASSUME_YES%"=="1" goto stage2

echo.
echo ================================================
echo  STAGE 1 COMPLETE
echo.
echo    Pick up your phone and test:
echo    - Open WhatsApp - send a message
echo    - Open Gmail - check inbox loads
echo    - Make a call, take a photo
echo.
echo    All good? Press any key for Stage 2.
echo    Something wrong? Close this window. The undo file is already saved.
echo ================================================
pause >nul

:stage2
REM ============================================================
echo.
echo ================================================
echo  STAGE 2: Removing Xiaomi bloatware
echo ================================================
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo === STAGE 2: Xiaomi bloatware ===

call :run_list "%STAGE2_LIST%"
if "%DRY_RUN%"=="0" call :sanity_check

:finish
REM ============================================================
>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo Removed: %REMOVED%  Disabled: %DISABLED%  Failed: %FAILED%  Not on phone: %SKIPPED%
set /a TOTAL_REMOVED=REMOVED+DISABLED

echo.
echo ================================================
echo.
if "%DRY_RUN%"=="1" (
    echo    Dry run finished. Nothing was changed.
    echo.
    echo    Would remove: %REMOVED% apps
    echo    Not on this phone: %SKIPPED%
    echo.
    echo    Keep something? Put a # in front of its line in the lists folder.
    echo    Ready? Run: debloat.bat
    echo.
    echo    Package snapshot: %SNAPSHOT_FILE%
    goto end
)
echo    Your phone is now boring. That's the point.
echo.
echo    Removed:  %TOTAL_REMOVED% apps
if not "%DISABLED%"=="0" echo              %DISABLED% of them disabled, because Xiaomi blocks uninstalling them
if not "%FAILED%"=="0" echo    Failed:   %FAILED% - the phone refused, see FAILED lines in the log
echo    Skipped:  %SKIPPED% - not on this phone, or already gone
echo.
echo    Files saved in %LOG_DIR%
echo    Log:       debloat_%TIMESTAMP%.log
echo    Snapshot:  packages_before_%TIMESTAMP%.txt
echo    Undo:      restore_%TIMESTAMP%.bat
echo.
echo    To undo everything, run:
echo    "%RESTORE_FILE%"
:end
echo.
echo ================================================
pause
exit /b 0


REM ============================================================
REM Subroutines
REM ============================================================

:print_usage
echo Usage: debloat.bat [options]
echo.
echo   -n, --dry-run            Show what would be removed. Changes nothing on the phone.
echo   -y, --yes                Don't pause between Stage 1 and Stage 2.
echo       --distractions-only  Run Stage 1 only, skipping the Xiaomi bloatware.
echo   -h, --help               Show this help.
echo.
echo More than one phone plugged in? Pick one first:  set ANDROID_SERIAL=your-serial
exit /b

:count_device
REM %1 = serial, %2 = state, from one line of "adb devices"
if "%~2"=="" exit /b
if "%~1"=="*" exit /b
if defined ANDROID_SERIAL if not "%~1"=="%ANDROID_SERIAL%" exit /b
set /a DEVICE_COUNT+=1
set "SERIAL=%~1"
set "STATE=%~2"
set "DEVICE_LIST=!DEVICE_LIST! %~1"
exit /b

:prop
REM %1 = property name, %2 = variable to store it in
set "%~2="
for /f "delims=" %%L in ('adb shell getprop %~1 2^>nul') do set "%~2=%%L"
exit /b

:run_list
REM %1 = list file. Lines starting with # are skipped; first word is the package, the rest is the label.
set "SKIPPED_BEFORE=%SKIPPED%"
for /f "usebackq eol=# tokens=1,*" %%A in ("%~1") do call :remove "%%A" "%%B"
set /a STAGE_SKIPPED=SKIPPED-SKIPPED_BEFORE
echo    [skip] !STAGE_SKIPPED! other listed apps aren't on this phone, or are already gone.
exit /b

:remove
REM %1 = package, %2 = label
set "PKG=%~1"
set "LABEL=%~2"
if "!LABEL!"=="" set "LABEL=!PKG!"
findstr /L /X /C:"package:%PKG%" "%SNAPSHOT_FILE%" >nul 2>nul || (
    >>"%LOG_FILE%" echo SKIPPED: !PKG! - !LABEL! - not on this phone
    set /a SKIPPED+=1
    exit /b
)
findstr /L /X /C:"package:%PKG%" "%DISABLED_FILE%" >nul 2>nul && (
    >>"%LOG_FILE%" echo SKIPPED: !PKG! - !LABEL! - already disabled
    set /a SKIPPED+=1
    exit /b
)
for %%P in (%PROTECTED%) do if "%%P"=="%PKG%" (
    echo    [skip] !LABEL!, !PKG! - protected, not touching it
    >>"%LOG_FILE%" echo PROTECTED: !PKG! - !LABEL!
    exit /b
)
if "%DRY_RUN%"=="1" (
    echo    [dry] !LABEL!  - !PKG!
    >>"%LOG_FILE%" echo WOULD REMOVE: !PKG! - !LABEL!
    set /a REMOVED+=1
    exit /b
)

set "OUT=_"
for /f "delims=" %%L in ('adb shell pm uninstall -k --user 0 %PKG% 2^>^&1') do set "OUT=!OUT! %%L"
if not "!OUT:Success=!"=="!OUT!" (
    echo    [ok] !LABEL!
    >>"%LOG_FILE%" echo REMOVED: !PKG! - !LABEL!
    >>"%RESTORE_FILE%" echo adb shell cmd package install-existing !PKG!
    set /a REMOVED+=1
    exit /b
)
if not "!OUT:not installed for=!"=="!OUT!" (
    >>"%LOG_FILE%" echo SKIPPED: !PKG! - !LABEL! - already removed
    set /a SKIPPED+=1
    exit /b
)

REM Some system apps refuse to uninstall - Mi Browser has, since MIUI 12. Disabling hides them just as well.
set "DOUT=_"
for /f "delims=" %%L in ('adb shell pm disable-user --user 0 %PKG% 2^>^&1') do set "DOUT=!DOUT! %%L"
if not "!DOUT:disabled-user=!"=="!DOUT!" (
    echo    [ok] !LABEL! - disabled, Xiaomi blocks uninstalling it
    >>"%LOG_FILE%" echo DISABLED: !PKG! - !LABEL! - uninstall said:!OUT:~1!
    >>"%RESTORE_FILE%" echo adb shell pm enable !PKG!
    set /a DISABLED+=1
    exit /b
)
echo    [FAIL] !LABEL!, !PKG! - the phone refused. Details in the log.
>>"%LOG_FILE%" echo FAILED: !PKG! - !LABEL! - uninstall:!OUT:~1! - disable:!DOUT:~1!
set /a FAILED+=1
exit /b

:check_essentials
REM Sets CHECK_MISSING to "_" plus [Name] for every essential that isn't installed.
adb shell pm list packages 2>nul | sort > "%NOW_FILE%"
set "CHECK_MISSING=_"
call :need "WhatsApp" com.whatsapp com.whatsapp.w4b
call :need "Gmail" com.google.android.gm
call :need "Google Maps" com.google.android.apps.maps
call :need "Phone" com.google.android.dialer com.android.contacts com.android.dialer
call :need "Messages" com.google.android.apps.messaging com.android.mms
call :need "Camera" com.android.camera com.google.android.GoogleCamera
call :need "Play Store" com.android.vending
exit /b

:need
REM %1 = name, %2... = packages, any one of them counts
set "NAME=%~1"
:need_next
shift
if "%~1"=="" (
    echo    [warn] !NAME! - not installed
    set "CHECK_MISSING=!CHECK_MISSING![!NAME!]"
    exit /b
)
findstr /L /X /C:"package:%~1" "%NOW_FILE%" >nul 2>nul && (
    echo    [ok] !NAME!
    exit /b
)
goto need_next

:sanity_check
echo.
echo    Sanity check...
call :check_essentials
set "LOST="
for %%N in ("WhatsApp" "Gmail" "Google Maps" "Phone" "Messages" "Camera" "Play Store") do (
    if not "!CHECK_MISSING:[%%~N]=!"=="!CHECK_MISSING!" (
        if "!MISSING_BEFORE:[%%~N]=!"=="!MISSING_BEFORE!" set "LOST=!LOST! [%%~N]"
    )
)
if defined LOST (
    echo.
    echo    [warn] Missing now but present before:!LOST! - check your phone.
    echo           Undo with: "%RESTORE_FILE%"
) else (
    echo    Everything you had before is still there.
)
exit /b

:browser_check
REM Anything that can still open a plain web link is a browser, whatever it calls itself.
echo.
echo    Browser check...
adb shell cmd package query-activities --brief -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d https://example.com > "%BROWSERS_FILE%" 2>&1
findstr /C:"No activities found" /C:"priority=" "%BROWSERS_FILE%" >nul 2>nul || (
    echo    [skip] This Android version can't answer the question.
    >>"%LOG_FILE%" echo BROWSER CHECK: unsupported
    exit /b
)
set "LEFTOVER="
for /f "tokens=1 delims=/ " %%P in ('findstr /R /C:"^ *[a-zA-Z][a-zA-Z0-9_.]*/" "%BROWSERS_FILE%"') do (
    set "LISTED=0"
    if "%DRY_RUN%"=="1" findstr /B /L /C:"%%P " "%STAGE1_LIST%" >nul 2>nul && set "LISTED=1"
    if "!LISTED!"=="0" set "LEFTOVER=!LEFTOVER! %%P"
)
if not defined LEFTOVER (
    if "%DRY_RUN%"=="1" (
        echo    [ok] Every app that opens web links today is on the list.
    ) else (
        echo    [ok] Nothing on this phone can open a web link anymore.
    )
    >>"%LOG_FILE%" echo BROWSER CHECK: clean
    exit /b
)
echo    [warn] These apps can still open web links:
for %%P in (!LEFTOVER!) do echo       - %%P
echo       Add them to lists\distractions.txt and run again to remove them.
>>"%LOG_FILE%" echo BROWSER CHECK: still handled by!LEFTOVER!
exit /b
