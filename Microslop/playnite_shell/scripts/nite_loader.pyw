import os
import io
import sys
import json
import time
import threading
import subprocess
import ctypes
from ctypes import wintypes
from pathlib import Path

try:
    import psutil
    psutil_enabled = True
except ImportError:
    psutil_enabled = False

try:
    from winotify import Notification, audio
    notify_enabled = True
except ImportError:
    notify_enabled = False

class Playnite:
    def __init__(self, app_path: Path | str | None = None, disable_notify: bool = False, disable_explorer: bool = False):

        self.disable_notify = disable_notify
        self.disable_explorer = disable_explorer

        # Fail safe if psutil and notify not installed.
        self.psutil_enabled = psutil_enabled
        self.notify_enabled = notify_enabled

        pip_install_reminder = r'If you installed Python under "C:\Program Files", then you should run `pip install <package>` in Terminal as Admin.'
        if not self.psutil_enabled:
            self.warn("psutil not available, Playnite ready detection disabled. run `pip install psutil`")
            self.info(pip_install_reminder)
        if not self.notify_enabled:
            self.warn("winotify not available, notifications disabled. run `pip install winotify`.", silent=True)
            self.info(pip_install_reminder)

        self.ROOT = Path(__file__).resolve().parents[1]

        self.app_name = "Playnite.FullscreenApp.exe"
        self.app = self._resolve_path(app_path)

        self.mpv = self.ROOT / "bin/mpv/mpv.exe"
        
        if not self.app.exists():
            self.error(f"Missing Playnite launcher: '{self.app}'", fatal=True)
        
        if not self.mpv.exists():
            self.error(f"Missing mpv: '{self.mpv}'", fatal=True)

        self.splash_settings()

        return

    def _resolve_path(self, value: Path | str | None) -> Path:
        # explicit fallback to LOCALAPPDATA; final fallback to user home
        if value is None:
            base = os.environ.get('LOCALAPPDATA') or Path.home()
            return Path(base) / "Playnite" / self.app_name

        if isinstance(value, Path):
            return value / self.app_name

        # value is str: expand env vars and ~, then convert
        expanded = os.path.expandvars(os.path.expanduser(value))
        return Path(expanded) / self.app_name

    def splash_settings(self, enabled: bool = False, video: str = "splash.mp4", pause_at: int = 3, screen: int = 0):    

        video_path = self.ROOT / "splashscreens" / video

        self.splash_enabled = enabled
        self.splash_screen = screen
        self.splash_pause_at = pause_at
        self.splash_video = video_path

        if not video_path.exists() and enabled:
            self.warn(f"Missing Splash video: '{video_path}'.")
            self.splash_enabled = False

        return
    
    def _focus_guard(self, duration: int = 30, interval: float = 0.5):
        """Keep Playnite in focus for a set duration after launch."""
        user32 = ctypes.windll.user32
        deadline = time.time() + duration
        
        while time.time() < deadline:
            time.sleep(interval)
            
            # Find Playnite's window handle
            playnite_hwnd = None
            def find_window(hwnd, _):
                nonlocal playnite_hwnd
                if not user32.IsWindowVisible(hwnd):
                    return True
                pid = wintypes.DWORD()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                for proc in psutil.process_iter(['name', 'pid']):
                    if proc.info['name'] == self.app_name:
                        if pid.value == proc.info['pid']:
                            playnite_hwnd = hwnd
                            return False
                return True
            
            WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
            user32.EnumWindows(WNDENUMPROC(find_window), 0)
            
            if playnite_hwnd:
                foreground = user32.GetForegroundWindow()
                if foreground != playnite_hwnd:
                    user32.SetForegroundWindow(playnite_hwnd)

    def launch(self, delay_playnite: int | None = None):
        def start_playnite(delay):
            if delay is not None:
                time.sleep(delay)
            subprocess.Popen([self.app, "--hidesplashscreen"])

        ipc_pipe = r'\\.\pipe\mpvsocket'

        if self.splash_enabled:
            splash_process = subprocess.Popen([
                self.mpv,
                "--fs",
                f"--screen={self.splash_screen}",
                "--ontop",
                "--no-border",
                "--no-terminal",
                f"--input-ipc-server={ipc_pipe}",
                self.splash_video
            ])
            time.sleep(1) # Wait for mpv to initialise

        threading.Thread(target=start_playnite, args=(delay_playnite,)).start()
        
        if not self.disable_explorer:
            subprocess.Popen(["explorer.exe"])

        if self.splash_enabled:
            with io.TextIOWrapper(io.FileIO(ipc_pipe, "r+b"), line_buffering=True) as pipe:

                # Poll playback position until we hit pause point
                while True:
                    if splash_process.poll() is not None:
                        break

                    response = self._mpv_send_command(pipe, ["get_property", "time-pos"])
                    if response and "data" in response:
                        if response["data"] >= self.splash_pause_at:
                            if not self._is_playnite_ready():
                                self._mpv_send_command(pipe, ["set_property", "pause", True])
                                print(f"Paused at {response['data']:.2f}s, waiting for Playnite...")
                                self.wait_for_playnite()
                                print("Playnite ready, resuming...")
                                self._mpv_send_command(pipe, ["set_property", "pause", False])
                            break
                    time.sleep(0.1)

            splash_process.wait() # Wait for mpv to finish
    
    def _mpv_send_command(self, pipe, command):
        try:
            payload = json.dumps({"command": command}) + "\n"
            pipe.write(payload)
            pipe.flush()
            response = pipe.readline()
            return json.loads(response) if response else None
        except OSError:
            return None

    def wait_for_playnite(self):
        while not self._is_playnite_ready():
            time.sleep(0.5)

    def _is_playnite_ready(self):
        # Fall back to basic process check if psutil unavailable
        if not self.psutil_enabled:
            for proc in os.popen('tasklist').readlines():
                if self.app_name.lower() in proc.lower():
                    return True
            return False

        user32 = ctypes.windll.user32
        result = {'ready': False}
        
        def enum_callback(hwnd, _):
            if not user32.IsWindowVisible(hwnd):
                return True
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            for proc in psutil.process_iter(['name', 'pid']):
                if proc.info['name'] == self.app_name:
                    if pid.value == proc.info['pid']:
                        result['ready'] = True
                        return False
            return True
        
        WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
        user32.EnumWindows(WNDENUMPROC(enum_callback), 0)
        return result['ready']

    def notify(self, title, msg, is_error=False):

        toast = Notification(
            app_id="Nite Loader",
            title=title,
            msg=msg,
            duration="short",
            icon=self.ROOT / "icon.png"
        )
        if is_error:
            toast.set_audio(audio.Default, loop=False)
        toast.show()

    def info(self, msg: str):
        self._logger(msg, silent=True)
        return
    
    def warn(self, msg: str, silent: bool = False):
        self._logger(msg, log_type="warn",silent=silent)
        return
    
    def error(self, msg: str, fatal: bool = False, silent: bool = False):
        self._logger(msg, log_type="error", silent=silent)

        if fatal:
            sys.exit(1)

    def _logger(self, message: str, log_type: str = "info", silent: bool = False):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

        is_error = True if log_type == "error" else False

        log_entry = f"[{timestamp}] [{log_type.upper():<5}] {message}\n"

        log_path = self.ROOT / "logs" / "nite_loader.log"
        log_path.parent.mkdir(exist_ok=True)

        with open(log_path, "a") as f:
            f.write(log_entry)

        if not silent and not self.disable_notify:
            log_type = "warning" if log_type == "warn" else log_type
            self.notify(f"{log_type.upper()}", f"{message}\nSee logs for details.", is_error=is_error)

playnite = Playnite(disable_explorer=True)
playnite.splash_settings(
    #enabled=True,
    #video="XBox360.mp4",
    #pause_at=6,
    #screen=0
)
playnite.launch()
