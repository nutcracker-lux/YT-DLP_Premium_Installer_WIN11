@echo off
setlocal enabledelayedexpansion

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

set "DEFAULT_DIR=%USERPROFILE%\YouTubeDownloader"
echo Default: %DEFAULT_DIR%
echo.
set /p "INSTALL_DIR=Enter path (or press Enter for default): "
if "%INSTALL_DIR%"=="" set "INSTALL_DIR=%DEFAULT_DIR%"

if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%" 2>nul
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Could not create folder: %INSTALL_DIR%
        pause
        exit /b 1
    )
)
echo   Install folder: %INSTALL_DIR%
echo.

:: ===========================================================================
:: SECTION 3: Copy app files
:: ===========================================================================
echo [3/5] Copying application files...

copy /Y "%SCRIPT_DIR%\youtube_downloader.py" "%INSTALL_DIR%\" >nul 2>&1
echo   - youtube_downloader.py

if exist "%SCRIPT_DIR%\yt-dlp premium.ico" (
    copy /Y "%SCRIPT_DIR%\yt-dlp premium.ico" "%INSTALL_DIR%\" >nul 2>&1
    echo   - yt-dlp premium.ico
)

:: Copy rustypipe-botguard zip (shipped with installer, extracted in section 4)
set "RUSTYPIPE_ZIP="
for %%F in ("%SCRIPT_DIR%\rustypipe-botguard-*.zip") do (
    set "RUSTYPIPE_ZIP=%%F"
)
if defined RUSTYPIPE_ZIP (
    copy /Y "!RUSTYPIPE_ZIP!" "%INSTALL_DIR%\" >nul 2>&1
    for %%F in ("!RUSTYPIPE_ZIP!") do echo   - %%~nxF
)

echo.

:: ===========================================================================
:: SECTION 4: Install dependencies (ffmpeg, yt-dlp, rustypipe-botguard)
:: ===========================================================================
echo [4/5] Installing dependencies...

:: --- ffmpeg ---
echo   Checking ffmpeg...
where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%F in ('where ffmpeg') do set "FFMPEG_PATH=%%F"
    echo     ffmpeg found: !FFMPEG_PATH!
) else (
    echo     ffmpeg not found. Attempting to install automatically...

    :: Method 1: winget
    where winget >nul 2>nul
    if !ERRORLEVEL! equ 0 (
        echo     Trying via winget...
        winget install --id Gyan.FFmpeg --silent --accept-package-agreements 2>&1 | findstr /i "success" >nul
        if !ERRORLEVEL! equ 0 goto :ffmpeg_done
        winget install --id ffmpeg --silent --accept-package-agreements 2>&1 | findstr /i "success" >nul
        if !ERRORLEVEL! equ 0 goto :ffmpeg_done
    )

    :: Method 2: Direct download of ffmpeg portable
    echo     Downloading ffmpeg portable (via gyan.dev, ~70 MB)...
    echo     This may take a moment...
    powershell -Command "& {
        $wc = New-Object System.Net.WebClient;
        $wc.Headers['User-Agent'] = 'YouTube-Downloader-Installer';
        $url = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
        $zip = \"%TEMP%\ffmpeg.zip\";
        try {
            Write-Host '    Downloading...';
            $wc.DownloadFile($url, $zip);
            Write-Host '    Extracting to %INSTALL_DIR%...';
            Expand-Archive -Path $zip -DestinationPath \"%TEMP%\ffmpeg_extract\" -Force;
            $ffmpegDir = Get-ChildItem -Path \"%TEMP%\ffmpeg_extract\" -Directory | Select-Object -First 1;
            if ($ffmpegDir) {
                Copy-Item \"$($ffmpegDir.FullName)\ffmpeg.exe\" \"%INSTALL_DIR%\ffmpeg.exe\" -Force;
                Remove-Item \"%TEMP%\ffmpeg_extract\" -Recurse -Force;
                Write-Host '    ffmpeg.exe installed in app folder.';
            }
            Remove-Item $zip -Force;
        } catch {
            Write-Host '    Download failed: ' + $_.Exception.Message;
        }
    }"

    if exist "%INSTALL_DIR%\ffmpeg.exe" (
        set "FFMPEG_PATH=%INSTALL_DIR%\ffmpeg.exe"
        set "PATH=%INSTALL_DIR%;%PATH%"
    ) else (
        echo     WARNING: Could not install ffmpeg automatically.
        echo     Download manually from: https://ffmpeg.org/download.html
        echo     Make sure ffmpeg.exe is in PATH or place it in %INSTALL_DIR%
    )

    :ffmpeg_done
    echo     ffmpeg: OK
)

