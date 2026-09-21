#!/usr/bin/env python3
"""
whimsy fetch-art helper
Fetches, bounds, and caches MPRIS track artwork securely.

Security constraints:
- Fail-closed if PIL (Pillow) is missing or cannot decode the image
- SSRF protection: all destination IPs (initial URL and every redirect) are validated
  against a public-address policy — loopback, link-local, ULA, private ranges, and
  multicast are all rejected after DNS resolution
- Strict monotonic wall-clock deadline (4.0s) covering connect, redirects, and all
  response reads
- Strict response byte cap (2 MB)
- Strict image dimension/pixel bounds via PIL thumbnailing (max 512x512)
- Rejection of decompression bombs (MAX_IMAGE_PIXELS = 5,000,000)
- Bounded cache: max 200 entries, max 100 MB total; LRU eviction on every write
- Atomic disk caching in ~/.cache/omarchy/whimsy/art/
- Outputs ONLY bounded local file:// URLs to stdout
"""

import sys
import os
import hashlib
import io
import time
import signal
import socket
import ipaddress
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
MAX_DOWNLOAD_BYTES = 2 * 1024 * 1024   # 2 MB cap per download
MAX_LOCAL_BYTES = 10 * 1024 * 1024     # 10 MB cap for local files

MAX_BOUNDED_SIZE = (512, 512)

# Cache quota limits
CACHE_MAX_ENTRIES = 200
CACHE_MAX_BYTES = 100 * 1024 * 1024    # 100 MB total cache ceiling


# ---------------------------------------------------------------------------
# SSRF protection — public-address policy
# ---------------------------------------------------------------------------

# IP network ranges that must never be contacted
_BLOCKED_NETWORKS = [
    ipaddress.ip_network("127.0.0.0/8"),       # Loopback
    ipaddress.ip_network("::1/128"),            # IPv6 loopback
    ipaddress.ip_network("10.0.0.0/8"),         # RFC-1918 private
    ipaddress.ip_network("172.16.0.0/12"),      # RFC-1918 private
    ipaddress.ip_network("192.168.0.0/16"),     # RFC-1918 private
    ipaddress.ip_network("169.254.0.0/16"),     # Link-local (IPv4)
    ipaddress.ip_network("fe80::/10"),          # Link-local (IPv6)
    ipaddress.ip_network("fc00::/7"),           # ULA (IPv6)
    ipaddress.ip_network("0.0.0.0/8"),          # "This" network
    ipaddress.ip_network("100.64.0.0/10"),      # Shared address (CGNAT)
    ipaddress.ip_network("192.0.0.0/24"),       # IETF Protocol Assignments
    ipaddress.ip_network("192.0.2.0/24"),       # TEST-NET-1 (docs)
    ipaddress.ip_network("198.51.100.0/24"),    # TEST-NET-2 (docs)
    ipaddress.ip_network("203.0.113.0/24"),     # TEST-NET-3 (docs)
    ipaddress.ip_network("224.0.0.0/4"),        # IPv4 multicast
    ipaddress.ip_network("240.0.0.0/4"),        # Reserved
    ipaddress.ip_network("255.255.255.255/32"), # Broadcast
    ipaddress.ip_network("ff00::/8"),           # IPv6 multicast
    ipaddress.ip_network("::ffff:0:0/96"),      # IPv4-mapped IPv6
    ipaddress.ip_network("::/128"),             # Unspecified IPv6
]


def _is_public_ip(ip_str: str) -> bool:
    """Return True only if ip_str is a routable public-Internet address."""
    try:
        addr = ipaddress.ip_address(ip_str)
    except ValueError:
        return False
    for net in _BLOCKED_NETWORKS:
        if addr in net:
            return False
    return True


def _hostname_resolves_to_public(hostname: str, port: int = 80) -> bool:
    """
    Resolve hostname via getaddrinfo and confirm that EVERY returned
    IP address is a public (non-private/non-loopback) address.
    Rejects the host if DNS yields zero results or any private address.
    """
    try:
        results = socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)
    except socket.gaierror:
        return False
    if not results:
        return False
    for family, _type, _proto, _canon, sockaddr in results:
        ip = sockaddr[0]
        if not _is_public_ip(ip):
            return False
    return True


def _url_passes_ssrf_check(url: str) -> bool:
    """
    Parse url and ensure scheme is http/https, netloc is present, and
    the host resolves exclusively to public IP addresses.
    """
    try:
        parsed = urllib.parse.urlparse(url)
    except Exception:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    hostname = parsed.hostname
    if not hostname:
        return False
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    return _hostname_resolves_to_public(hostname, port)


