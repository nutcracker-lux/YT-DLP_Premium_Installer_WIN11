@echo off
setlocal enabledelayedexpansion

set "DEBUG_LOG=%TEMP%\ytdlp_install_debug.log"
echo %DATE% %TIME% - Installer started > "%DEBUG_LOG%"

title YouTube Downloader - Windows Setup

color 0B
echo ===========================================================================
echo   YouTube Music Premium Downloader - Windows Setup
echo ===========================================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: ===========================================================================
:: SECTION 1: Check / Install Python
:: ===========================================================================
echo [1/5] Checking Python installation...

:check_python
where python >nul 2>nul
if %ERRORLEVEL% equ 0 goto :python_found

echo   Python not found. Attempting auto-install via winget...

where winget >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo   ERROR: winget not available on this system.
    echo   Please install Python 3.8+ manually from:
    echo   https://www.python.org/downloads/
    echo   MAKE SURE TO CHECK "Add Python to PATH" during installation!
    echo.
    echo %DATE% %TIME% - ERROR: winget not available >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

echo   Installing Python 3.12 via winget (this may take a moment)...
winget install --id Python.Python.3.12 --silent --accept-package-agreements >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo   WARNING: winget install failed. Trying alternative method...
    start https://www.python.org/downloads/
    echo   Please install Python 3.8+ manually. Make sure to check
    echo   "Add Python to PATH" during installation.
    echo.
    echo   After installing, re-run this installer.
    pause
    exit /b 1
)

:: Wait for install to finish and PATH to update
echo   Python installed. Refreshing environment...
timeout /t 5 /nobreak >nul

:: Refresh PATH from registry for current session
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "PATH=%%B;%PATH%"

:: Check again
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo   Python was installed but is not in PATH yet.
    echo   Please restart this installer or manually add Python to PATH.
    pause
    exit /b 1
)

:python_found
echo %DATE% %TIME% - Python check passed >> "%DEBUG_LOG%"
python --version 2>&1 | findstr "3." >nul
if %ERRORLEVEL% neq 0 (
    echo   WARNING: Python 3 not detected. Your default Python may be version 2.
    echo   Try installing Python 3.8+ from python.org
    pause
    exit /b 1
)
for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "PY_VER=%%V"
echo   Python !PY_VER! found: OK
echo.

:: ===========================================================================
:: SECTION 2: Choose install path
:: ===========================================================================
echo [2/5] Choose installation folder...

set "DEFAULT_NAME=YouTubeDownloader"
echo Enter a folder name for the installation.
echo It will be created inside your user folder: %USERPROFILE%
echo.
echo Default: %DEFAULT_NAME%
echo.
set /p "INSTALL_NAME=Folder name (or press Enter for default): "
if "%INSTALL_NAME%"=="" set "INSTALL_NAME=%DEFAULT_NAME%"

set "INSTALL_DIR=%USERPROFILE%\%INSTALL_NAME%"

if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%" 2>nul
)
if not exist "%INSTALL_DIR%" (
    echo ERROR: Could not create folder: %INSTALL_DIR%
    echo Check permissions for %USERPROFILE%
    pause
    exit /b 1
)
echo   Install folder: %INSTALL_DIR%
echo %DATE% %TIME% - Section 2 done, folder=%INSTALL_DIR% >> "%DEBUG_LOG%"
echo.

:: ===========================================================================
:: SECTION 3: Copy app files
:: ===========================================================================
echo %DATE% %TIME% - Starting Section 3 >> "%DEBUG_LOG%"
echo [3/5] Copying application files...

copy /Y "%SCRIPT_DIR%\youtube_downloader.py" "%INSTALL_DIR%\" >nul 2>&1
if !ERRORLEVEL! neq 0 echo WARNING: copy youtube_downloader.py failed >> "%DEBUG_LOG%"
echo   - youtube_downloader.py

if exist "%SCRIPT_DIR%\yt-dlp premium.ico" (
    copy /Y "%SCRIPT_DIR%\yt-dlp premium.ico" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 echo WARNING: copy .ico failed >> "%DEBUG_LOG%"
    echo   - yt-dlp premium.ico
)

