@echo off
REM ===========================================================================
REM  Get the published firmware.  Run this where there IS internet.
REM
REM      UPDATE.bat
REM
REM  Afterwards everything works offline: flashing, zeroing and checking need
REM  only the serial cable.
REM
REM  You will be asked for the password - the same one the engineer gave you
REM  for SETUP. It is not stored anywhere; you type it each time.
REM
REM  IT REPLACES THE WHOLE FOLDER WITH A CLEAN ONE. Nothing is merged and
REM  nothing is left over, so a board or a tool that was WITHDRAWN cannot sit
REM  here looking current, and a half-finished earlier attempt cannot survive.
REM
REM  NOTHING LOCAL IS TOUCHED UNTIL THE NEW TREE IS COMPLETE AND PROVEN. The
REM  download and the unpack both happen in a TEMPORARY folder; only once the
REM  password has opened it and the flashing tool is really there does this
REM  folder get replaced. If the laptop is offline, or the password is wrong, it
REM  stops with everything exactly as it was. An update that half-finishes on a
REM  laptop in a field is worse than no update at all.
REM
REM  THE ONE THING CARRIED ACROSS is your marker file - tty5.ttl, tty4.485 and
REM  the like. That is configuration, not content: losing it would quietly
REM  leave the scripts not knowing which cable the drive is on. Anything else
REM  you kept in here is NOT preserved, so keep notes and logs somewhere else.
REM ===========================================================================
setlocal EnableDelayedExpansion

REM  Work from a copy in TEMP. This folder is about to be replaced wholesale,
REM  including this very file, and cmd.exe reads a batch file from disk line by
REM  line as it runs - pull it out from underneath itself and execution jumps
REM  into whatever now sits at that byte offset. The copy is immune. The
REM  relaunch and the exit share ONE line on purpose: once that line is parsed,
REM  this file is never read again.
if "%~1"=="--inplace" goto :work
set "WORK=%TEMP%\hs300_update"
rmdir /s /q "%WORK%" 2>nul
mkdir "%WORK%" 2>nul
copy /y "%~f0" "%WORK%\UPDATE.bat" >nul
call "%WORK%\UPDATE.bat" --inplace "%~dp0" & exit /b

:work
set REPO=https://github.com/Abdullbasit/hs300-firmware-release.git
set BRANCH=main
set ARC=hs300-release.7z

REM  %~2 arrives with a trailing backslash; strip it so it can be used as a name.
set "DIR=%~2"
if "!DIR:~-1!"=="\" set "DIR=!DIR:~0,-1!"
for %%P in ("!DIR!") do set "PARENT=%%~dpP"
set "NEW=%TEMP%\hs300_new"

REM  Sit in the PARENT, never inside the folder being replaced.
cd /d "!PARENT!"

set SEVENZIP=%ProgramFiles%\7-Zip\7z.exe
if not exist "!SEVENZIP!" set SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe
if not exist "!SEVENZIP!" (
  echo   7-Zip is missing. Run SETUP.bat instead - it installs it.
  pause & exit /b 1
)
where git >nul 2>nul
if errorlevel 1 (
  echo   git is missing. Run SETUP.bat instead - it installs it.
  pause & exit /b 1
)

echo.
echo   downloading to a temporary folder first - nothing here is touched yet
echo.
rmdir /s /q "!NEW!" 2>nul
git clone -q --depth 1 --branch %BRANCH% --single-branch %REPO% "!NEW!"
if errorlevel 1 (
  rmdir /s /q "!NEW!" 2>nul
  echo.
  echo   Could not reach GitHub, so there is no new firmware to install.
  echo   NOTHING WAS CHANGED - everything you had still works offline.
  echo   Try again on a connection that works.
  echo.
  pause & exit /b 1
)
if not exist "!NEW!\%ARC%" (
  rmdir /s /q "!NEW!" 2>nul
  echo.
  echo   The download did not contain %ARC%. NOTHING WAS CHANGED.
  echo.
  pause & exit /b 1
)
echo   got it:
git -C "!NEW!" log --oneline -1

echo.
echo   enter the password you were given
echo.
set "PW="
set /p "PW=  password: "
echo.

REM  Test, then unpack, and only then replace. A mistyped password costs
REM  nothing at all at this point.
echo   checking the password...
"!SEVENZIP!" t -p"!PW!" "!NEW!\%ARC%" >nul
if errorlevel 1 (
  set "PW="
  rmdir /s /q "!NEW!" 2>nul
  echo.
  echo   *** Wrong password, or the archive is damaged. ***
  echo   NOTHING WAS CHANGED - the firmware you had is untouched.
  echo.
  pause & exit /b 1
)
echo   password is good. unpacking...
"!SEVENZIP!" x -y -p"!PW!" -o"!NEW!" "!NEW!\%ARC%" >nul
set RC=!ERRORLEVEL!
set "PW="
if not "!RC!"=="0" (
  rmdir /s /q "!NEW!" 2>nul
  echo.
  echo   The unpack failed. NOTHING WAS CHANGED.
  echo.
  pause & exit /b 1
)
if not exist "!NEW!\tools\hs300_ota.py" (
  rmdir /s /q "!NEW!" 2>nul
  echo.
  echo   The new folder has no flashing tools in it, so it is not usable.
  echo   NOTHING WAS CHANGED. Tell the engineer.
  echo.
  pause & exit /b 1
)

REM  The new tree is complete and proven. Carry the marker file across BEFORE
REM  the mirror, or the mirror would delete it as "not in the new tree".
if exist "!DIR!" (
  REM  By EXTENSION, exactly as PORT.bat itself looks for them - NOT by a
  REM  "port*" prefix, which also matched PORT.bat and copied the OLD one over
  REM  the new tree's, pinning it for ever.
  for %%M in ("!DIR!\*.ttl" "!DIR!\*.485" "!DIR!\*.rs485") do (
    if exist "%%M" copy /y "%%M" "!NEW!\" >nul & echo   keeping your marker file %%~nxM
  )
)

echo.
echo   replacing this folder with the new one...
if not exist "!DIR!" mkdir "!DIR!"
REM  /MIR copies everything in AND deletes whatever is not in the new tree, so
REM  the result is exactly the new release with no leftovers. It never renames
REM  or deletes the folder itself, which matters: Windows refuses that while any
REM  window is sitting in it. Robocopy codes below 8 are success, not failure.
robocopy "!NEW!" "!DIR!" /MIR /NFL /NDL /NJH /NJS /NP >nul
if !ERRORLEVEL! GEQ 8 (
  echo.
  echo   *** This folder could not be replaced. ***
  echo   The new firmware is still in "!NEW!" - do not delete it, and tell
  echo   the engineer.
  echo.
  pause & exit /b 1
)
rmdir /s /q "!NEW!" 2>nul

if not exist "!DIR!\tools\hs300_ota.py" (
  echo.
  echo   *** This folder is incomplete after replacing it. ***
  echo   Do not flash from here. Tell the engineer.
  echo.
  pause & exit /b 1
)

echo.
echo   ======================================================
echo    Updated - this folder is now exactly what is published.
echo.
echo    Boards available:
for /d %%D in ("!DIR!\HS300_*") do (
  if exist "%%D\STABLE" (echo       %%~nxD   STABLE) else (echo       %%~nxD   no STABLE - ask the engineer)
)
echo.
echo    FLASH.bat ^<BOARD^>        with a marker file such as tty5.ttl
echo    FLASH.bat ^<BOARD^> COM5   or name the port yourself
echo   ======================================================
echo.
if not defined HS300_NOPAUSE pause
exit /b 0
