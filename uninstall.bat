@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Uninstall yt-dlp / ffmpeg / Python stack
echo ============================================
echo.

REM ---- Step 1: pip uninstall yt-dlp-get-pot-rustypipe ----
echo [1/5] Uninstalling yt-dlp-get-pot-rustypipe...
py -m pip uninstall -y yt-dlp-get-pot-rustypipe
if %errorlevel% neq 0 (
    echo [FAILED] Step 1 did not complete successfully.
    pause
    exit /b %errorlevel%
)
echo [SUCCESS] Step 1 complete.
pause

REM ---- Step 2: pip uninstall yt-dlp[default] ----
echo [2/5] Uninstalling yt-dlp[default] via pip...
py -m pip uninstall -y "yt-dlp[default]"
if %errorlevel% neq 0 (
    echo [FAILED] Step 2 did not complete successfully.
    pause
    exit /b %errorlevel%
)
echo [SUCCESS] Step 2 complete.
pause

REM ---- Step 3: winget uninstall FFmpeg ----
echo [3/5] Uninstalling Gyan.FFmpeg...
winget uninstall "Gyan.FFmpeg"
if %errorlevel% neq 0 (
    echo [FAILED] Step 3 did not complete successfully.
    pause
    exit /b %errorlevel%
)
echo [SUCCESS] Step 3 complete.
pause

REM ---- Step 4: winget uninstall Python Launcher ----
echo [4/5] Uninstalling Python.Launcher...
winget uninstall "Python.Launcher"
if %errorlevel% neq 0 (
    echo [FAILED] Step 4 did not complete successfully.
    pause
    exit /b %errorlevel%
)
echo [SUCCESS] Step 4 complete.
pause

REM ---- Step 5: winget uninstall all Python versions the installer can use ----
echo [5/5] Uninstalling Python (all versions the installer may have installed)...
for %%P in (3.14 3.13 3.12) do (
    winget list --exact --id Python.Python.%%P >nul 2>&1
    if errorlevel 1 (
        echo [INFO] Python.Python.%%P not installed, skipping.
    ) else (
        echo   Uninstalling Python.Python.%%P...
        winget uninstall --exact --id Python.Python.%%P
        if not errorlevel 1 (
            echo [SUCCESS] Python.Python.%%P removed.
        ) else (
            echo [FAILED] Python.Python.%%P could not be uninstalled.
            pause
            exit /b 1
        )
    )
)
pause

echo.
echo ============================================
echo  Removing desktop shortcut and installation folder...
echo ============================================

REM Derive the install folder name from this script's own location
for %%I in ("%~dp0.") do set "INSTALL_NAME=%%~nxI"

REM Remove the desktop shortcut if it still exists
set "SHORTCUT=%USERPROFILE%\Desktop\!INSTALL_NAME!.lnk"
if exist "!SHORTCUT!" (
    del /f /q "!SHORTCUT!"
    echo [SUCCESS] Desktop shortcut removed.
) else (
    echo [INFO] Desktop shortcut not found, skipping.
)

REM Leave the folder before deleting it
cd /d "%SystemDrive%\"

REM Delete the whole installation folder (including this script)
if exist "%~dp0" (
    rmdir /s /q "%~dp0"
    echo [SUCCESS] Installation folder removed.
) else (
    echo [INFO] Installation folder already gone.
)

echo.
echo ============================================
echo  Uninstall complete.
echo ============================================
pause
endlocal
