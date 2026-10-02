@echo off
REM ===========================================================================
REM  Get newly published firmware.  Run this where there IS internet.
REM
REM      UPDATE.bat
REM
REM  Afterwards everything works offline: flashing, zeroing and checking need
REM  only the serial cable.
REM
REM  You will be asked for the password - the same one the engineer gave you
REM  for SETUP. It is not stored anywhere; you type it each time.
REM
REM  NOTHING LOCAL IS DELETED UNTIL THE NEW FIRMWARE IS IN HAND. The order is
REM  deliberate: reach GitHub first, then check the password actually opens the
REM  new archive, and only then replace the firmware folders. If this laptop is
REM  offline, or the password is wrong, it stops with everything still working.
REM  An update that half-finishes on a laptop in a field is worse than no
REM  update at all.
REM
REM  Your own files are kept. Only what the archive delivers is replaced - so a
REM  marker file such as tty5.ttl, and any notes or logs you saved here, stay.
REM ===========================================================================
setlocal EnableDelayedExpansion

REM  Work from a copy in TEMP. "git reset" below can rewrite THIS VERY FILE,
REM  and cmd.exe reads a batch file from disk line by line as it runs - replace
REM  it underneath itself and execution jumps into whatever now sits at that
REM  byte offset. The copy is immune. The relaunch and the exit are on ONE line
REM  on purpose: once this line is parsed, no further read of this file happens.
if "%~1"=="--inplace" goto :work
set "WORK=%TEMP%\hs300_update"
rmdir /s /q "%WORK%" 2>nul
mkdir "%WORK%" 2>nul
copy /y "%~f0" "%WORK%\UPDATE.bat" >nul
call "%WORK%\UPDATE.bat" --inplace "%~dp0" & exit /b

:work
cd /d "%~2"
set ARC=hs300-release.7z

set SEVENZIP=%ProgramFiles%\7-Zip\7z.exe
if not exist "%SEVENZIP%" set SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe
if not exist "%SEVENZIP%" (
  echo   7-Zip is missing. Run SETUP.bat instead - it installs it.
  pause & exit /b 1
)
where git >nul 2>nul
if errorlevel 1 (
  echo   git is missing. Run SETUP.bat instead - it installs it.
  pause & exit /b 1
)
if not exist ".git" (
  echo.
  echo   This folder was not downloaded with git, so it cannot update itself.
  echo   Run SETUP.bat instead.
  echo.
  pause & exit /b 1
)

echo.
echo   you have:
git log --oneline -1
echo.
echo   checking GitHub...

REM  fetch only - this writes nothing into the folder you can see.
git fetch -q origin main
if errorlevel 1 (
  echo.
  echo   Could not reach GitHub, so there is no new firmware to install.
  echo   NOTHING WAS CHANGED - everything you had still works offline.
  echo   Try again on a connection that works.
  echo.
  pause & exit /b 1
)

REM  Compare what was last UNPACKED, not what git has checked out. They are not
REM  the same thing: a reset by hand, or an unpack that was interrupted, leaves
REM  git pointing at the new release while the files on disk are still the old
REM  ones. HEAD is what we HAVE; .unpacked is what we have actually INSTALLED.
set "HAVE="
if exist ".unpacked" set /p HAVE=<.unpacked
for /f %%H in ('git rev-parse FETCH_HEAD') do set "WANT=%%H"
if "!HAVE!"=="!WANT!" if exist "tools\hs300_ota.py" (
  echo.
  echo   Already up to date - this is the firmware that is published.
  echo   Nothing to do, nothing changed.
  echo.
  if not defined HS300_NOPAUSE pause
  exit /b 0
)

echo   new firmware is published:
git log --oneline -1 FETCH_HEAD

REM  --hard, and onto FETCH_HEAD rather than a pull: it must work even when the
REM  published history was replaced rather than added to. It only touches files
REM  git is tracking - the archive and these scripts - so anything you made
REM  yourself is left alone.
git reset -q --hard FETCH_HEAD
if errorlevel 1 (
  echo.
  echo   Could not apply the update. NOTHING WAS CHANGED.
  echo   Tell the engineer; do not try to fix it by hand.
  echo.
  pause & exit /b 1
)
if not exist "%ARC%" (
  echo.
  echo   The download did not include %ARC%. Nothing was unpacked.
  pause & exit /b 1
)

echo.
echo   enter the password you were given
echo.
set "PW="
set /p "PW=  password: "
echo.

REM  TEST the archive before deleting a single file. This is the whole point of
REM  the order: a wrong password here costs nothing.
echo   checking the password...
"%SEVENZIP%" t -p"!PW!" "%ARC%" >nul
if errorlevel 1 (
  set "PW="
  echo.
  echo   *** Wrong password, or the archive is damaged. ***
  echo   NOTHING WAS DELETED - the firmware you had is untouched.
  echo.
  pause & exit /b 1
)
echo   password is good.

REM  Now, and only now, clear out the old firmware so a board or a tool that
REM  was WITHDRAWN does not sit here looking current. Only what the archive
REM  delivers is removed; your marker file, notes and logs are not.
echo   removing the old firmware...
for /d %%D in ("HS300_*") do rmdir /s /q "%%D"
rmdir /s /q "tools"      2>nul
rmdir /s /q "docs"       2>nul
rmdir /s /q "bootloader" 2>nul
del /q "FLASH.bat" "CHECK_SENSOR.bat" "ZERO_ADC.bat" "PORT.bat" "DASHBOARD.bat" 2>nul

echo   unpacking the new firmware...
"%SEVENZIP%" x -y -p"!PW!" "%ARC%" >nul
set RC=!ERRORLEVEL!
set "PW="
if not "!RC!"=="0" (
  echo.
  echo   *** The unpack FAILED after the old firmware was removed. ***
  echo   This folder is now incomplete. Run SETUP.bat in a new, empty
  echo   folder - do not flash anything from here.
  echo.
  pause & exit /b 1
)
if not exist "tools\hs300_ota.py" (
  echo.
  echo   *** The unpack finished but the flashing tools are not there. ***
  echo   Do not flash from here. Tell the engineer.
  echo.
  pause & exit /b 1
)

REM  Written LAST, and only now: it is the record that the files on disk really
REM  are this release. Writing it any earlier would make an interrupted unpack
REM  look finished.
git rev-parse HEAD > ".unpacked"

echo.
echo   ======================================================
echo    Updated. Boards available:
for /d %%D in ("HS300_*") do (
  if exist "%%D\STABLE" (echo       %%~nxD   STABLE) else (echo       %%~nxD   no STABLE - ask the engineer)
)
echo.
echo    FLASH.bat ^<BOARD^>        with a marker file such as tty5.ttl
echo    FLASH.bat ^<BOARD^> COM5   or name the port yourself
echo   ======================================================
echo.
if not defined HS300_NOPAUSE pause
exit /b 0
