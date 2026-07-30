@echo off
setlocal enabledelayedexpansion

:: ANSI escape codes for colored output (Windows 10+)
for /F "delims=#" %%a in ('prompt #$E#^& for %%b in (1) do rem') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "YELLOW=%ESC%[93m"
set "RESET=%ESC%[0m"

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
if %ERRORLEVEL% equ 0 goto :python_found

:: Try Python Launcher (pre-installed on Windows 10+)
py -3.12 -c "import sys; sys.exit(0)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   Python found via Launcher. Adding to PATH...
    for /f "delims=" %%P in ('py -3.12 -c "import sys; print(sys.executable)"') do set "PYTHON_EXE=%%P"
    for /f "delims=" %%D in ("!PYTHON_EXE!") do (
        set "PATH=%%~dpD;%PATH%"
        powershell -Command "[Environment]::SetEnvironmentVariable('Path',[Environment]::GetEnvironmentVariable('Path','User')+';%%~dpD','User')" >nul
    )
    goto :python_found
)

:: Python not found or too old — install latest via winget
:install_python
echo   Python not found (or below 3.12). Attempting auto-install...

where winget >nul 2>nul
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%ERROR: winget not available on this system.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Please install Python 3.12+ manually from:%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%https://www.python.org/downloads/%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%MAKE SURE TO CHECK "Add Python to PATH" during installation!%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Then re-run this installer.%RESET%
    echo.
    echo %DATE% %TIME% - ERROR: winget not available >> "%DEBUG_LOG%"
    pause
    exit /b 1
)

echo   Installing latest Python via winget (this may take a moment)...
:: Try versions from newest to oldest
winget install --exact --id Python.Python.3.14 --silent --accept-package-agreements >nul 2>&1
if %ERRORLEVEL% neq 0 winget install --exact --id Python.Python.3.13 --silent --accept-package-agreements >nul 2>&1
if %ERRORLEVEL% neq 0 winget install --exact --id Python.Python.3.12 --silent --accept-package-agreements >nul 2>&1
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%WARNING: winget install failed. Trying alternative method...%RESET%
    start https://www.python.org/downloads/
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Please install Python 3.12+ manually. Make sure to check%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%"Add Python to PATH" during installation.%RESET%
    echo.
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%After installing, re-run this installer.%RESET%
    pause
    exit /b 1
)

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
    echo   %RED%Python was installed but is not in PATH yet.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Please restart this installer or manually add Python to PATH.%RESET%
    pause
    exit /b 1
)

:python_found
echo %DATE% %TIME% - Python check passed >> "%DEBUG_LOG%"
python --version 2>&1 | findstr /r "3\.(1[2-9]|[2-9][0-9])" >nul
if %ERRORLEVEL% neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%WARNING: Python 3.12+ not detected.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Your Python version may be too old.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%Please install Python 3.12+ from python.org%RESET%
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
if !ERRORLEVEL! neq 0 (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo   %RED%FAILED: could not copy youtube_downloader.py%RESET%
    pause
    exit /b 1
)
echo   - youtube_downloader.py

if exist "%SCRIPT_DIR%\yt-dlp premium.ico" (
    copy /Y "%SCRIPT_DIR%\yt-dlp premium.ico" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 echo   %YELLOW%WARNING: could not copy .ico file%RESET%
    echo   - yt-dlp premium.ico
)

:: Copy rustypipe-botguard zip (shipped with installer, extracted in section 4)
set "RUSTYPIPE_ZIP="
for %%F in ("%SCRIPT_DIR%\rustypipe-botguard-*.zip") do (
    set "RUSTYPIPE_ZIP=%%F"
)
if defined RUSTYPIPE_ZIP (
    copy /Y "!RUSTYPIPE_ZIP!" "%INSTALL_DIR%\" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        echo   %YELLOW%WARNING: could not copy rustypipe zip%RESET%
        echo   %YELLOW%Manually copy it and unpack into:%RESET%
        echo   %YELLOW%%INSTALL_DIR%%RESET%
    )
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
    echo     %GREEN%ffmpeg: found in PATH%RESET%
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
    echo     %GREEN%ffmpeg: installed OK%RESET%
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%ffmpeg: install failed%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%ffmpeg is required for audio conversion.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Install manually from https://ffmpeg.org/ then re-run.%RESET%
    pause
    exit /b 1
)
:ffmpeg_done
echo %DATE% %TIME% - ffmpeg section done >> "%DEBUG_LOG%"

