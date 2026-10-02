@echo off
REM ===========================================================================
REM  HS300 - SET UP A LAPTOP TO FLASH DRIVES.  Double-click this. That is all.
REM
REM  For the technician's machine, not the development one. It does NOT install
REM  Keil and does not build firmware - it gets the ready-made images and the
REM  tools to put them on a drive.
REM
REM  Copy this one file anywhere (USB stick is fine) and run it. It will:
REM     1. install git, python and 7-Zip if they are missing
REM     2. install pyserial
REM     3. download the firmware archive from GitHub (public, no sign-in)
REM     4. ask for the password and unpack it
REM     5. check it all works and tell you the next command
REM
REM  You need the PASSWORD from the engineer. Everything else is automatic.
REM
REM  Safe to run again any time - that is also how you get new firmware later.
REM ===========================================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set REPO=https://github.com/Abdullbasit/hs300-firmware-release.git
set BRANCH=main
set DEST=hs300-firmware
set PROBLEM=0

echo.
echo  ========================================================
echo       HS300 drive-flashing laptop setup
echo  ========================================================
echo.

REM ---------------------------------------------------------------- git -----
call :need git "Git.Git" "%ProgramFiles%\Git\cmd"
if errorlevel 1 set PROBLEM=1

REM ------------------------------------------------------------- python -----
call :need python "Python.Python.3.12" "%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts"
if errorlevel 1 set PROBLEM=1

REM ----------------------------------------------------------- 7-Zip -----
call :need 7z "7zip.7zip" "%ProgramFiles%\7-Zip"
if errorlevel 1 set PROBLEM=1

if "%PROBLEM%"=="1" goto :sorry

REM ----------------------------------------------------------- pyserial -----
python -c "import serial" 2>nul
if errorlevel 1 (
  echo   [..] pyserial - installing
  python -m pip install --quiet --disable-pip-version-check pyserial
  python -c "import serial" 2>nul
  if errorlevel 1 (
    echo   [!!] pyserial would not install. Is this laptop online?
    set PROBLEM=1
    goto :sorry
  )
)
echo   [OK] pyserial

REM --------------------------------------------------------- the firmware ---
REM  There is ONE update path on purpose, and it is UPDATE.bat: it fetches
REM  first, checks the password actually opens the new archive, and only then
REM  replaces anything - so an offline laptop or a mistyped password costs
REM  nothing. Doing it again here would mean two copies of the careful part,
REM  and sooner or later only one of them would be right.
echo.
if exist "FLASH.bat" goto :inplace
if exist "%DEST%\.git" goto :handover

echo   [..] downloading the firmware folder
echo        No sign-in needed - this repository is public.
echo.
git clone --branch %BRANCH% --single-branch %REPO% "%DEST%"
if errorlevel 1 (
  echo.
  echo   [!!] Download failed - this laptop probably has no internet.
  echo        Nothing else was changed. Try again when it is online.
  set PROBLEM=1
  goto :sorry
)

:handover
if not exist "%DEST%\UPDATE.bat" (
  echo   [!!] the download did not complete - UPDATE.bat is not there.
  set PROBLEM=1
  goto :sorry
)
echo.
set HS300_NOPAUSE=1
call "%DEST%\UPDATE.bat"
set "HS300_NOPAUSE="
if errorlevel 1 (
  set PROBLEM=1
  goto :sorry
)

REM -------------------------------------------------------------- verify ----
echo.
if not exist "%DEST%\tools\hs300_ota.py" (
  echo   [!!] the flashing tools are not here - the download did not complete
  set PROBLEM=1
  goto :sorry
)
python "%DEST%\tools\hs300_ota.py" --help >nul 2>nul
if errorlevel 1 (
  echo   [!!] the flashing tool will not run
  set PROBLEM=1
  goto :sorry
)
echo   [OK] flashing tools run
goto :sorry

REM  SETUP.bat run from INSIDE the firmware folder. Hand over completely and
REM  exit on the same line: the update can rewrite this very file, and cmd
REM  reads a batch file from disk as it goes.
:inplace
echo   [..] this IS the firmware folder, so UPDATE.bat is the tool here.
if not exist "UPDATE.bat" (
  echo   [!!] UPDATE.bat is missing. Run SETUP.bat in a new, empty folder.
  echo.
  pause & exit /b 1
)
echo.
call "UPDATE.bat" & exit /b

:sorry
echo.
echo  ========================================================
if "%PROBLEM%"=="1" (
  echo    NOT FINISHED - see the [!!] lines above.
  echo    If it mentions closing the window, do that and run this again:
  echo    a freshly installed program is not visible until then.
) else (
  echo    READY.
  echo.
  if exist "%DEST%\FLASH.bat" ( set GO=cd %DEST% ) else ( set GO=you are in the right folder )
  echo    Next, in this order:
  echo.
  echo      !GO!
  echo      echo. ^> tty5.ttl             say once where the drive is
  echo      CHECK_SENSOR.bat             check the drive's current sensor
  echo      FLASH.bat ^<BOARD^>             put the firmware on it
  echo      DASHBOARD.bat                watch it in the browser
  echo.
  echo    The marker file IS the setting: name it after your port and cable,
  echo    tty5.ttl for the ST-Link lead or tty4.485 for the USB-RS485 one,
  echo    and every script finds the drive on its own after that.
  echo    It is tty and not com because Windows will not allow a file called
  echo    com5.anything - COM1 to COM9 are reserved device names.
  echo.
  echo    FLASH.bat on its own lists the boards it has.
  echo    docs^\MANUAL.md is the manual; docs^\TROUBLESHOOTING.md is sorted
  echo    by symptom. Read the manual before the first board.
  echo.
  echo    Run this SETUP again whenever new firmware is published.
)
echo  ========================================================
echo.
pause
exit /b 0

REM ===========================================================================
REM  :need <exe> <winget-id> <paths-to-try-after-install>
REM
REM  A program installed by winget is NOT on PATH in the window that installed
REM  it - Windows only picks it up in a new one. Telling the technician to
REM  close and reopen works but reads like a failure, so after installing we
REM  add the known location to PATH for this run and carry on.
REM ===========================================================================
:need
where %1 >nul 2>nul
if not errorlevel 1 (
  echo   [OK] %1
  exit /b 0
)
echo   [..] %1 - installing, this takes a minute
winget install --id %2 -e --source winget --accept-package-agreements --accept-source-agreements >nul 2>nul
set "PATH=%PATH%;%~3"
where %1 >nul 2>nul
if not errorlevel 1 (
  echo   [OK] %1 - installed
  exit /b 0
)
echo   [!!] %1 - installed but not visible yet.
echo        CLOSE THIS WINDOW and run SETUP.bat again.
exit /b 1