:: Copy rustypipe-botguard zip (shipped with installer, extracted in section 4)
set "RUSTYPIPE_ZIP="
for %%F in ("%SCRIPT_DIR%\rustypipe-botguard-*.zip") do (
    set "RUSTYPIPE_ZIP=%%F"
)
if defined RUSTYPIPE_ZIP (
    copy /Y "!RUSTYPIPE_ZIP!" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 echo WARNING: copy rustypipe zip failed >> "%DEBUG_LOG%"
    for %%F in ("!RUSTYPIPE_ZIP!") do echo   - %%~nxF
)

echo.
echo %DATE% %TIME% - Section 3 done >> "%DEBUG_LOG%"

:: ===========================================================================
:: SECTION 4: Install dependencies (ffmpeg, yt-dlp, rustypipe-botguard)
:: ===========================================================================
echo %DATE% %TIME% - Starting Section 4 >> "%DEBUG_LOG%"
echo [4/5] Installing dependencies...

:: --- ffmpeg ---
echo   Checking ffmpeg...
where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo     ffmpeg: found in PATH
    goto :ffmpeg_done
)
echo     ffmpeg: installing via winget...
winget install --id Gyan.FFmpeg --silent --accept-package-agreements --accept-source-agreements
set "WINGET_EXIT=%ERRORLEVEL%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
if %WINGET_EXIT% equ 0 (
    echo     ffmpeg: installed OK
) else (
    echo     ffmpeg: install failed
)
:ffmpeg_done
echo %DATE% %TIME% - ffmpeg section done >> "%DEBUG_LOG%"

:: --- Node.js (required for yt-dlp JS challenge solving on Windows) ---
echo   Checking Node.js...
:: Check if node is already in PATH
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo     Node.js: found in PATH
    goto :node_done
)
echo     Node.js: not found. Installing via winget...
:: Install Node.js silently via winget
winget install OpenJS.NodeJS --silent --accept-package-agreements
set "WINGET_NODE_EXIT=%ERRORLEVEL%"
:: Refresh PATH from registry so the current session can find node
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
if %WINGET_NODE_EXIT% equ 0 (
    echo     Node.js: installed OK
) else (
    echo     Node.js: install failed
    echo     Some yt-dlp features may not work without Node.js.
    echo     Install manually from https://nodejs.org/
)
:node_done
echo %DATE% %TIME% - Node.js section done >> "%DEBUG_LOG%"

:: --- rustypipe-botguard ---
echo   Checking rustypipe-botguard...
if exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
    echo     rustypipe-botguard.exe: OK
    goto :rustypipe_done
)

echo     rustypipe-botguard.exe: extracting shipped zip...
set "RUSTYPE_SHIPPED="
for %%F in ("%INSTALL_DIR%\rustypipe-botguard-*.zip") do set "RUSTYPE_SHIPPED=%%F"
if defined RUSTYPE_SHIPPED (
    tar -xf "!RUSTYPE_SHIPPED!" -C "%INSTALL_DIR%"
)
if exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
    echo     rustypipe-botguard: OK
) else (
    echo     rustypipe-botguard: FAILED
)
:rustypipe_done
echo %DATE% %TIME% - rustypipe section done >> "%DEBUG_LOG%"

:: --- Python packages ---
echo   Installing/upgrading Python packages...
python -m pip install --upgrade pip --quiet 2>&1 | findstr /v "^$" >nul

echo     Installing yt-dlp...
python -m pip install --upgrade yt-dlp
if not errorlevel 1 ( echo     yt-dlp: OK ) else ( echo     yt-dlp: FAILED )

echo     Installing yt-dlp-get-pot-rustypipe...
python -m pip install --upgrade yt-dlp-get-pot-rustypipe
if not errorlevel 1 ( echo     yt-dlp-get-pot-rustypipe: OK ) else ( echo     yt-dlp-get-pot-rustypipe: FAILED )

