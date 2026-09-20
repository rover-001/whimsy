#!/usr/bin/env python3
"""
whimsy fetch-art helper
Fetches, bounds, and caches MPRIS track artwork securely.

Security constraints:
- Fail-closed if PIL (Pillow) is missing or cannot decode the image
- Strict monotonic wall-clock deadline (4.0s) covering connect, redirects, and all response reads
- Strict response byte cap (2 MB)
- Strict image dimension/pixel bounds via PIL thumbnailing (max 512x512)
- Rejection of decompression bombs (MAX_IMAGE_PIXELS = 5,000,000)
- Atomic disk caching in ~/.cache/omarchy/whimsy/art/
- Outputs ONLY bounded local file:// URLs to stdout
"""

import sys
import os
import hashlib
import io
import time
import signal
import urllib.request
import urllib.parse
import urllib.error

# Mandatory runtime dependency: fail closed immediately if Pillow is missing
try:
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = 5_000_000
except ImportError:
    sys.exit(0)

TOTAL_DEADLINE_SECONDS = 4.0
MAX_DOWNLOAD_BYTES = 2 * 1024 * 1024  # 2 MB cap
MAX_LOCAL_BYTES = 10 * 1024 * 1024     # 10 MB cap
MAX_BOUNDED_SIZE = (512, 512)

def get_cache_dir() -> str:
    cache_dir = os.path.expanduser("~/.cache/omarchy/whimsy/art")
    os.makedirs(cache_dir, exist_ok=True)
    return cache_dir

def process_and_save_image(image_data_or_path, out_file: str) -> bool:
    """
    Decodes and verifies image data using PIL.
    Enforces decompression bomb limit (MAX_IMAGE_PIXELS) and downscales
    to MAX_BOUNDED_SIZE (512x512) before atomically writing as PNG.
    Fails closed (returns False) on any decoding error, decompression bomb,
    or unsupported format. NEVER caches or returns unvalidated raw bytes.
    """
    tmp_file = f"{out_file}.tmp.{os.getpid()}"
    try:
        if isinstance(image_data_or_path, (bytes, bytearray)):
            img = Image.open(io.BytesIO(image_data_or_path))
        else:
            img = Image.open(image_data_or_path)

        with img:
            # Force decode and bound dimensions
            img.thumbnail(MAX_BOUNDED_SIZE, Image.Resampling.LANCZOS)
            img.convert("RGBA").save(tmp_file, "PNG")

        os.replace(tmp_file, out_file)
        return True
    except Exception:
        if os.path.exists(tmp_file):
            try:
                os.remove(tmp_file)
            except OSError:
                pass
        return False

class MonotonicDeadlineRedirectHandler(urllib.request.HTTPRedirectHandler):
    def __init__(self, start_time: float, deadline: float):
        super().__init__()
        self.start_time = start_time
        self.deadline = deadline

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Abort if the total wall-clock deadline has been exceeded
        if time.monotonic() - self.start_time >= self.deadline:
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def fetch_remote_image(raw_url: str) -> bytes:
    """
    Downloads remote image data enforcing:
    - End-to-end monotonic wall-clock deadline (4.0s) spanning connection,
      all redirects, and the entire response read loop.
    - Max download size cap (2 MB).
    - Hard wall-clock timer (signal.setitimer) as failsafe against hanging syscalls.
    """
    parsed = urllib.parse.urlparse(raw_url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        return b""

    start_time = time.monotonic()
    opener = urllib.request.build_opener(
        MonotonicDeadlineRedirectHandler(start_time, TOTAL_DEADLINE_SECONDS)
    )

    req = urllib.request.Request(
        raw_url,
        headers={"User-Agent": "Omarchy-Whimsy/1.0 (ArtworkFetcher)"}
    )

    def _alarm_handler(signum, frame):
        raise TimeoutError("Total monotonic deadline exceeded")

    old_handler = None
    has_timer = hasattr(signal, "setitimer") and hasattr(signal, "SIGALRM")
    if has_timer:
        try:
            old_handler = signal.signal(signal.SIGALRM, _alarm_handler)
            signal.setitimer(signal.ITIMER_REAL, TOTAL_DEADLINE_SECONDS)
        except Exception:
            has_timer = False

    try:
        remaining = TOTAL_DEADLINE_SECONDS - (time.monotonic() - start_time)
        if remaining <= 0:
            return b""

        with opener.open(req, timeout=remaining) as response:
            content_length = response.headers.get("Content-Length")
            if content_length:
                try:
                    if int(content_length) > MAX_DOWNLOAD_BYTES:
                        return b""
                except ValueError:
                    pass

            data = bytearray()
            while True:
                elapsed = time.monotonic() - start_time
                if elapsed >= TOTAL_DEADLINE_SECONDS:
                    return b""

                remaining = TOTAL_DEADLINE_SECONDS - elapsed
                if remaining <= 0:
                    return b""

                # Dynamically clamp socket timeout to remaining deadline to block drip-feed attacks
                try:
                    sock = getattr(response, "fp", None)
                    if sock and hasattr(sock, "raw") and hasattr(sock.raw, "_sock") and sock.raw._sock:
                        sock.raw._sock.settimeout(remaining)
                except Exception:
                    pass

                chunk = response.read(65536)
                if not chunk:
                    break

                data.extend(chunk)
                if len(data) > MAX_DOWNLOAD_BYTES:
                    return b""

            return bytes(data)
    except Exception:
        return b""
    finally:
        if has_timer:
            try:
                signal.setitimer(signal.ITIMER_REAL, 0)
                if old_handler is not None:
                    signal.signal(signal.SIGALRM, old_handler)
            except Exception:
                pass

def resolve_art(raw_url: str) -> str:
    if not raw_url or not isinstance(raw_url, str):
        return ""
    raw_url = raw_url.strip()
    if not raw_url:
        return ""

    cache_dir = get_cache_dir()
    url_hash = hashlib.sha256(raw_url.encode("utf-8")).hexdigest()[:24]
    cached_file = os.path.join(cache_dir, f"{url_hash}.png")

    # If already cached and non-empty, return immediately
    if os.path.isfile(cached_file) and os.path.getsize(cached_file) > 0:
        return f"file://{cached_file}"

    # Handle local files (file:// or /path)
    if raw_url.startswith("file://") or raw_url.startswith("/"):
        if raw_url.startswith("file://"):
            local_path = urllib.parse.unquote(raw_url[7:])
        else:
            local_path = raw_url

        if not os.path.isfile(local_path):
            return ""
        try:
            if os.path.getsize(local_path) > MAX_LOCAL_BYTES:
                return ""
        except OSError:
            return ""

        if process_and_save_image(local_path, cached_file):
            return f"file://{cached_file}"
        return ""

    # Handle remote URLs (http:// or https://)
    if raw_url.startswith("http://") or raw_url.startswith("https://"):
        data = fetch_remote_image(raw_url)
        if data and process_and_save_image(data, cached_file):
            return f"file://{cached_file}"
        return ""

    # Handle data: URIs
    if raw_url.startswith("data:image/"):
        try:
            header, encoded = raw_url.split(",", 1)
            if ";base64" in header:
                import base64
                data = base64.b64decode(encoded)
                if len(data) <= MAX_DOWNLOAD_BYTES and process_and_save_image(data, cached_file):
                    return f"file://{cached_file}"
        except Exception:
            return ""

    return ""

def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    raw_url = sys.argv[1]
    safe_url = resolve_art(raw_url)
    if safe_url:
        sys.stdout.write(safe_url + "\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
