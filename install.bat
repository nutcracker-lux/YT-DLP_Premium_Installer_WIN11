@echo off
setlocal enabledelayedexpansion

:: PowerShell helpers for colored output (reliable on all Windows versions)
set "CG=powershell -NoProfile -Command Write-Host -ForegroundColor Green"
set "CR=powershell -NoProfile -Command Write-Host -ForegroundColor Red"
set "CY=powershell -NoProfile -Command Write-Host -ForegroundColor Yellow"
set "CB=powershell -NoProfile -Command $Host.UI.RawUI.ForegroundColor='Cyan'"

set "PIP_MAX_ATTEMPTS=3"

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
:: SECTION 1: Detect / Install / Update Python (must be 3.12+)
:: ===========================================================================
echo [1/5] Checking Python installation...

:check_python
:: Check if Python >= 3.12 is already available
python -c "import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)" 2>nul
if %ERRORLEVEL% equ 0 goto :section2

:: Try Python Launcher (pre-installed on Windows 10+)
py -3.12 -c "import sys; sys.exit(0)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Python found via Launcher. Adding to PATH...
    for /f "delims=" %%P in ('py -3.12 -c "import sys; print(sys.executable)"') do set "PYTHON_EXE=%%P"
    for /f "delims=" %%D in ("!PYTHON_EXE!") do (
        set "PATH=%%~dpD;%PATH%"
        powershell -Command "[Environment]::SetEnvironmentVariable('Path',[Environment]::GetEnvironmentVariable('Path','User')+';%%~dpD','User')" >nul
    )
    python -c "import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)" 2>nul
    if !ERRORLEVEL! equ 0 goto :section2
)

:: Python not found or too old — install latest via winget
:install_python
%CY% '  Python not found (or below 3.12). Attempting auto-install...'

where winget >nul 2>nul
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  ERROR: winget not available on this system.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Research why your system might not have the winget feature.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  https://github.com/microsoft/winget-cli'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Then re-run this installer.'
    echo.
    echo %DATE% %TIME% - ERROR: winget not available >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

echo   Installing latest Python via winget (this may take a moment)...
:: Try versions from newest to oldest
winget install --exact --id Python.Python.3.14 --silent --accept-package-agreements
if %ERRORLEVEL% neq 0 winget install --exact --id Python.Python.3.13 --silent --accept-package-agreements
if %ERRORLEVEL% neq 0 winget install --exact --id Python.Python.3.12 --silent --accept-package-agreements
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Python could not be installed via winget.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Please open an issue at:'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  https://github.com/nutcracker-lux/YT-DLP_Premium_Installer_WIN11/issues'
    pause
    exit /b 1
)

%CB%

:: Wait for install to finish and PATH to update
echo   Python installed. Refreshing environment...
timeout /t 5 /nobreak >nul

:: Refresh PATH from registry for current session
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "PATH=%%B;%PATH%"

:: Verify installation
python --version >nul 2>nul
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Python could not be found after installation.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Try restarting this installer or install Python 3.12+ manually.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  MAKE SURE TO CHECK "Add Python to PATH" during installation!'
    pause
    exit /b 1
)

:python_found
echo %DATE% %TIME% - Python check passed >> "%DEBUG_LOG%"
python -c "import sys; sys.exit(0 if sys.version_info >= (3,12) else 1)" 2>nul
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  WARNING: Python 3.12+ not detected.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Please install Python 3.12+ manually from python.org'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  MAKE SURE TO CHECK "Add Python to PATH" during installation!'
    pause
    exit /b 1
)
for /f "tokens=2" %%V in ('python --version 2^>^&1') do set "PY_VER=%%V"
%CG% '  Python !PY_VER! found: OK'
echo.

:section2
%CB%
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
if !ERRORLEVEL! neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  FAILED: could not copy youtube_downloader.py'
    pause
    exit /b 1
)
echo   - youtube_downloader.py

if exist "%SCRIPT_DIR%\YT-DLP_Premium.ico" (
    copy /Y "%SCRIPT_DIR%\YT-DLP_Premium.ico" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 %CY% '  WARNING: could not copy .ico file'
    echo   - YT-DLP_Premium.ico
)

