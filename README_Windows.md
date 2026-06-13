# YT-DLP Premium Downloader for Windows

A Windows port of the macOS YouTube Music Premium downloader. Download music in the highest available quality (256kbps AAC .m4a) using your YouTube Music Premium account, with automatic AIFF fallback.

## Requirements

- **Windows 10 or 11** (64-bit)
- **Python 3.8+** installed and in PATH (download from [python.org](https://www.python.org/downloads/))
- **ffmpeg** installed (for AIFF fallback — `winget install ffmpeg` or download from [ffmpeg.org](https://ffmpeg.org/download.html))
- A **YouTube Music Premium** account for HQ downloads
- **Chrome** (recommended) or another browser with cookie export capability

## Installation

1. Download and unzip this repository
2. **Right-click** `install.bat` → **Run as administrator** (recommended) or double-click it
3. Follow the prompts:
   - Choose an installation folder (or press Enter for default)
   - The installer downloads `rustypipe-botguard.exe` (PO token support)
   - Installs Python dependencies: `yt-dlp`, `yt-dlp-get-pot-rustypipe`
   - Creates a desktop shortcut
4. **Export your cookies** — install the [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) Chrome extension, log into YouTube Music, and export `cookies.txt`
5. Place `cookies.txt` in the installation folder
6. Double-click the **YouTube Downloader** desktop shortcut

## Usage

### Single Track
1. Launch the app
2. Select **Single Track** mode
3. Paste your YouTube Music URL
4. Choose or create a save folder
5. Click **Download**

### Playlist
1. Open your YouTube Music playlist in Chrome, scroll to the bottom
2. Press **F12** → **Console** tab
3. Paste the contents of `F12Developer_Tool_Command.txt` and press Enter
4. Copy all returned URLs into a plain `.txt` file (one per line)
5. Launch the app, select **Playlist** mode
6. Select your `.txt` file, choose a save folder
7. Click **Download**

### Cancel a Download
- Click the **Cancel** button in the app window
- Downloads stop within a few seconds

### Output Structure
```
YouTubeDownloader/
├── yt-dlp/
│   └── [folder name]/
│       ├── [HQ-256k]/         ← 256kbps AAC .m4a (needs cookies)
│       └── [Fallback-AIFF]/    ← AIFF with cover art
├── cookies.txt
├── config.json
├── download_log_file.txt
└── rustypipe-botguard.exe
```

## Troubleshooting

| Problem | Solution |
|---|---|
| "yt-dlp not found" | Run `python -m pip install yt-dlp` |
| Downloads only get AIFF | Cookies missing or expired — re-export `cookies.txt` |
| "No valid cookies" | Re-export cookies from Chrome (they expire ~24h) |
| HQ (141) not working | Check with `yt-dlp --cookies cookies.txt -F URL` if format 141 exists |
| Rustypipe-botguard error | Make sure `rustypipe-botguard.exe` is in the install folder |
| ffmpeg not found | Install ffmpeg: `winget install ffmpeg` or download manually |

## Notes
- Cookies need to be re-exported roughly every 24 hours
- Folder names with spaces are not supported
- The app window stays responsive during downloads — you can view the log at any time
- All heavy processing (yt-dlp, ffmpeg) runs in hidden background processes

## Credits
- Original macOS version by **Nutcracker**
- Windows port uses [yt-dlp](https://github.com/yt-dlp/yt-dlp), [rustypipe-botguard](https://codeberg.org/ThetaDev/rustypipe-botguard), and [ffmpeg](https://ffmpeg.org/)

## Support
BTC: `15hMZCUhPZs9tMAoVUR3YY4ZLxAKebo3wU`