:: --- Node.js (required for yt-dlp JS challenge solving on Windows) ---
echo   Checking Node.js...
:: Check if node is already in PATH
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo     %GREEN%Node.js: found in PATH%RESET%
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
    echo     %GREEN%Node.js: installed OK%RESET%
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Node.js: install failed%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Node.js is required for yt-dlp JS challenge solving on Windows.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Install manually from https://nodejs.org/ then re-run.%RESET%
    pause
    exit /b 1
)
:node_done
echo %DATE% %TIME% - Node.js section done >> "%DEBUG_LOG%"

:: --- rustypipe-botguard ---
echo     rustypipe-botguard.exe: extracting shipped zip...
set "RUSTYPE_SHIPPED="
for %%F in ("%INSTALL_DIR%\rustypipe-botguard-*.zip") do set "RUSTYPE_SHIPPED=%%F"
if defined RUSTYPE_SHIPPED (
    tar -xf "!RUSTYPE_SHIPPED!" -C "%INSTALL_DIR%"
)
if exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
    echo     %GREEN%rustypipe-botguard: OK%RESET%
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%rustypipe-botguard: FAILED%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Download rustypipe-botguard manually, unpack it%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%and paste the .exe into this folder:%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%%INSTALL_DIR%%RESET%
)
:rustypipe_done
echo %DATE% %TIME% - rustypipe section done >> "%DEBUG_LOG%"

:: --- Python packages ---
echo   Installing/upgrading Python packages...
python -m pip install --upgrade pip --quiet 2>&1 | findstr /v "^$" >nul

echo     Installing yt-dlp[default] with extras...
python -m pip install --upgrade "yt-dlp[default]"
if not errorlevel 1 (
    echo     %GREEN%yt-dlp: OK%RESET%
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%yt-dlp: FAILED%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%yt-dlp is required. Install manually:%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%python -m pip install -U "yt-dlp[default]"%RESET%
    pause
    exit /b 1
)

echo     Installing yt-dlp-get-pot-rustypipe...
python -m pip install --upgrade yt-dlp-get-pot-rustypipe
if not errorlevel 1 (
    echo     %GREEN%yt-dlp-get-pot-rustypipe: OK%RESET%
) else (
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%yt-dlp-get-pot-rustypipe: FAILED%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%yt-dlp-get-pot-rustypipe is required for bot solving.%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%Install manually:%RESET%
    :: SCRIPT ERROR STOP!!!!!!!!!
    echo     %RED%python -m pip install -U yt-dlp-get-pot-rustypipe%RESET%
    pause
    exit /b 1
)

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

:: --- Create desktop shortcut ---
echo   Creating desktop shortcut...
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\%INSTALL_NAME%.lnk"
powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.TargetPath='pythonw.exe';$s.Arguments='%INSTALL_DIR%\youtube_downloader.py';$s.WorkingDirectory='%INSTALL_DIR%';$s.Description='YouTube Music Premium Downloader';$s.Save()"
if exist "%INSTALL_DIR%\yt-dlp premium.ico" (
    powershell -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%');$s.IconLocation='%INSTALL_DIR%\yt-dlp premium.ico';$s.Save()"
)
if exist "%SHORTCUT_PATH%" (
    echo     %GREEN%Desktop shortcut created: %INSTALL_NAME%.lnk%RESET%
) else (
    echo     %YELLOW%Could not create desktop shortcut.%RESET%
    echo     %YELLOW%Run manually:%RESET%
    echo     %YELLOW%pythonw "%INSTALL_DIR%\youtube_downloader.py"%RESET%
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