# ---------------------------------------------------------------------------
# Cache quota / LRU eviction
# ---------------------------------------------------------------------------

def _evict_cache_if_needed(cache_dir: str) -> None:
    """
    Enforce CACHE_MAX_ENTRIES and CACHE_MAX_BYTES limits with LRU eviction
    (oldest-access-time files removed first).  Called after every new cache
    write so the directory stays bounded.
    """
    try:
        entries = []
        total_bytes = 0
        for name in os.listdir(cache_dir):
            if not name.endswith(".png"):
                continue
            path = os.path.join(cache_dir, name)
            try:
                st = os.stat(path)
                entries.append((st.st_atime, st.st_size, path))
                total_bytes += st.st_size
            except OSError:
                continue

        # Sort ascending by last-access time (least recently used first)
        entries.sort(key=lambda e: e[0])

        while entries and (len(entries) > CACHE_MAX_ENTRIES or total_bytes > CACHE_MAX_BYTES):
            atime, size, path = entries.pop(0)
            try:
                os.remove(path)
                total_bytes -= size
            except OSError:
                pass
    except Exception:
        pass  # Never crash on eviction


# ---------------------------------------------------------------------------
# Image processing
# ---------------------------------------------------------------------------

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
    or unsupported format.  NEVER caches or returns unvalidated raw bytes.
    After a successful write, triggers LRU eviction to enforce cache quota.
    """
    tmp_file = f"{out_file}.tmp.{os.getpid()}"
    try:
        if isinstance(image_data_or_path, (bytes, bytearray)):
            img = Image.open(io.BytesIO(image_data_or_path))
        else:
            img = Image.open(image_data_or_path)

        with img:
            img.thumbnail(MAX_BOUNDED_SIZE, Image.Resampling.LANCZOS)
            img.convert("RGBA").save(tmp_file, "PNG")

        os.replace(tmp_file, out_file)
        _evict_cache_if_needed(os.path.dirname(out_file))
        return True
    except Exception:
        if os.path.exists(tmp_file):
            try:
                os.remove(tmp_file)
            except OSError:
                pass
        return False


# ---------------------------------------------------------------------------
# Remote fetch with monotonic deadline + SSRF-filtered redirect handler
# ---------------------------------------------------------------------------

class _SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    """
    Intercepts every redirect and re-validates the new destination URL against
    the SSRF public-address policy before following it.  Also aborts if the
    monotonic wall-clock deadline has been exceeded.
    """

    def __init__(self, start_time: float, deadline: float):
        super().__init__()
        self.start_time = start_time
        self.deadline = deadline

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Abort if the total wall-clock deadline has been exceeded
        if time.monotonic() - self.start_time >= self.deadline:
            return None
        # Re-validate the redirect target against the public-address policy
        if not _url_passes_ssrf_check(newurl):
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_remote_image(raw_url: str) -> bytes:
    """
    Downloads remote image data enforcing:
    - SSRF check: initial destination must resolve to a public IP address.
    - SSRF check: every redirect destination re-checked by _SafeRedirectHandler.
    - End-to-end monotonic wall-clock deadline (4.0s) spanning connection,
      all redirects, and the entire response read loop.
    - Max download size cap (2 MB).
    - Hard OS-level timer (signal.setitimer) as fail-safe against blocking syscalls.
    """
    # Validate initial URL before opening any connection
    if not _url_passes_ssrf_check(raw_url):
        return b""

    start_time = time.monotonic()
    opener = urllib.request.build_opener(
        _SafeRedirectHandler(start_time, TOTAL_DEADLINE_SECONDS)
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

                # Dynamically clamp socket timeout to remaining deadline
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


# ---------------------------------------------------------------------------
# Main resolver
# ---------------------------------------------------------------------------

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
        # Touch atime for LRU tracking
        try:
            os.utime(cached_file, None)
        except OSError:
            pass
        return f"file://{cached_file}"

    # Handle local files (file:// or /path) — SSRF does not apply to local paths
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

    # Handle remote URLs (http:// or https://) — full SSRF check applied
    if raw_url.startswith("http://") or raw_url.startswith("https://"):
        data = fetch_remote_image(raw_url)
        if data and process_and_save_image(data, cached_file):
            return f"file://{cached_file}"
        return ""

    # Handle data: URIs — no network, no SSRF risk
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
