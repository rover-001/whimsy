#!/usr/bin/env python3
"""
whimsy fetch-art helper
Fetches, bounds, and caches MPRIS track artwork securely.

Security constraints:
- Strict network timeout (4 seconds)
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
import urllib.request
import urllib.parse

try:
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = 5_000_000
    HAVE_PIL = True
except ImportError:
    HAVE_PIL = False

TIMEOUT_SECONDS = 4.0
MAX_DOWNLOAD_BYTES = 2 * 1024 * 1024  # 2 MB cap
MAX_LOCAL_BYTES = 10 * 1024 * 1024     # 10 MB cap
MAX_BOUNDED_SIZE = (512, 512)

def get_cache_dir() -> str:
    cache_dir = os.path.expanduser("~/.cache/omarchy/whimsy/art")
    os.makedirs(cache_dir, exist_ok=True)
    return cache_dir

def process_and_save_image(image_data_or_path, out_file: str) -> bool:
    if not HAVE_PIL:
        # Fallback if PIL not present (rare on Arch/Omarchy)
        if isinstance(image_data_or_path, (bytes, bytearray)):
            tmp = f"{out_file}.tmp.{os.getpid()}"
            with open(tmp, "wb") as f:
                f.write(image_data_or_path)
            os.replace(tmp, out_file)
            return True
        return False

    try:
        if isinstance(image_data_or_path, (bytes, bytearray)):
            img = Image.open(io.BytesIO(image_data_or_path))
        else:
            img = Image.open(image_data_or_path)

        with img:
            # Bound dimensions
            img.thumbnail(MAX_BOUNDED_SIZE, Image.Resampling.LANCZOS)
            tmp_file = f"{out_file}.tmp.{os.getpid()}"
            img.convert("RGBA").save(tmp_file, "PNG")
            os.replace(tmp_file, out_file)
            return True
    except Exception:
        return False

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
        parsed = urllib.parse.urlparse(raw_url)
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            return ""

        req = urllib.request.Request(
            raw_url,
            headers={"User-Agent": "Omarchy-Whimsy/1.0 (ArtworkFetcher)"}
        )

        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as response:
                content_length = response.headers.get("Content-Length")
                if content_length and int(content_length) > MAX_DOWNLOAD_BYTES:
                    return ""

                data = bytearray()
                while True:
                    chunk = response.read(65536)
                    if not chunk:
                        break
                    data.extend(chunk)
                    if len(data) > MAX_DOWNLOAD_BYTES:
                        return ""

                if not data:
                    return ""

                if process_and_save_image(data, cached_file):
                    return f"file://{cached_file}"
        except Exception:
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
