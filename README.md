# YT-DLP Premium Downloader for Windows

A Windows port of the macOS YouTube Music downloader. Downloads music from **YouTube Music** at up to **256kbps AAC (.m4a)** when a YouTube Music **Premium** account and cookies are provided, and automatically falls back to a high-quality **AIFF** conversion when they are not.

## Requirements

- **Windows 10 or 11** (64-bit)
- A **YouTube Music Premium** account - only needed for HQ 256kbps downloads
- **Chrome or Firefox** with a cookie-export extension (only for Premium users)

Everything else - **Python 3.12+, ffmpeg, Node.js, yt-dlp and rustypipe-botguard** - is installed automatically by the installer.

## What's in the download

```
install.bat                       ← run this to install
youtube_downloader.py             ← the app (copied into the install folder)
uninstall.bat                     ← shipped copy; the real uninstaller is copied into the install folder
YT-DLP_Premium.ico                ← app icon
rustypipe-botguard-v0.1.2-*.zip   ← bot-protection solver (extracted during install)
config.json.template              ← reference config
README.md
```

## Installation

1. Download and unzip the release folder
2. **Double-click `install.bat`**
3. Enter a folder name (default: `YouTubeDownloader`) - it is created inside your user folder. **Avoid spaces in the name.**
4. The installer does everything automatically:
   - Checks for Python 3.12+ and installs it via winget if missing
   - Installs **ffmpeg** and **Node.js** via winget if missing
   - Installs **yt-dlp** and **yt-dlp-get-pot-rustypipe** (with automatic retries)
   - Extracts **rustypipe-botguard** (required to pass YouTube's bot protection)
   - Creates `config.json`, a **desktop shortcut** and a copy of the **uninstaller**
5. (Premium users only) The installer offers to open the cookie extension page. Install [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc), log into YouTube Music and export `cookies.txt` into the app folder - or do this later via the "Get Cookie Extension" button in the app.
6. Launch the app from the desktop shortcut.

Notes:

- Re-running the installer with the **same folder name** simply re-copies the files - no duplicates, no extra folders.
- If an install step fails, just re-run `install.bat` and enter the **same** folder name.
- After installing, you can safely delete the unzipped folder you ran the installer from. The installed folder is self-contained and includes the uninstaller.

## Usage

### Single Track
1. Launch the app
2. Keep **Single Track** mode selected
3. Paste a `music.youtube.com` URL - only music.youtube.com links are accepted (`www.youtube.com` links are rejected)
4. Choose a save folder (must be inside the `yt-dlp` folder, or use **Create New**)
5. Click **Download**

### Playlist
1. Open your YouTube Music playlist in Chrome and scroll to the bottom so every track is loaded
2. Press **F12** → **Console** tab
3. In the app click **"? How to get URLs"**, then **Copy Script**, and paste it into the Console (type `allow pasting` first if prompted)
4. Press Enter - copy all returned URLs into a plain `.txt` file, one per line
5. In the app, switch to **Playlist** mode, select the file and choose a save folder
6. Click **Download** - tracks are processed one by one with a small delay between them

Notes:

- Only lines containing `music.youtube.` **and** `list=PL` are used.
- **Albums are not supported** - album links (`list=OLAK...`) are rejected.
- Your playlist must be **non-private**, and you should copy the links from **inside** the playlist page.

### Cookies & HQ 256kbps
- Cookies are **only required for YouTube Music Premium** subscribers who want the HQ 256kbps (format 141) version. Without cookies the app downloads the AIFF fallback instead.
- Click **"? How to use cookies"** in the app for step-by-step instructions (works with Chrome and Firefox).
- Cookies expire regularly - re-export `cookies.txt` roughly every 24 hours.

### Cancel a Download
- Click the **Cancel** button - the current download stops and any remaining playlist tracks are skipped.

### Output Structure

```
%USERPROFILE%\YouTubeDownloader\
├── youtube_downloader.py      ← the app itself
├── YT-DLP_Premium.ico         ← icon used by the shortcut
├── uninstall.bat              ← run this to remove everything
├── config.json                ← app settings
├── rustypipe-botguard.exe     ← bot-protection solver
├── cookies.txt                ← your exported cookies (Premium only)
├── download_log_file.txt      ← download log (viewable in the app)
└── yt-dlp\
    └── [your music folder]\
        ├── [HQ-256k]\         ← 256kbps AAC .m4a (requires cookies)
        └── [Fallback-AIFF]\   ← AIFF with cover art (no cookies needed)
```

## Uninstall

Run `uninstall.bat` **from inside the installed folder**:

1. Removes yt-dlp and yt-dlp-get-pot-rustypipe
2. Removes ffmpeg (via winget)
3. Asks whether to also remove Python and the Python Launcher (recommended if nothing else uses them)
4. Removes the desktop shortcut and the entire app folder

## Troubleshooting

| Problem | Solution |
|---|---|
| Install failed at the yt-dlp / rustypipe step | Re-run `install.bat` with the **same folder name** (files are simply re-copied) |
| "yt-dlp not found" | Re-run `install.bat`, or run `python -m pip install -U "yt-dlp[default]"` |
| Downloads only produce AIFF | Cookies missing or expired - re-export `cookies.txt` (Premium only) |
| Single track rejected as unsupported | The link must be from `music.youtube.com`, not `www.youtube.com` |
| Playlist says "No URLs" | Every line must contain `list=PL` and `music.youtube.`; albums (`list=OLAK...`) are not supported; the playlist must be non-private |
| ffmpeg not found | Re-run `install.bat`, or run `winget install --id Gyan.FFmpeg` |
| Node.js error | Re-run `install.bat` |
| rustypipe-botguard error | Make sure `rustypipe-botguard.exe` is in the app folder (re-run the installer) |
| Shortcut doesn't launch | The folder name probably contains spaces - reinstall with a name without spaces |

## Notes

- Cookies need to be re-exported roughly every 24 hours.
- Folder names with spaces are not supported (the desktop shortcut needs a path without spaces).
- The app window stays responsive during downloads - you can view the log at any time.
- ffmpeg and Node.js are installed system-wide via winget; everything else lives in the app folder.
- All heavy processing (yt-dlp, ffmpeg) runs in hidden background processes.

## Credits

- Original macOS version by **Nutcracker**
- Windows port uses [yt-dlp](https://github.com/yt-dlp/yt-dlp), [rustypipe-botguard](https://codeberg.org/ThetaDev/rustypipe-botguard), and [ffmpeg](https://ffmpeg.org/)

## Support

BTC: `15hMZCUhPZs9tMAoVUR3YY4ZLxAKebo3wU`