:: --- rustypipe-botguard ---
echo   Checking rustypipe-botguard...
if not exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
    set "RUSTYPIPE_ZIP_FILE="
    for /f "delims=" %%F in ('dir /b "%INSTALL_DIR%\rustypipe-botguard-*.zip" 2^>nul') do set "RUSTYPIPE_ZIP_FILE=%INSTALL_DIR%\%%F"
    
    if not defined RUSTYPIPE_ZIP_FILE (
        for /f "delims=" %%F in ('dir /b "%SCRIPT_DIR%\rustypipe-botguard-*.zip" 2^>nul') do set "RUSTYPIPE_ZIP_FILE=%SCRIPT_DIR%\%%F"
        if defined RUSTYPIPE_ZIP_FILE (
            echo     Found in source: !RUSTYPIPE_ZIP_FILE!
            copy /Y "!RUSTYPIPE_ZIP_FILE!" "%INSTALL_DIR%\" >nul 2>&1
            for /f "delims=" %%F in ('dir /b "%INSTALL_DIR%\rustypipe-botguard-*.zip" 2^>nul') do set "RUSTYPIPE_ZIP_FILE=%INSTALL_DIR%\%%F"
        )
    )
    
    if defined RUSTYPIPE_ZIP_FILE (
        echo     Found: !RUSTYPIPE_ZIP_FILE!
        echo     Extracting rustypipe-botguard...
        powershell -Command "Expand-Archive -Path '!RUSTYPIPE_ZIP_FILE!' -DestinationPath '%INSTALL_DIR%' -Force"
        del "!RUSTYPIPE_ZIP_FILE!" 2>nul
    )
    
    if not exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
        for /r "%INSTALL_DIR%" %%F in (rustypipe-botguard.exe) do (
            if exist "%%F" copy /Y "%%F" "%INSTALL_DIR%\" >nul
        )
    )
    
    if exist "%INSTALL_DIR%\rustypipe-botguard.exe" (
        echo     rustypipe-botguard.exe installed.
    ) else (
        echo     No local zip found. Downloading rustypipe-botguard (~16 MB)...
        powershell -Command "& {
            $wc = New-Object System.Net.WebClient;
            $wc.Headers['User-Agent'] = 'YouTube-Downloader-Installer';
            $url = 'https://codeberg.org/ThetaDev/rustypipe-botguard/releases/download/v0.1.2/rustypipe-botguard-v0.1.2-x86_64-pc-windows-msvc.zip';
            $zip = \"%TEMP%\rustypipe-botguard.zip\";
            try {
                $wc.DownloadFile($url, $zip);
                Expand-Archive -Path $zip -DestinationPath \"%INSTALL_DIR%\" -Force;
                Remove-Item $zip -Force;
                Write-Host '    rustypipe-botguard.exe installed.';
            } catch {
                Write-Host '    Download failed: ' + $_.Exception.Message;
                exit 1
            }
        }"
        if !ERRORLEVEL! neq 0 (
            echo     WARNING: Could not get rustypipe-botguard.
            echo     Download manually from: https://codeberg.org/ThetaDev/rustypipe-botguard/releases
        )
    )
) else (
    echo     rustypipe-botguard.exe already present.
)

:: --- Python packages ---
echo   Installing/upgrading Python packages...
python -m pip install --upgrade pip --quiet 2>&1 | findstr /v "^$" >nul

echo     Installing yt-dlp...
python -m pip install --upgrade yt-dlp --quiet
if %ERRORLEVEL% equ 0 ( echo     yt-dlp: OK ) else ( echo     yt-dlp: FAILED )

echo     Installing yt-dlp-get-pot-rustypipe...
python -m pip install --upgrade yt-dlp-get-pot-rustypipe --quiet
if %ERRORLEVEL% equ 0 ( echo     yt-dlp-get-pot-rustypipe: OK ) else ( echo     yt-dlp-get-pot-rustypipe: FAILED )

echo.

:: ===========================================================================
:: SECTION 5: Finalize setup
:: ===========================================================================
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
    echo const allLinks = Array.from(document.querySelectorAll('a'));
    echo const watchLinks = allLinks
    echo   .map(a =^> a.href)
    echo   .filter(href =^> href.includes('watch?v='));
    echo.
    echo const uniqueLinks = [...new Set(watchLinks)];
    echo console.log(uniqueLinks.join('\n'));
    echo.
    echo //######### PRESS ENTER AFTER LAST URL IN URL.txt #########
) > "%F12_FILE%"
echo   - F12Developer_Tool_Command.txt

:: --- Create desktop shortcut ---
echo   Creating desktop shortcut...
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\YouTube Downloader.lnk"
powershell -Command "& {
    $WScriptShell = New-Object -ComObject WScript.Shell;
    $Shortcut = $WScriptShell.CreateShortcut('%SHORTCUT_PATH%');
    $Shortcut.TargetPath = 'pythonw.exe';
    $Shortcut.Arguments = '\"%INSTALL_DIR:\=\\%\\youtube_downloader.py\"';
    $Shortcut.WorkingDirectory = '%INSTALL_DIR%';
    $Shortcut.Description = 'YouTube Music Premium Downloader';
    if (Test-Path '%INSTALL_DIR:\=\\%\\yt-dlp premium.ico') {
        $Shortcut.IconLocation = '%INSTALL_DIR:\=\\%\\yt-dlp premium.ico';
    }
    $Shortcut.Save();
}"
if exist "%SHORTCUT_PATH%" (
    echo   Desktop shortcut created.
) else (
    echo   Could not create shortcut. Run manually:
    echo     pythonw "%INSTALL_DIR%\youtube_downloader.py"
)

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
echo  Thanks for downloading. -Nutcracker :)
echo  BTC: 15hMZCUhPZs9tMAoVUR3YY4ZLxAKebo3wU
echo.
echo ===========================================================================
echo.
pause
exit /b 0
