
"""
YouTube Downloader for Windows
Port of YT-DLP Premium Downloader (macOS) by Nutcracker

A GUI application for YouTube Music Premium users to download
high-quality audio (256kbps AAC .m4a or AIFF fallback).
"""

# ============================================================================
# TESTING CHECKLIST  (tick when verified)
# ============================================================================
#
# MODE SWITCHING:
# [ ] Single track radio → switches mode, browse btn disabled, url entry cleared
# [ ] Playlist radio → switches mode, browse btn enabled
# [ ] Mode switching mid-download: radio buttons NOT disabled — potential bug
#
# URL/FILE INPUT:
# [ ] Single track + empty field → "Missing URL" popup
# [ ] Single track + file path → error with "switch to Playlist mode" hint
# [ ] Single track + web URL → accepted (both http/https)
# [ ] Playlist + empty field → "Missing file" popup
# [ ] Playlist + web URL → error with "? How to get URLs" hint
# [ ] Playlist + non-existent file path → "File not found" popup
# [ ] Playlist + existing .txt with valid playlist URLs → downloads
# [ ] Playlist + existing .txt with 0 valid URLs → warning + "? How to get URLs"
# [ ] Paste button → pastes clipboard content into URL field
# [ ] Browse File button (playlist mode) → file dialog opens, path inserted
# [ ] Browse File button (single mode) → disabled
#
# SAVE LOCATION:
# [ ] No folder selected → "Missing folder" popup
# [ ] Browse inside yt-dlp/ → folder path set
# [ ] Browse outside yt-dlp/ → error "OR: Use Create New"
# [ ] Browse greyed out when yt-dlp/ missing or empty
# [ ] Create New → creates subfolder inside yt-dlp/, path set, browse re-enabled
# [ ] Download to existing folder with pre-existing file → yt-dlp skips, no overwrite
# [ ] Entering a non-existent folder path → auto-created
#
# COOKIES:
# [ ] Cookies field empty → HQ step skipped, goes to AIFF fallback
# [ ] Valid cookies → HQ 141 attempted
# [ ] Invalid cookies → HQ fails (error logged), falls back to AIFF
# [ ] Browse cookies → file dialog opens
# [ ] Get Cookie Extension → opens Chrome Web Store page
#
# DOWNLOAD (HQ 141 PATH):
# [ ] Cookies present + HQ available → 141 .m4a downloaded with metadata/cover
# [ ] HQ downloaded → progress bar pulses, stops on completion
# [ ] HQ downloaded → "Download Complete" popup with title
#
# DOWNLOAD (AIFF FALLBACK PATH):
# [ ] No cookies / HQ fails → WAV downloaded, thumbnail written
# [ ] ffmpeg converts WAV+JPG → AIFF with cover art + ID3v2 tags
# [ ] WAV and JPG cleaned up after conversion
# [ ] AIFF conversion failure → error popup, temp files removed
#
# CANCEL:
# [ ] Cancel during idle → no-op (button disabled, nothing happens)
# [ ] Cancel during HQ download → process tree killed, "Cancelled" message
# [ ] Cancel during fallback download → same as above
# [ ] Cancel during ffmpeg conversion → ffmpeg killed, "Cancelled" message
# [ ] Rapid double-click Cancel → second call safe (process already None)
# [ ] Cancel mid-playlist → remaining tracks skipped, "Cancelled at track N" message
#
# PLAYLIST:
# [ ] Single valid URL → downloads one track
# [ ] Multiple URLs → all processed sequentially
# [ ] Mix of valid + invalid URLs → valid succeed, invalid logged as errors
# [ ] Delay between tracks (9-16s) → logged as "[Info] Waiting Xs..."
# [ ] Cancel mid-playlist → stops after current track
# [ ] One track fails → continues to next, error counted
#
# UI DURING DOWNLOAD:
# [ ] Download button → disabled
# [ ] Cancel button → enabled
# [ ] URL entry → disabled
# [ ] Browse File button → disabled
# [ ] Browse Folder button → disabled
# [ ] Progress bar → pulsing (indeterminate)
# [ ] Status shows current track/progress
# [ ] After completion: buttons restored, progress stops, status = "Ready."
# [ ] Mode radio buttons NOT disabled — could switch mode mid-download (bug)
#
# LOGS:
# [ ] View Log button → opens log file
# [ ] Log contains all [Task]/[Success]/[ERROR] entries per track
# [ ] Log contains ffmpeg output on fallback
#
# MISC:
# [ ] Open Folder → opens file explorer at save location
# [ ] ? How to get URLs → instructions window with steps + script
# [ ] Copy Script → F12 script copied to clipboard
# [ ] --remote-components ejs:github works on first run (downloads solver)
#
# ============================================================================
# IMPLEMENTATION TODOs (priority order)
# ============================================================================
#
# TODO: [P1] install.bat — add Node.js install via winget (required for --js-runtimes node)
# TODO: [P2] install.bat — verify ffmpeg installed into PATH correctly
# TODO: [P3] install.bat — fix Python auto-install when not detected
# TODO: [P4] — create uninstall.bat
#
# ============================================================================
    
