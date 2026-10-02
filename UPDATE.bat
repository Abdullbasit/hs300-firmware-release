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
REM ===========================================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

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
echo   current:
git log --oneline -1
echo.
echo   fetching...
git pull --ff-only
if errorlevel 1 (
  echo.
  echo   Pull refused - this folder has been edited by hand. It is published
  echo   output and should not be. Easiest fix: delete it and run SETUP.bat.
  echo.
  pause & exit /b 1
)
echo.
echo   now at:
git log --oneline -1

if not exist "%ARC%" (
  echo.
  echo   No %ARC% here - nothing to unpack.
  pause & exit /b 1
)

echo.
echo   unpacking - enter the password
echo.
set "PW="
set /p "PW=  password: "
echo.
"%SEVENZIP%" x -y -p"%PW%" "%ARC%"
set "PW="
if errorlevel 1 (
  echo.
  echo   *** Wrong password, or the archive is damaged. ***
  echo   The files you already had are untouched.
  echo.
  pause & exit /b 1
)

echo.
echo   ======================================================
echo    Updated. Boards available:
for /d %%D in ("%~dp0HS300_*") do (
  if exist "%%D\STABLE" (echo       %%~nxD   STABLE) else (echo       %%~nxD   no STABLE - ask the engineer)
)
echo.
echo    FLASH.bat ^<BOARD^> COM5
echo   ======================================================
echo.
pause
