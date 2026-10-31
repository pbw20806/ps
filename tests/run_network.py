"""Run four real Godot processes against a loopback ENet server."""
import os
import pathlib
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
processes = []
try:
    with tempfile.TemporaryDirectory(prefix="mystery-network-") as tmp:
        for role in range(4):
            env = os.environ.copy()
            for kind in ("DATA", "CONFIG", "CACHE"):
                env[f"XDG_{kind}_HOME"] = f"{tmp}/{role}/{kind.lower()}"
            process = subprocess.Popen(
                [os.environ.get("GODOT", "godot"), "--headless", "--path", str(ROOT),
                 "res://tests/network_peer.tscn", "--", str(role)],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
            processes.append(process)
            if role == 0:
                time.sleep(0.5)
        failed = False
        for role, process in enumerate(processes):
            output, _ = process.communicate(timeout=23)
            print(f"--- peer {role} ---\n{output}", end="")
            expected = "synchronized four unique confirmed characters"
            if process.returncode or "ERROR:" in output or expected not in output:
                failed = True
        raise SystemExit(1 if failed else 0)
finally:
    for process in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