:: Add Python Scripts directory to PATH (so yt-dlp is findable)
for /f "delims=" %%S in ('python -c "import site,os; print(os.path.join(os.path.dirname(site.getusersitepackages()),'Scripts'))" 2^>nul') do (
    set "SCRIPTS_DIR=%%S"
    set "PATH=%%S;%PATH%"
    powershell -Command "[Environment]::SetEnvironmentVariable('Path',[Environment]::GetEnvironmentVariable('Path','User')+';%%S','User')" >nul
)
if defined SCRIPTS_DIR echo     Added Scripts to PATH: !SCRIPTS_DIR!
echo %DATE% %TIME% - pip section done >> "%DEBUG_LOG%"
echo.
echo %DATE% %TIME% - Section 4 done >> "%DEBUG_LOG%"

:: ===========================================================================
:: SECTION 5: Finalize setup
:: ===========================================================================
echo %DATE% %TIME% - Starting Section 5 >> "%DEBUG_LOG%"
echo [5/5] Finalizing setup...

:: --- Create config.json ---
set "CONFIG_FILE=%INSTALL_DIR%\config.json"
if not exist "!CONFIG_FILE!" (
    (
        echo {
        echo     "install_root": "%INSTALL_DIR:\=\\%",
        echo     "cookie_file": "%INSTALL_DIR:\=\\%\\cookies.txt",
        echo     "rustypipe_bg_bin": "%INSTALL_DIR:\=\\%\\rustypipe-botguard.exe"
        echo }
    ) > "!CONFIG_FILE!"
    echo   - config.json created
)

:: --- Create F12 helper ---
set "F12_FILE=%INSTALL_DIR%\F12Developer_Tool_Command.txt"
(
    echo const allLinks = Array.from^(document.querySelectorAll^('a'^)^);
    echo const watchLinks = allLinks
    echo   .map(a =^> a.href^)
    echo   .filter(href =^> href.includes^('watch?v='^));
    echo.
    echo const uniqueLinks = [...new Set^(watchLinks^)];
    echo console.log^(uniqueLinks.join^('\n'^)^);
    echo.
    echo //######### PRESS ENTER AFTER LAST URL IN URL.txt #########
) > "%F12_FILE%"
echo   - F12Developer_Tool_Command.txt

:: --- Create desktop shortcut ---
echo   Creating desktop shortcut...
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\YouTube Downloader.lnk"
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.TargetPath='pythonw.exe';$s.Arguments='%INSTALL_DIR%\youtube_downloader.py';$s.WorkingDirectory='%INSTALL_DIR%';$s.Description='YouTube Music Premium Downloader';$s.Save()"
if exist "%INSTALL_DIR%\yt-dlp premium.ico" (
    powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.IconLocation='%INSTALL_DIR%\yt-dlp premium.ico';$s.Save()"
)
if exist "%SHORTCUT_PATH%" (
    echo   Desktop shortcut created.
) else (
    echo   Could not create shortcut. Run manually:
    echo     pythonw "%INSTALL_DIR%\youtube_downloader.py"
)

:: Clean up shipped zip files
for %%F in ("%INSTALL_DIR%\rustypipe-botguard-*.zip") do del "%%F" >nul 2>&1
if exist "%TEMP%\ffmpeg.zip" del "%TEMP%\ffmpeg.zip" >nul 2>&1

echo.
echo ===========================================================================
echo  INSTALLATION COMPLETE!
echo ===========================================================================
echo.
echo  Installed to: %INSTALL_DIR%
echo.
echo  Launch via desktop shortcut: YouTube Downloader
echo.
echo.
set /p "OPEN_COOKIE=Open cookie extension page in your browser now? (y/N): "
if /i "!OPEN_COOKIE!"=="y" (
    echo   Opening cookie extension page...
    start https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc
) else (
    echo   You can open it later from the app's "Get Cookie Extension" button.
)
echo.
echo  NEXT STEPS:
echo   1. Export cookies.txt using the extension
echo   2. Place cookies.txt into:
echo      %INSTALL_DIR%
echo   3. Launch the app and start downloading!
echo.
echo %DATE% %TIME% - Installer completed successfully >> "%DEBUG_LOG%"
echo  Thanks for downloading. -Nutcracker :)
echo  BTC: 15hMZCUhPZs9tMAoVUR3YY4ZLxAKebo3wU
echo.
echo ===========================================================================
echo.
pause
exit /b 0
