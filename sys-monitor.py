#!/usr/bin/env python3
"""
Whimsy hardware telemetry daemon.
Streams real-time CPU, RAM, and GPU stats as single-line JSON to stdout.
"""

import sys
import time
import signal
import subprocess
import shutil
import glob
import os
import json

def cleanup(signum=None, frame=None):
    sys.exit(0)

signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

has_nvidia = bool(shutil.which("nvidia-smi"))

def get_cpu_times():
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
        fields = [float(x) for x in line.strip().split()[1:]]
        idle = fields[3] + fields[4]
        total = sum(fields)
        return idle, total
    except Exception:
        return 0.0, 1.0

def get_mem_info():
    try:
        mem = {}
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    mem[parts[0].strip()] = float(parts[1].strip().split()[0])
        total_kb = mem.get("MemTotal", 1.0)
        avail_kb = mem.get("MemAvailable", 0.0)
        used_kb = max(0.0, total_kb - avail_kb)
        pct = (used_kb / total_kb) * 100.0 if total_kb > 0 else 0.0
        used_gb = round(used_kb / (1024.0 * 1024.0), 1)
        total_gb = round(total_kb / (1024.0 * 1024.0), 1)
        return round(pct, 1), used_gb, total_gb
    except Exception:
        return 0.0, 0.0, 0.0

def get_cpu_temp():
    temps = []
    # Try thermal zones first
    for tz in glob.glob("/sys/class/thermal/thermal_zone*"):
        try:
            with open(os.path.join(tz, "temp"), "r") as f:
                t = float(f.read().strip()) / 1000.0
                if 20.0 <= t <= 115.0:
                    temps.append(t)
        except Exception:
            pass
    if temps:
        return round(max(temps), 0)
    # Fallback to hwmon
    for h in glob.glob("/sys/class/hwmon/hwmon*/temp*_input"):
        try:
            with open(h, "r") as f:
                t = float(f.read().strip()) / 1000.0
                if 20.0 <= t <= 115.0:
                    temps.append(t)
        except Exception:
            pass
    return round(max(temps), 0) if temps else 0.0

def get_gpu_info():
    if not has_nvidia:
        return {"avail": False, "util": 0.0, "temp": 0.0, "mem_used": 0.0, "mem_total": 0.0, "mem_pct": 0.0}
    try:
        res = subprocess.run(
            [
                "nvidia-smi",
                "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
                "--format=csv,noheader,nounits"
            ],
            capture_output=True,
            text=True,
            timeout=0.8
        )
        if res.returncode == 0 and res.stdout.strip():
            parts = [p.strip() for p in res.stdout.strip().split(",")]
            util = float(parts[0])
            temp = float(parts[1])
            mem_used_mb = float(parts[2])
            mem_total_mb = float(parts[3])
            mem_pct = (mem_used_mb / mem_total_mb * 100.0) if mem_total_mb > 0 else 0.0
            return {
                "avail": True,
                "util": round(util, 1),
                "temp": round(temp, 0),
                "mem_used": round(mem_used_mb / 1024.0, 1),
                "mem_total": round(mem_total_mb / 1024.0, 1),
                "mem_pct": round(mem_pct, 1)
            }
    except Exception:
        pass
    return {"avail": False, "util": 0.0, "temp": 0.0, "mem_used": 0.0, "mem_total": 0.0, "mem_pct": 0.0}

def main():
    prev_idle, prev_total = get_cpu_times()
    gpu_counter = 0
    cached_gpu = get_gpu_info()

    while True:
        time.sleep(1.0)
        curr_idle, curr_total = get_cpu_times()
        idle_delta = curr_idle - prev_idle
        total_delta = curr_total - prev_total
        prev_idle, prev_total = curr_idle, curr_total

        cpu_pct = 0.0
        if total_delta > 0:
            cpu_pct = max(0.0, min(100.0, 100.0 * (1.0 - (idle_delta / total_delta))))

        ram_pct, ram_used, ram_total = get_mem_info()
        cpu_temp = get_cpu_temp()

        # Query GPU every 1s (nvidia-smi is fast enough)
        gpu_counter += 1
        if gpu_counter >= 1:
            gpu_counter = 0
            cached_gpu = get_gpu_info()

        data = {
            "cpu": {
                "pct": round(cpu_pct, 1),
                "temp": cpu_temp
            },
            "ram": {
                "pct": ram_pct,
                "used": ram_used,
                "total": ram_total
            },
            "gpu": cached_gpu
        }

        try:
            line = json.dumps(data)
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, IOError):
            break

if __name__ == "__main__":
    main()
