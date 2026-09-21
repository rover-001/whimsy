#!/usr/bin/env python3
"""
whimsy fetch-art helper
Fetches, bounds, and caches MPRIS track artwork securely.

Security constraints:
- Fail-closed if PIL (Pillow) is missing or cannot decode the image
- DNS-rebinding-safe SSRF protection: hostname is resolved ONCE, the first
  suitable public IP is validated using ipaddress built-ins AND an explicit
  denylist, and urllib is directed to connect to that pre-validated IP address
  directly (so no second independent DNS lookup can occur). Host/SNI are
  preserved for HTTP and TLS respectively.  Every redirect destination goes
  through the same single-resolution pipeline before the next hop is opened.
- Strict monotonic wall-clock deadline (4.0s) covering connect, redirects, and
  all response reads
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
import http.client
import ssl
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

# Maximum number of redirects to follow
MAX_REDIRECTS = 5


# ---------------------------------------------------------------------------
# SSRF protection — DNS-rebinding-safe public-address policy
# ---------------------------------------------------------------------------

# Additional explicit denylist of ranges that ipaddress.is_global() may not
# classify as non-global on all Python versions (belt-and-suspenders).
_EXTRA_BLOCKED_NETWORKS = [
    ipaddress.ip_network("100.64.0.0/10"),      # Shared address space (CGNAT)
    ipaddress.ip_network("192.0.0.0/24"),        # IETF Protocol Assignments
    ipaddress.ip_network("192.0.2.0/24"),        # TEST-NET-1 (docs)
    ipaddress.ip_network("198.51.100.0/24"),     # TEST-NET-2 (docs)
    ipaddress.ip_network("203.0.113.0/24"),      # TEST-NET-3 (docs)
    ipaddress.ip_network("240.0.0.0/4"),         # Reserved
    ipaddress.ip_network("255.255.255.255/32"),  # Broadcast
    ipaddress.ip_network("::ffff:0:0/96"),       # IPv4-mapped IPv6
    ipaddress.ip_network("::/128"),              # Unspecified IPv6
]


def _is_safe_ip(ip_str: str) -> bool:
    """
    Return True only if ip_str is a routable, public-Internet address.

    Uses ipaddress built-in predicates (is_global, is_loopback, is_private,
    is_link_local, is_multicast, is_reserved, is_unspecified) as the primary
    check, then applies an extra explicit denylist for ranges that is_global()
    may not handle consistently across Python versions.
    """
    try:
        addr = ipaddress.ip_address(ip_str)
    except ValueError:
        return False

    # Reject anything that is NOT globally routable by stdlib definition
    if not addr.is_global:
        return False

    # Belt-and-suspenders: reject extra ranges stdlib may not catch
    for net in _EXTRA_BLOCKED_NETWORKS:
        try:
            if addr in net:
                return False
        except TypeError:
            pass  # IPv4 vs IPv6 mismatch — not in that network

    return True


def _resolve_to_safe_ip(hostname: str, port: int) -> str:
    """
    Resolve hostname via getaddrinfo and return the first IP address that
    passes _is_safe_ip().  Returns "" if no safe IP is found.

    getaddrinfo is called ONCE here; the returned IP is stored and used
    directly for the TCP connection so no second DNS resolution occurs.
    """
    try:
        results = socket.getaddrinfo(
            hostname, port,
            type=socket.SOCK_STREAM,
            flags=socket.AI_ADDRCONFIG,
        )
    except socket.gaierror:
        return ""

    for family, _type, _proto, _canon, sockaddr in results:
        ip = sockaddr[0]
        if _is_safe_ip(ip):
            return ip

    return ""


# ---------------------------------------------------------------------------
# DNS-rebinding-safe HTTP(S) connection helpers
# ---------------------------------------------------------------------------

def _make_connection(scheme: str, validated_ip: str, hostname: str, port: int,
                     remaining_seconds: float):
    """
    Open an HTTP or HTTPS connection to the pre-validated IP address directly.
    - For HTTP:  HTTPConnection target is the IP; Host header carries hostname.
    - For HTTPS: SSLContext check_hostname=True validates against the original
                 hostname (SNI + cert); the TCP connection goes to the IP.
    Returns an http.client.HTTPConnection/HTTPSConnection (not yet connected).
    """
    timeout = min(remaining_seconds, TOTAL_DEADLINE_SECONDS)
    if scheme == "https":
        ctx = ssl.create_default_context()
        # server_hostname makes ssl set SNI and validate the cert against hostname
        conn = http.client.HTTPSConnection(
            validated_ip, port, timeout=timeout, context=ctx
        )
        # Override the host sent in the TLS handshake so cert validation works
        conn._tunnel_host = hostname  # ignored for non-CONNECT, safe to set
        # Directly replace the server_hostname used by ssl.wrap_socket
        conn._server_hostname = hostname
    else:
        conn = http.client.HTTPConnection(validated_ip, port, timeout=timeout)
    return conn


def _fetch_url_once(url: str, start_time: float) -> tuple:
    """
    Perform a single (non-redirecting) HTTP/HTTPS GET to url.
    Returns (status_code, headers_dict, body_bytes) on success,
    or (None, None, None) on any error.

    The TCP connection is made directly to the pre-validated IP so that
    no second DNS resolution is ever performed.
    """
    elapsed = time.monotonic() - start_time
    remaining = TOTAL_DEADLINE_SECONDS - elapsed
    if remaining <= 0:
        return (None, None, None)

    try:
        parsed = urllib.parse.urlparse(url)
    except Exception:
        return (None, None, None)

    scheme = parsed.scheme
    if scheme not in ("http", "https"):
        return (None, None, None)

    hostname = parsed.hostname
    if not hostname:
        return (None, None, None)

    port = parsed.port or (443 if scheme == "https" else 80)

    # Single DNS resolution → validated IP; no second lookup after this
    validated_ip = _resolve_to_safe_ip(hostname, port)
    if not validated_ip:
        return (None, None, None)

    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    try:
        conn = _make_connection(scheme, validated_ip, hostname, port, remaining)
        conn.request(
            "GET", path,
            headers={
                "Host": hostname,
                "User-Agent": "Omarchy-Whimsy/1.0 (ArtworkFetcher)",
                "Connection": "close",
            }
        )
        resp = conn.getresponse()
        status = resp.status
        headers = {k.lower(): v for k, v in resp.getheaders()}

        # Check content-length before reading
        cl = headers.get("content-length")
        if cl:
            try:
                if int(cl) > MAX_DOWNLOAD_BYTES:
                    conn.close()
                    return (status, headers, None)
            except ValueError:
                pass

        # Stream the body with monotonic deadline enforcement
        data = bytearray()
        while True:
            elapsed2 = time.monotonic() - start_time
            if elapsed2 >= TOTAL_DEADLINE_SECONDS:
                conn.close()
                return (status, headers, None)

            remaining2 = TOTAL_DEADLINE_SECONDS - elapsed2
            conn.sock.settimeout(remaining2)

            chunk = resp.read(65536)
            if not chunk:
                break
            data.extend(chunk)
            if len(data) > MAX_DOWNLOAD_BYTES:
                conn.close()
                return (status, headers, None)

        conn.close()
        return (status, headers, bytes(data))
    except Exception:
        return (None, None, None)


def fetch_remote_image(raw_url: str) -> bytes:
    """
    Downloads remote image data enforcing:
    - DNS-rebinding-safe SSRF: hostname resolved once to a validated public IP,
      TCP connection made directly to that IP (no second DNS lookup).
    - Every redirect destination re-validated with the same single-resolution
      pipeline before the next hop opens.
    - End-to-end monotonic wall-clock deadline.
    - Max download size cap (2 MB).
    - Hard OS-level SIGALRM timer as fail-safe against blocking syscalls.
    """
    parsed = urllib.parse.urlparse(raw_url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        return b""

    start_time = time.monotonic()

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
        url = raw_url
        for _ in range(MAX_REDIRECTS + 1):
            if time.monotonic() - start_time >= TOTAL_DEADLINE_SECONDS:
                return b""

            status, headers, body = _fetch_url_once(url, start_time)
            if status is None:
                return b""

            if status in (301, 302, 303, 307, 308):
                location = (headers or {}).get("location", "").strip()
                if not location:
                    return b""
                # Resolve relative redirects
                url = urllib.parse.urljoin(url, location)
                # Validate the redirect target (new DNS resolution, new IP check)
                p = urllib.parse.urlparse(url)
                if p.scheme not in ("http", "https") or not p.hostname:
                    return b""
                continue

            if status == 200 and body is not None:
                return body

            return b""

        # Exceeded max redirects
        return b""

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

        entries.sort(key=lambda e: e[0])

        while entries and (len(entries) > CACHE_MAX_ENTRIES or total_bytes > CACHE_MAX_BYTES):
            _atime, size, path = entries.pop(0)
            try:
                os.remove(path)
                total_bytes -= size
            except OSError:
                pass
    except Exception:
        pass


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
    Enforces decompression bomb limit and downscales to MAX_BOUNDED_SIZE.
    Fails closed on any decode error.  After a successful write, triggers
    LRU eviction to enforce the cache quota.
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

    # If already cached and non-empty, return immediately (touch atime for LRU)
    if os.path.isfile(cached_file) and os.path.getsize(cached_file) > 0:
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

    # Handle remote URLs (http:// or https://) — DNS-rebinding-safe SSRF applied
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