import os
import sys
import re
import json
import threading
import subprocess
import time
import random
import shutil
import webbrowser
import queue
from pathlib import Path
from datetime import datetime

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

# ============================================================================
# CONSTANTS
# ============================================================================

APP_NAME = "YouTube Downloader"
VERSION = "1.0.0"

COOKIE_EXTENSION_URL = (
    "https://chromewebstore.google.com/detail/"
    "get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc"
)

F12_SCRIPT = """const allLinks = Array.from(document.querySelectorAll('a'));
const watchLinks = allLinks
  .map(a => a.href)
  .filter(href => href.includes('watch?v='));
const uniqueLinks = [...new Set(watchLinks)];
console.log(uniqueLinks.join('\\n'));"""


# ============================================================================
# URL SANITIZATION  (ported from youtube_downloader.zsh)
# ============================================================================

def sanitize_url(url):
    url = re.sub(r'&list=[^&]*', '', url)
    if 'music.' not in url:
        url = re.sub(r'www\.youtube\.', 'music.youtube.', url)
        if 'music.' not in url:
            url = re.sub(r'youtube\.', 'music.youtube.', url)
    url = re.sub(r'music\.youtube\.co\.[a-z]{2}', 'music.youtube.com', url)
    url = re.sub(r'music\.youtube\.([a-z]{2})([/?]|$)', r'music.youtube.com\2', url)
    if '.com' not in url:
        url = re.sub(r'music\.youtube\.([a-z]{3})([/?]|$)', r'music.youtube.com\1', url)
    return url

# ============================================================================
# CONFIG
# ============================================================================

SCRIPT_DIR = Path(__file__).parent.resolve()

def load_config():
    config_path = SCRIPT_DIR / 'config.json'
    if not config_path.exists():
        config_path = Path.home() / 'YouTubeDownloader' / 'config.json'
    cfg = {
        "install_root": str(SCRIPT_DIR),
        "cookie_file": str(SCRIPT_DIR / "cookies.txt"),
        "rustypipe_bg_bin": str(SCRIPT_DIR / "rustypipe-botguard.exe"),
    }
    if config_path.exists():
        try:
            with open(config_path) as f:
                cfg.update(json.load(f))
        except Exception:
            pass
    return cfg

def save_config(cfg):
    config_path = SCRIPT_DIR / 'config.json'
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w') as f:
        json.dump(cfg, f, indent=2)

# ============================================================================
# DOWNLOAD ENGINE
# ============================================================================