:: Copy rustypipe-botguard zip (shipped with installer, extracted in section 4)
set "RUSTYPIPE_ZIP="
for %%F in ("%SCRIPT_DIR%\rustypipe-botguard-*.zip") do (
    set "RUSTYPIPE_ZIP=%%F"
)
if defined RUSTYPIPE_ZIP (
    copy /Y "!RUSTYPIPE_ZIP!" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        %CY% '  WARNING: could not copy rustypipe zip'
        %CY% '  Manually copy it and unpack into:'
        %CY% '  %INSTALL_DIR%'
    )
    for %%F in ("!RUSTYPIPE_ZIP!") do echo   - %%~nxF
)

echo.
echo %DATE% %TIME% - Section 3 done >> "%DEBUG_LOG%"

%CB%
:: ===========================================================================
:: SECTION 4: Install dependencies (ffmpeg, yt-dlp, rustypipe-botguard)
:: ===========================================================================
echo %DATE% %TIME% - Starting Section 4 >> "%DEBUG_LOG%"
echo [4/5] Installing dependencies...

:: --- ffmpeg ---
echo   Checking ffmpeg...
where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    %CG% '  ffmpeg: found in PATH'
    goto :ffmpeg_done
)
echo     ffmpeg: installing via winget...
winget install --id Gyan.FFmpeg --silent --accept-package-agreements --accept-source-agreements
timeout /t 5 /nobreak >nul
:: Refresh PATH from registry
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
:: Verify ffmpeg is now findable
where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    %CG% '  ffmpeg: installed OK'
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  ffmpeg: install failed'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  ffmpeg is required for audio conversion.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Install manually from https://ffmpeg.org/ then re-run.'
    pause
    exit /b 1
)
:ffmpeg_done
echo %DATE% %TIME% - ffmpeg section done >> "%DEBUG_LOG%"
%CB%

:: --- Node.js (required for yt-dlp JS challenge solving on Windows) ---
echo   Checking Node.js...
:: Check if node is already in PATH
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    %CG% '  Node.js: found in PATH'
    goto :node_done
)
echo     Node.js: installing via winget...
:: Install Node.js silently via winget
winget install OpenJS.NodeJS --silent --accept-package-agreements
timeout /t 5 /nobreak >nul
:: Refresh PATH from registry so the current session can find node
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do if not "%%B"=="" set "PATH=%%B;%PATH%"
:: Verify node is now findable
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    %CG% '  Node.js: installed OK'
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Node.js: install failed'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Node.js is required for yt-dlp JS challenge solving on Windows.'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Install manually from https://nodejs.org/ then re-run.'
    pause
    exit /b 1
)
:node_done
echo %DATE% %TIME% - Node.js section done >> "%DEBUG_LOG%"
%CB%

:: --- rustypipe-botguard ---
echo     rustypipe-botguard.exe: extracting shipped zip...
set "RUSTYPE_SHIPPED="
for %%F in ("%INSTALL_DIR%\rustypipe-botguard-*.zip") do set "RUSTYPE_SHIPPED=%%F"
if defined RUSTYPE_SHIPPED (
    tar -xf "!RUSTYPE_SHIPPED!" -C "%INSTALL_DIR%"
)
if exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
    %CG% '  rustypipe-botguard: OK'
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  rustypipe-botguard: FAILED'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  Download rustypipe-botguard manually, unpack it'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  and paste the .exe into this folder:'
    :: SCRIPT ERROR STOP!!!!!!!!!
    %CR% '  %INSTALL_DIR%'
)
:rustypipe_done
echo %DATE% %TIME% - rustypipe section done >> "%DEBUG_LOG%"

:: --- Python packages ---
echo   Installing/upgrading Python packages...
call :pip_retry "yt-dlp[default]" "yt-dlp" :ytdlp_fail "yt-dlp[default] with extras"
goto :ytdlp_ok

:ytdlp_fail
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  yt-dlp: FAILED'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  yt-dlp is required. It could not be installed.'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  Tip: Re-run this installer and enter the SAME'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  folder name. Files are simply re-copied, so'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  no new folder or bloat is created.'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  Or install it manually:'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  python -m pip install -U "yt-dlp[default]"'
pause
exit /b 1

:ytdlp_ok
call :pip_retry "yt-dlp-get-pot-rustypipe" "yt-dlp-get-pot-rustypipe" :rustypipe_fail "yt-dlp-get-pot-rustypipe"
goto :rustypipe_ok