class DownloadEngine:
    """Runs yt-dlp downloads, communicates with GUI via a queue."""

    def __init__(self, config, status_queue):
        self.config = config
        self.queue = status_queue
        self._cancel_event = threading.Event()
        self._process = None
        self._ffmpeg_process = None

        root = Path(config.get('install_root', str(SCRIPT_DIR)))
        self.base_dir = root / 'yt-dlp'
        self.cookie_file = Path(config.get('cookie_file', root / 'cookies.txt'))
        self.log_file_path = root / 'download_log_file.txt'
        self.rustypipe_bin = Path(config.get('rustypipe_bg_bin', root / 'rustypipe-botguard.exe'))
        self.base_dir.mkdir(parents=True, exist_ok=True)

    def cancel(self):
        self._cancel_event.set()
        if self._ffmpeg_process and self._ffmpeg_process.poll() is None:
            try:
                self._ffmpeg_process.terminate()
            except Exception:
                pass
        if self._process and self._process.poll() is None:
            self._kill_process_tree()

    def _kill_process_tree(self):
        try:
            subprocess.run(
                ['taskkill', '/F', '/T', '/PID', str(self._process.pid)],
                capture_output=True, timeout=5,
                startupinfo=self._make_startupinfo(),
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
            )
        except Exception:
            try:
                self._process.terminate()
            except Exception:
                pass

    @property
    def is_cancelled(self):
        return self._cancel_event.is_set()

    def _log(self, msg):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(self.log_file_path, 'a', encoding='utf-8') as f:
            f.write(f"[{timestamp}] {msg}\n")

    def _send(self, msg_type, message, **kw):
        self.queue.put({'type': msg_type, 'message': message, **kw})

    def _make_startupinfo(self):
        """Return STARTUPINFO that hides the console window (Windows only)."""
        if sys.platform != 'win32':
            return None
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = 0
        return si

    def _run_subprocess(self, args):
        self._process = subprocess.Popen(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='replace',
            startupinfo=self._make_startupinfo(),
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
        )
        line_queue = queue.Queue()
        def _reader():
            for line in self._process.stdout:
                line_queue.put(line)
            line_queue.put(None)
        reader_thread = threading.Thread(target=_reader, daemon=True)
        reader_thread.start()
        while True:
            if self.is_cancelled:
                self._kill_process_tree()
                break
            try:
                line = line_queue.get(timeout=0.5)
            except queue.Empty:
                if self._process.poll() is not None and line_queue.empty():
                    break
                continue
            if line is None:
                break
            self._log(line.rstrip('\n\r'))
        self._process.wait()
        return self._process.returncode == 0

    def _get_ffmpeg(self):
        ff = shutil.which('ffmpeg')
        if ff:
            return ff
        root = Path(self.config.get('install_root', str(SCRIPT_DIR)))
        candidates = [
            str(root / 'ffmpeg.exe'),
            r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
            r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
            r'C:\ffmpeg\bin\ffmpeg.exe',
        ]
        for c in candidates:
            if Path(c).exists():
                return c
        return 'ffmpeg'

    def _download_track(self, url, hq_dir, fallback_dir):
        # Get title
        try:
            si = self._make_startupinfo()
            r = subprocess.run(
                ['yt-dlp', '--get-title', '--no-playlist', url],
                capture_output=True, text=True, timeout=30,
                startupinfo=si,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
            )
            title = r.stdout.strip() or "Unknown_Track"
        except Exception:
            title = "Unknown_Track"

        title_safe = re.sub(r'[\\/:*?"<>|]', '_', title)
        self._log(f"[Task] Downloading: {title}")
        self._send('track', f"Downloading: {title}")

        extractor_args = "youtube:player_client=mweb;formats=missing_pot"
        if self.rustypipe_bin and self.rustypipe_bin.exists():
            extractor_args += f";rustypipe_bg_bin={self.rustypipe_bin}"

        # Try HQ (format 141)
        if self.cookie_file.exists() and self.cookie_file.stat().st_size > 0:
            self._log("[Task] Cookies detected. Attempting HQ (141) download.")
            self._send('progress', "Attempting HQ download (format 141)...")
            args = [
                'yt-dlp', '--cookies', str(self.cookie_file),
                '--no-playlist',
                '--extractor-args', extractor_args,
                '--js-runtimes', 'node',
                '--remote-components', 'ejs:github',
                '-f', '141',
                '--add-metadata', '--embed-thumbnail',
                '-o', str(Path(hq_dir) / '%(title)s.%(ext)s'),
                url,
            ]
            ok = self._run_subprocess(args)
            if self.is_cancelled:
                return False, 'cancelled', title
            if ok:
                self._log(f"[Success] Downloaded HQ (141) for {title}.")
                self._send('success', f"Downloaded: {title} (HQ 256kbps)")
                return True, 'hq', title
            self._log(f"[!] HQ (141) download failed for {title}.")
        else:
            self._log("[!] No valid cookies. Skipping HQ attempt.")

        # Fallback: WebM -> WAV -> AIFF
        if self.is_cancelled:
            return False, 'cancelled', title

        self._log(f"[Task] Initiating AIFF fallback for {title}.")
        self._send('progress', f"Downloading audio for {title}...")
        ffmpeg = self._get_ffmpeg()

        args = [
            'yt-dlp', '--ffmpeg-location', ffmpeg,
            '--no-playlist',
            '--js-runtimes', 'node',
            '--remote-components', 'ejs:github',
            '-f', 'bestaudio[ext=webm]',
            '--write-thumbnail', '--convert-thumbnails', 'jpg',
            '-x', '--audio-format', 'wav',
            '-o', str(Path(fallback_dir) / '%(title)s.%(ext)s'),
            url,
        ]
        ok = self._run_subprocess(args)
        if self.is_cancelled:
            return False, 'cancelled', title
        if not ok:
            self._log(f"[ERROR] Fallback download failed for {title}.")
            return False, 'failed', title

        wavs = sorted(Path(fallback_dir).glob('*.wav'))
        jpgs = sorted(Path(fallback_dir).glob('*.jpg'))
        if not wavs:
            self._log("[ERROR] No WAV file found after download.")
            return False, 'failed', title

        if self.is_cancelled:
            return False, 'cancelled', title

        wav = str(wavs[0])
        jpg = str(jpgs[0]) if jpgs else None
        aiff = str(Path(fallback_dir) / f"{title_safe}.aiff")

        self._send('progress', f"Converting to AIFF for {title}...")
        ff_args = (
            [ffmpeg, '-i', wav, '-i', jpg,
             '-map', '0:a', '-map', '1:v',
             '-c:a', 'pcm_s16be', '-c:v', 'mjpeg',
             '-disposition:v', 'attached_pic',
             '-metadata', f'title={title}',
             '-id3v2_version', '3', '-write_id3v2', '1', aiff]
            if jpg and Path(jpg).exists()
            else [ffmpeg, '-i', wav,
                  '-c:a', 'pcm_s16be',
                  '-metadata', f'title={title}',
                  '-id3v2_version', '3', '-write_id3v2', '1', aiff]
        )

        self._ffmpeg_process = subprocess.Popen(
            ff_args,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='replace',
            startupinfo=self._make_startupinfo(),
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0,
        )
        with open(self.log_file_path, 'a', encoding='utf-8') as log:
            for line in self._ffmpeg_process.stdout:
                log.write(line)
        self._ffmpeg_process.wait()

        if self.is_cancelled:
            return False, 'cancelled', title

        if self._ffmpeg_process.returncode != 0:
            self._log(f"[ERROR] AIFF conversion failed for {title}.")
            os.remove(wav)
            if jpg and Path(jpg).exists():
                os.remove(jpg)
            return False, 'failed', title

        os.remove(wav)
        if jpg and Path(jpg).exists():
            os.remove(jpg)
        self._log(f"[Success] Downloaded and converted {title} to AIFF.")
        return True, 'aiff', title

    def _cleanup(self, target, hq_dir, fallback_dir):
        for d in [hq_dir, fallback_dir, target]:
            p = Path(d)
            if p.exists() and not any(p.iterdir()):
                shutil.rmtree(p, ignore_errors=True)
                self._log(f"[Cleanup] Removed empty: {p}")

    def download_single(self, url, target_path):
        target = Path(target_path)
        hq = target / "[HQ-256k]"
        fb = target / "[Fallback-AIFF]"
        target.mkdir(parents=True, exist_ok=True)
        hq.mkdir(exist_ok=True)
        fb.mkdir(exist_ok=True)

        clean = sanitize_url(url)
        self._log(f"[Info] Sanitized URL: {clean}")
        self._send('info', f"Processing: {clean}")

        if self.is_cancelled:
            self._send('cancelled', "Cancelled.")
            self._cleanup(target, hq, fb)
            return

        ok, fmt, title = self._download_track(clean, str(hq), str(fb))
        self._cleanup(target, hq, fb)

        if fmt == 'cancelled':
            self._send('cancelled', f"Cancelled.")
        elif ok:
            self._send('complete', f"Done! {title} ({fmt.upper()})")
        else:
            self._send('error', f"Failed: {title}")

    def download_playlist(self, urls, target_path):
        target = Path(target_path)
        hq = target / "[HQ-256k]"
        fb = target / "[Fallback-AIFF]"
        target.mkdir(parents=True, exist_ok=True)
        hq.mkdir(exist_ok=True)
        fb.mkdir(exist_ok=True)

        total = len(urls)
        success = 0
        failed = 0
        cancelled = False
        self._send('progress', f"Playlist: {total} tracks")

        for i, url in enumerate(urls):
            if self.is_cancelled:
                self._send('cancelled', f"Cancelled at track {i+1}/{total}")
                cancelled = True
                break

            clean = sanitize_url(url)
            self._log(f"[Info] [{i+1}/{total}] {clean}")
            self._send('track', f"[{i+1}/{total}] Processing...")

            ok, fmt, title = self._download_track(clean, str(hq), str(fb))
            if fmt == 'cancelled':
                self._send('cancelled', f"Cancelled at track {i+1}/{total}")
                cancelled = True
                break
            if ok:
                success += 1
            else:
                failed += 1

            if i < total - 1 and not self.is_cancelled:
                delay = random.randint(9, 16)
                self._log(f"[Info] Waiting {delay}s...")
                self._send('progress', f"Waiting {delay}s before next track...")
                for _ in range(delay):
                    if self.is_cancelled:
                        break
                    time.sleep(1)

        self._cleanup(target, hq, fb)
        if not cancelled:
            self._send('complete', f"Done! {success} ok, {failed} failed.")