:rustypipe_fail
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  yt-dlp-get-pot-rustypipe: FAILED'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  yt-dlp-get-pot-rustypipe is required for bot solving.'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  Install manually:'
:: SCRIPT ERROR STOP!!!!!!!!!
%CR% '  python -m pip install -U yt-dlp-get-pot-rustypipe'
pause
exit /b 1

:rustypipe_ok
%CB%

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

%CB%
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

:: --- Create desktop shortcut ---
echo   Creating desktop shortcut...
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\%INSTALL_NAME%.lnk"
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.TargetPath='pythonw.exe';$s.Arguments='%INSTALL_DIR%\youtube_downloader.py';$s.WorkingDirectory='%INSTALL_DIR%';$s.Description='YouTube Music Premium Downloader';$s.Save()"
if exist "%INSTALL_DIR%\YT-DLP_Premium.ico" (
    powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.IconLocation='%INSTALL_DIR%\YT-DLP_Premium.ico';$s.Save()"
)
if exist "%SHORTCUT_PATH%" (
    %CG% '  Desktop shortcut created: %INSTALL_NAME%.lnk'
) else (
    %CY% '  Could not create desktop shortcut.'
    %CY% '  Run manually:'
    %CY% '  pythonw "%INSTALL_DIR%\youtube_downloader.py"'
)

:: --- Create uninstall.bat ---
copy /Y "%SCRIPT_DIR%\uninstall.bat" "%INSTALL_DIR%\uninstall.bat" >nul 2>&1
if !ERRORLEVEL! neq 0 (
    %CY% '  WARNING: could not copy uninstall.bat'
) else (
    echo   - uninstall.bat
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
echo  Launch via desktop shortcut: %INSTALL_NAME%.lnk
echo.
echo.
%CY% '  NOTE: The cookie extension is only required for'
%CY% '  YouTube Music Premium subscription users!'
echo.
set /p "OPEN_COOKIE=Open cookie extension page in your browser now? (y/N): "
if /i "!OPEN_COOKIE!"=="y" (
    echo   Opening cookie extension page...
    start https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc
) else (
    echo   You can open it later from the app's "Get Cookie Extension" button.
)
echo.
%CG% '  NEXT STEPS: (only required for YouTube Music Premium subscription users!)'
%CG% '   1. Export cookies.txt using the extension while logged into'
%CG% '      the account that has premium features - otherwise the'
%CG% '      cookies will not work'
%CG% '   2. Place cookies.txt into:'
%CG% '      %INSTALL_DIR%'
%CG% '   3. Launch the app and start downloading!'
echo.
%CG% '   NOTE: You can safely delete the unzipped folder you ran this'
%CG% '   installer from. Your installed folder is self-contained and'
%CG% '   includes the uninstaller.'
echo.
echo %DATE% %TIME% - Installer completed successfully >> "%DEBUG_LOG%"
echo  Thanks for downloading. -Nutcracker :)
%CR% '  BTC: 15hMZCUhPZs9tMAoVUR3YY4ZLxAKebo3wU'
echo.
echo ===========================================================================
echo.
pause
exit /b 0

:pip_retry
:: usage: call :pip_retry <package-spec> <display-label> <failure-label> <install-text>
set "PR_SPEC=%~1"
set "PR_LABEL=%~2"
set "PR_FAIL=%~3"
set "PR_INSTALL_TEXT=%~4"
set /a PR_TRY=0
:pip_retry_loop
set /a PR_TRY+=1
if !PR_TRY! gtr %PIP_MAX_ATTEMPTS% (
    echo %DATE% %TIME% - %PR_LABEL% failed after %PIP_MAX_ATTEMPTS% attempts >> "%DEBUG_LOG%"
    goto %PR_FAIL%
)
if !PR_TRY! equ 1 (
    echo     Installing !PR_INSTALL_TEXT!...
) else (
    echo %DATE% %TIME% - %PR_LABEL% attempt !PR_TRY! failed, retrying >> "%DEBUG_LOG%"
    %CY% '  !PR_LABEL! install failed. Retrying (attempt !PR_TRY!/%PIP_MAX_ATTEMPTS%)...'
    timeout /t 5 /nobreak >nul
)
python -m pip install --upgrade "!PR_SPEC!"
if not errorlevel 1 (
    %CG% '  !PR_LABEL!: OK'
    echo %DATE% %TIME% - %PR_LABEL% installed OK >> "%DEBUG_LOG%"
    exit /b 0
)
goto :pip_retry_loop