# ============================================================================
# GUI APPLICATION
# ============================================================================

class Application(tk.Tk):
    PAD = {'padx': 10, 'pady': 4}
    PAD_LR = {'padx': (12, 12)}

    def __init__(self):
        super().__init__()
        self.title(f"{APP_NAME}  {VERSION}")
        self.minsize(640, 520)
        self.resizable(True, True)

        self.config_data = load_config()
        self.status_queue = queue.Queue()
        self.current_engine = None
        self.download_thread = None

        self._setup_style()
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        # Try to set icon
        self._load_icon()

    def _load_icon(self):
        icon_path = Path(__file__).parent / "yt-dlp premium.ico"
        if icon_path.exists():
            try:
                self.iconbitmap(str(icon_path))
            except Exception:
                pass

    def _setup_style(self):
        style = ttk.Style(self)
        try:
            style.theme_use('vista' if sys.platform == 'win32' else 'clam')
        except tk.TclError:
            pass
        style.configure('Title.TLabel', font=('Segoe UI', 16, 'bold'))
        style.configure('Heading.TLabel', font=('Segoe UI', 11))
        style.configure('Status.TLabel', font=('Segoe UI', 10))
        style.configure('Action.TButton', font=('Segoe UI', 12, 'bold'))
        style.configure('Cancel.TButton', font=('Segoe UI', 12))
        style.configure('Small.TButton', font=('Segoe UI', 9))
        style.configure('Red.Horizontal.TProgressbar', foreground='#1a73e8', background='#1a73e8')

    def _build_ui(self):
        # --- Header ---
        header = ttk.Frame(self)
        header.pack(fill='x', **self.PAD_LR, pady=(12, 0))
        ttk.Label(header, text="YouTube Music Premium Downloader",
                  style='Title.TLabel').pack(side='left')
        ttk.Label(header, text=VERSION,
                  font=('Segoe UI', 9)).pack(side='right', anchor='s')

        ttk.Separator(self, orient='horizontal').pack(fill='x', **self.PAD_LR, pady=6)

        body = ttk.Frame(self)
        body.pack(fill='both', expand=True, **self.PAD_LR)

        # --- Mode selection ---
        self.mode_var = tk.StringVar(value='single')
        mode_f = ttk.LabelFrame(body, text="Download Mode", padding=8)
        mode_f.pack(fill='x', pady=(0, 8))
        ttk.Radiobutton(mode_f, text="Single Track", variable=self.mode_var,
                        value='single', command=self._on_mode_change).pack(side='left', padx=(0, 20))
        ttk.Radiobutton(mode_f, text="Playlist (from .txt file)", variable=self.mode_var,
                        value='playlist', command=self._on_mode_change).pack(side='left')
        ttk.Button(mode_f, text="? How to get URLs", style='Small.TButton',
                   command=self._show_url_help).pack(side='right')

        # --- URL / File input ---
        url_f = ttk.LabelFrame(body, text="URL / File", padding=8)
        url_f.pack(fill='x', pady=(0, 8))

        self.url_var = tk.StringVar()
        self.url_entry = ttk.Entry(url_f, textvariable=self.url_var, font=('Segoe UI', 10))
        self.url_entry.pack(side='left', fill='x', expand=True, padx=(0, 6))
        self.browse_btn = ttk.Button(url_f, text="Browse File...", style='Small.TButton',
                                     command=self._browse_file)
        self.browse_btn.pack(side='right')
        ttk.Button(url_f, text="Paste", style='Small.TButton',
                   command=self._paste_url).pack(side='right', padx=(0, 4))

        # --- Save location ---
        folder_f = ttk.LabelFrame(body, text="Save Location", padding=8)
        folder_f.pack(fill='x', pady=(0, 8))

        self.folder_var = tk.StringVar(value='')
        self.folder_entry = ttk.Entry(folder_f, textvariable=self.folder_var,
                                      font=('Segoe UI', 10))
        self.folder_entry.pack(side='left', fill='x', expand=True, padx=(0, 6))
        self.browse_folder_btn = ttk.Button(folder_f, text="Browse...", style='Small.TButton',
                                            command=self._browse_folder)
        self.browse_folder_btn.pack(side='right')
        ttk.Button(folder_f, text="Create New...", style='Small.TButton',
                   command=self._create_folder).pack(side='right', padx=(0, 4))

        # --- Cookies ---
        cooks_f = ttk.LabelFrame(body, text="Cookies (optional – required for HQ 256kbps)",
                                 padding=8)
        cooks_f.pack(fill='x', pady=(0, 8))

        self.cookies_var = tk.StringVar(value=self.config_data.get('cookie_file', ''))
        self.cookies_entry = ttk.Entry(cooks_f, textvariable=self.cookies_var,
                                       font=('Segoe UI', 10))
        self.cookies_entry.pack(side='left', fill='x', expand=True, padx=(0, 6))
        ttk.Button(cooks_f, text="Browse...", style='Small.TButton',
                   command=self._browse_cookies).pack(side='right')
        ttk.Button(cooks_f, text="Get Cookie Extension", style='Small.TButton',
                   command=self._open_cookie_ext).pack(side='right', padx=(0, 4))

        # --- Progress area ---
        prog_f = ttk.LabelFrame(body, text="Download Progress", padding=8)
        prog_f.pack(fill='both', expand=True, pady=(0, 4))

        self.status_var = tk.StringVar(value="Ready.")
        ttk.Label(prog_f, textvariable=self.status_var,
                  style='Status.TLabel', wraplength=580).pack(anchor='w')

        self.progress_var = tk.DoubleVar(value=0.0)
        self.progress_bar = ttk.Progressbar(prog_f, variable=self.progress_var,
                                            maximum=100, mode='determinate')
        self.progress_bar.pack(fill='x', pady=(4, 4))

        self.track_var = tk.StringVar(value="")
        ttk.Label(prog_f, textvariable=self.track_var,
                  font=('Segoe UI', 9), foreground='#555').pack(anchor='w')

        # --- Action buttons ---
        action_f = ttk.Frame(body)
        action_f.pack(fill='x', pady=(4, 6))

        self.download_btn = ttk.Button(action_f, text="▶  Download",
                                       style='Action.TButton',
                                       command=self._start_download)
        self.download_btn.pack(side='left', padx=(0, 8))

        self.cancel_btn = ttk.Button(action_f, text="⏹  Cancel",
                                     style='Cancel.TButton',
                                     command=self._cancel_download, state='disabled')
        self.cancel_btn.pack(side='left')

        ttk.Button(action_f, text="Open Folder", style='Small.TButton',
                   command=self._open_folder).pack(side='right', padx=(0, 4))
        ttk.Button(action_f, text="View Log", style='Small.TButton',
                   command=self._view_log).pack(side='right', padx=(0, 4))

        # Set initial mode
        self._on_mode_change()
        self._update_folder_browse_state()

        # Start polling queue
        self._poll_queue()

    def _on_mode_change(self):
        mode = self.mode_var.get()
        self.url_entry.configure(state='normal')
        self.url_entry.delete(0, 'end')
        if mode == 'single':
            self.browse_btn.configure(state='disabled')
        else:
            self.browse_btn.configure(state='normal')

    def _update_folder_browse_state(self):
        yt_dlp_root = Path(
            self.config_data.get('install_root', str(SCRIPT_DIR))
        ) / 'yt-dlp'
        has_sub = yt_dlp_root.is_dir() and any(
            p.is_dir() for p in yt_dlp_root.iterdir()
        )
        self.browse_folder_btn.configure(state='normal' if has_sub else 'disabled')

    def _paste_url(self):
        try:
            clip = self.clipboard_get()
            self.url_var.set(clip)
        except tk.TclError:
            pass

    def _browse_file(self):
        path = filedialog.askopenfilename(
            title="Select playlist .txt file",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        if path:
            self.url_var.set(path)

    def _browse_folder(self):
        yt_dlp_root = Path(
            self.config_data.get('install_root', str(SCRIPT_DIR))
        ) / 'yt-dlp'
        start = self.folder_var.get() or (str(yt_dlp_root) if yt_dlp_root.is_dir() else None)
        path = filedialog.askdirectory(
            title="Select download folder",
            initialdir=start
        )
        if path:
            if not str(Path(path).resolve()).startswith(str(yt_dlp_root.resolve())):
                messagebox.showerror(
                    "Invalid folder",
                    f"You can only select folders inside:\n{yt_dlp_root}\n\n"
                    "OR: Use 'Create New' to make a new subfolder inside yt-dlp."
                )
                return
            self.folder_var.set(path)

    def _create_folder(self):
        dialog = tk.Toplevel(self)
        dialog.title("New Folder")
        dialog.geometry("360x140")
        dialog.resizable(False, False)
        dialog.transient(self)
        dialog.grab_set()

        ttk.Label(dialog, text="Enter a name for the new folder:",
                  font=('Segoe UI', 10)).pack(pady=(16, 8))

        name_var = tk.StringVar()
        entry = ttk.Entry(dialog, textvariable=name_var, font=('Segoe UI', 12))
        entry.pack(fill='x', padx=16, pady=(0, 12))
        entry.focus_set()

        def confirm():
            name = name_var.get().strip()
            if name:
                base = Path(
                    self.config_data.get('install_root', str(SCRIPT_DIR))
                ) / 'yt-dlp'
                new_dir = base / name
                try:
                    new_dir.mkdir(parents=True, exist_ok=True)
                    self.folder_var.set(str(new_dir))
                    self._update_folder_browse_state()
                    dialog.destroy()
                except Exception as e:
                    messagebox.showerror("Error", f"Could not create folder:\n{e}")
            else:
                messagebox.showwarning("Name required", "Please enter a folder name.")

        def on_enter(event):
            confirm()

        entry.bind('<Return>', on_enter)
        btn_f = ttk.Frame(dialog)
        btn_f.pack(fill='x', padx=16)
        ttk.Button(btn_f, text="Create", command=confirm).pack(side='right', padx=(8, 0))
        ttk.Button(btn_f, text="Cancel", command=dialog.destroy).pack(side='right')

    def _browse_cookies(self):
        path = filedialog.askopenfilename(
            title="Select cookies.txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
        )
        if path:
            self.cookies_var.set(path)
            self.config_data['cookie_file'] = path
            save_config(self.config_data)

    def _open_cookie_ext(self):
        webbrowser.open(COOKIE_EXTENSION_URL)

    def _show_url_help(self):
        win = tk.Toplevel(self)
        win.title("Getting URLs")
        win.geometry("580x480")
        win.resizable(False, False)
        win.transient(self)
        win.grab_set()

        folder_name = Path(self.folder_var.get()).name if self.folder_var.get() else "yt-dlp"

        ttk.Label(win, text="How to get playlist URLs:", font=('Segoe UI', 11, 'bold'),
                  wraplength=540).pack(pady=(14, 4))

        steps = (
            "1. Open your YouTube Music playlist in Chrome\n"
            "2. Scroll to the bottom so all tracks are loaded\n"
            "3. Press F12 \u2192 go to Console tab\n"
            "4. Copy the script below, paste it into the Console, press Enter\n"
            "(4.1 If the pasting fails, type \"allow pasting\", press Enter and paste again)\n"
            "5. Copy all returned URLs into a .txt file (one per line)\n"
            "6. After the last URL, press Enter to add a blank line at the end\n"
            f"7. Save the file (preferably in your {folder_name} folder) as \"URL.txt\" and select it in the app\n"
            "8. For future downloads, just edit the URL.txt file\n"
        )
        ttk.Label(win, text=steps, wraplength=540, justify='left',
                  font=('Segoe UI', 10)).pack(pady=(0, 4))

        ttk.Label(win, text=f"* Click \"Open Folder\" to find the location of {folder_name} folder. *",
                  wraplength=540, justify='left', font=('Segoe UI', 10, 'italic')).pack(pady=(0, 10))

        ttk.Label(win, text="Script to paste in Console:", font=('Segoe UI', 10, 'bold'),
                  wraplength=540).pack(pady=(0, 4))

        frame = ttk.Frame(win)
        frame.pack(fill='both', expand=True, padx=20, pady=(0, 10))

        text = tk.Text(frame, wrap='word', font=('Consolas', 9), height=7,
                       relief='solid', borderwidth=1, bg='#f5f5f5')
        text.insert('1.0', F12_SCRIPT)
        text.configure(state='disabled')
        text.pack(fill='both', expand=True, side='left')

        scroll = ttk.Scrollbar(frame, orient='vertical', command=text.yview)
        scroll.pack(side='right', fill='y')
        text.configure(yscrollcommand=scroll.set)

        btn_f = ttk.Frame(win)
        btn_f.pack(pady=(0, 14))

        def _copy():
            self.clipboard_clear()
            self.clipboard_append(F12_SCRIPT)
            self.update()

        ttk.Button(btn_f, text="Copy Script", command=_copy).pack(side='left', padx=6)
        ttk.Button(btn_f, text="Close", command=win.destroy).pack(side='left', padx=6)

    def _start_download(self):
        mode = self.mode_var.get()
        url_or_file = self.url_var.get().strip()
        folder_path = self.folder_var.get().strip()

        if mode == 'single' and not url_or_file:
            messagebox.showwarning("Missing URL", "Please enter a YouTube Music URL.")
            return

        if mode == 'single' and not (url_or_file.startswith('http://') or url_or_file.startswith('https://')):
            messagebox.showerror(
                "Invalid input",
                "Single track mode only accepts a direct web URL.\n"
                "If you want to download multiple tracks, switch to Playlist mode and select a .txt file with URLs.\n"
                "Find out how to get playlist URLs by clicking the \"? How to get URLs\" button in the top right corner."
            )
            return

        if mode == 'playlist':
            if not url_or_file:
                messagebox.showwarning("Missing file", "Please select a .txt file.")
                return
            if url_or_file.startswith('http://') or url_or_file.startswith('https://'):
                messagebox.showerror(
                    "Invalid input",
                    "Playlist mode does not accept direct URLs.\n"
                    "Please select a .txt file containing playlist URLs.\n"
                    "Click the \"? How to get URLs\" button in the top right corner for help."
                )
                return
            if not Path(url_or_file).exists():
                messagebox.showerror("File not found", f"File does not exist:\n{url_or_file}")
                return

        if not folder_path:
            messagebox.showwarning("Missing folder", "Please select a save location.")
            return

        folder_path_obj = Path(folder_path)
        if not folder_path_obj.exists():
            try:
                folder_path_obj.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                messagebox.showerror("Error", f"Cannot create folder:\n{e}")
                return

        # Save cookies path
        if self.cookies_var.get().strip():
            self.config_data['cookie_file'] = self.cookies_var.get().strip()
            save_config(self.config_data)

        # Set busy state
        self._set_busy(True)
        self.status_var.set("Starting download...")
        self.progress_var.set(0)
        self.track_var.set("")

        # Create engine
        engine = DownloadEngine(self.config_data, self.status_queue)

        if mode == 'single':
            self.download_thread = threading.Thread(
                target=engine.download_single, args=(url_or_file, folder_path),
                daemon=True
            )
        else:
            try:
                with open(url_or_file, 'r', encoding='utf-8') as f:
                    lines = [l.strip() for l in f if l.strip()]
                urls = [l for l in lines if 'list=PL' in l]
                if not urls:
                    messagebox.showwarning(
                        "No URLs",
                        "No playlist URLs (containing 'list=PL') found in the file.\n"
                        "Make sure to follow the \"? How to get URLs\" guide."
                    )
                    engine._log("[ERROR] NO VALID URLS COULD BE DETECTED! MAKE SURE TO FOLLOW \"? How to get URLs\".")
                    self._set_busy(False)
                    self.status_var.set("Ready.")
                    self.progress_var.set(0)
                    return
            except Exception as e:
                messagebox.showerror("Error", f"Could not read file:\n{e}")
                self._set_busy(False)
                return
            self.download_thread = threading.Thread(
                target=engine.download_playlist, args=(urls, folder_path),
                daemon=True
            )

        self.current_engine = engine
        self.download_thread.start()

    def _cancel_download(self):
        if self.current_engine:
            self.current_engine.cancel()
            self.status_var.set("Cancelling...")
            self.cancel_btn.configure(state='disabled')

    def _set_busy(self, busy):
        if busy:
            self.download_btn.configure(state='disabled')
            self.cancel_btn.configure(state='normal')
            self.url_entry.configure(state='disabled')
            self.browse_btn.configure(state='disabled')
            self.browse_folder_btn.configure(state='disabled')
            self.progress_bar.configure(mode='indeterminate')
            self.progress_bar.start(10)
        else:
            self.download_btn.configure(state='normal')
            self.cancel_btn.configure(state='disabled')
            self.url_entry.configure(state='normal')
            if self.mode_var.get() == 'single':
                self.browse_btn.configure(state='disabled')
            else:
                self.browse_btn.configure(state='normal')
            self._update_folder_browse_state()
            self.progress_bar.stop()
            self.progress_bar.configure(mode='determinate')

    def _poll_queue(self):
        try:
            while True:
                msg = self.status_queue.get_nowait()
                self._handle_status(msg)
        except queue.Empty:
            pass
        self.after(100, self._poll_queue)

    def _handle_status(self, msg):
        t = msg.get('type', '')
        text = msg.get('message', '')

        if t == 'progress':
            self.status_var.set(text)
        elif t == 'track':
            self.status_var.set(text)
            self.track_var.set(text)
        elif t == 'success':
            self.status_var.set(text)
            self.track_var.set(text)
        elif t == 'error':
            self.status_var.set(text)
            self.track_var.set(text)
            messagebox.showerror("Error", text)
        elif t == 'complete':
            self.status_var.set(text)
            self.track_var.set(text)
            self.progress_bar.stop()
            self.progress_bar.configure(mode='determinate')
            self.progress_var.set(100)
            self._set_busy(False)
            messagebox.showinfo("Download Complete", text)
        elif t == 'cancelled':
            self.status_var.set(text)
            self.track_var.set(text)
            self.progress_bar.stop()
            self.progress_bar.configure(mode='determinate')
            self._set_busy(False)
            messagebox.showinfo("Cancelled", text)
        elif t == 'info':
            self.status_var.set(text)

    def _open_folder(self):
        folder = self.folder_var.get().strip()
        if folder and Path(folder).exists():
            webbrowser.open(str(Path(folder)))
        else:
            install_root = self.config_data.get('install_root', str(SCRIPT_DIR))
            if Path(install_root).exists():
                webbrowser.open(install_root)
            else:
                messagebox.showinfo("No folder", "No download folder exists yet. Download something first!")

    def _view_log(self):
        log_path = Path(self.config_data.get('install_root', str(SCRIPT_DIR))) / 'download_log_file.txt'
        if not log_path.exists():
            messagebox.showinfo("No log", "No log file found. Download something first!")
            return

        try:
            if sys.platform == 'win32':
                os.startfile(str(log_path))
            else:
                webbrowser.open(str(log_path))
        except Exception:
            try:
                with open(log_path) as f:
                    content = f.read()
            except Exception as e:
                messagebox.showerror("Error", f"Could not read log:\n{e}")
                return

            win = tk.Toplevel(self)
            win.title("Download Log")
            win.geometry("700x500")
            win.transient(self)
            txt = scrolledtext.ScrolledText(win, wrap='word', font=('Consolas', 10))
            txt.pack(fill='both', expand=True)
            txt.insert('1.0', content)
            txt.configure(state='disabled')

    def _on_close(self):
        if self.current_engine and self.download_thread and self.download_thread.is_alive():
            if messagebox.askyesno("Quit?", "A download is in progress. Cancel and quit?"):
                self.current_engine.cancel()
                self.destroy()
        else:
            self.destroy()


# ============================================================================
# ENTRY POINT
# ============================================================================

def main():
    app = Application()
    try:
        app.mainloop()
    except KeyboardInterrupt:
        app.destroy()


if __name__ == '__main__':
    main()
