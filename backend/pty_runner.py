#!/usr/bin/env python3
"""AuditX PTY Runner — pseudo-terminal execution & ANSI streaming."""

import os
import sys
import pty
import select
import subprocess
import errno
import json
import threading
import signal
import html
import re
import time
import argparse

ANSI_COLORS = {
    '30': '#4f5b66', '31': '#ff5555', '32': '#50fa7b', '33': '#f1fa8c',
    '34': '#6272a4', '35': '#ff79c6', '36': '#8be9fd', '37': '#f8f8f2',
    '90': '#6272a4', '91': '#ff6e6e', '92': '#69ff94', '93': '#ffffa5',
    '94': '#d6acff', '95': '#ff92df', '96': '#a4ffff', '97': '#ffffff'
}

# ANSI to HTML converter
def ansi_to_html(text: str) -> str:
    if not text:
        return ""
    text = html.escape(text)

    def repl(m):
        raw_codes = m.group(1).split(';')
        if not raw_codes or raw_codes == [''] or raw_codes == ['0']:
            return '</span>'
        styles = []
        i = 0
        while i < len(raw_codes):
            c = raw_codes[i]
            if c in ANSI_COLORS:
                styles.append(f'color:{ANSI_COLORS[c]}')
            elif c == '1':
                styles.append('font-weight:bold')
            elif c == '2':
                styles.append('opacity:0.7')
            elif c == '3':
                styles.append('font-style:italic')
            elif c == '4':
                styles.append('text-decoration:underline')
            elif c == '38' and i + 2 < len(raw_codes) and raw_codes[i+1] == '5':
                try:
                    color_idx = int(raw_codes[i+2])
                    styles.append(f'color:rgb({(color_idx % 6) * 45 + 30}, {((color_idx // 6) % 6) * 45 + 30}, {((color_idx // 36) % 6) * 45 + 30})')
                except Exception:
                    pass
                i += 2
            i += 1
        style_str = ";".join(styles)
        return f'<span style="{style_str}">' if styles else ''

    out = re.sub(r'\033\[([0-9;]*)m', repl, text)
    out = re.sub(r'\033\[[0-9;]*[a-zA-Z]', '', out)
    out = re.sub(r'\033\].*?\x07', '', out)
    return out

# JSON line emitter
def emit(event: str, **kwargs):
    payload = {"event": event, **kwargs}
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()

# PTY session runner
def run_pty_session(cmd: str, targets: dict = None, cwd: str = None):
    if targets is None:
        targets = {}

    # Target vars
    ip = targets.get("ip", "").strip()
    domain = targets.get("domain", "").strip()
    url = targets.get("url", "").strip()
    cloud = targets.get("cloud", "").strip()
    path_target = targets.get("path", "").strip()
    username = targets.get("username", "").strip()
    iface = targets.get("interface", "").strip()

    primary = ip or domain or url or cloud or path_target or username or iface or "127.0.0.1"

    # Environment setup
    env = os.environ.copy()
    env["AUDITX_TARGET"] = primary
    env["TARGET"] = primary
    env["IP"] = ip
    env["DOMAIN"] = domain
    env["URL"] = url
    env["CLOUD"] = cloud
    env["PATH_TARGET"] = path_target
    env["USERNAME"] = username
    env["INTERFACE"] = iface
    env["TERM"] = "xterm-256color"
    env["COLORTERM"] = "truecolor"
    env["FORCE_COLOR"] = "1"
    env["CLICOLOR_FORCE"] = "1"
    env["PYTHONUNBUFFERED"] = "1"

    local_bin = os.path.expanduser("~/.local/bin")
    if local_bin not in env.get("PATH", "").split(os.pathsep):
        env["PATH"] = local_bin + os.pathsep + env.get("PATH", "")

    work_dir = cwd or os.path.expanduser("~")

    # Spawn PTY
    master, slave = pty.openpty()

    try:
        proc = subprocess.Popen(
            ["/bin/bash", "-c", cmd],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            close_fds=True,
            preexec_fn=os.setsid,
            env=env,
            cwd=work_dir
        )
    except Exception as e:
        os.close(slave)
        os.close(master)
        emit("error", message=f"Failed to spawn process: {e}")
        emit("exit", code=-1)
        return -1

    os.close(slave)
    emit("start", cmd=cmd, pid=proc.pid, cwd=work_dir, timestamp=time.strftime("%H:%M:%S"))

    # Stdin listener thread
    stop_event = threading.Event()

    def stdin_forwarder():
        while not stop_event.is_set():
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                stripped = line.strip()
                if stripped == "__AUDITX_SIGNAL_INT__":
                    try:
                        os.killpg(os.getpgid(proc.pid), signal.SIGINT)
                    except Exception:
                        pass
                    continue
                elif stripped == "__AUDITX_SIGNAL_KILL__":
                    try:
                        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
                    except Exception:
                        pass
                    continue

                os.write(master, line.encode("utf-8", errors="replace"))
            except Exception:
                break

    stdin_thread = threading.Thread(target=stdin_forwarder, daemon=True)
    stdin_thread.start()

    # Signal handlers
    def sig_handler(signum, frame):
        try:
            os.killpg(os.getpgid(proc.pid), signum)
        except Exception:
            pass

    try:
        signal.signal(signal.SIGINT, sig_handler)
        signal.signal(signal.SIGTERM, sig_handler)
    except Exception:
        pass

    # Output read loop
    buf = b""
    last_flush_time = time.time()

    try:
        while True:
            try:
                r, _, _ = select.select([master], [], [], 0.04)
                now = time.time()

                if r:
                    chunk = os.read(master, 2048)
                    if not chunk:
                        break
                    buf += chunk

                    while b"\n" in buf:
                        raw_line, buf = buf.split(b"\n", 1)
                        clean = raw_line.decode("utf-8", errors="replace").rstrip("\r")
                        emit("output", text=ansi_to_html(clean), raw=clean, is_line=True)
                        last_flush_time = now

                else:
                    # Flush partial prompt buffer
                    if buf and (now - last_flush_time > 0.08):
                        clean = buf.decode("utf-8", errors="replace").rstrip("\r")
                        buf = b""
                        emit("output", text=ansi_to_html(clean), raw=clean, is_line=False)
                        last_flush_time = now

                    if proc.poll() is not None:
                        if buf:
                            clean = buf.decode("utf-8", errors="replace").rstrip("\r")
                            emit("output", text=ansi_to_html(clean), raw=clean, is_line=False)
                        break

            except OSError as e:
                if e.errno == errno.EIO:
                    if buf:
                        clean = buf.decode("utf-8", errors="replace").rstrip("\r")
                        emit("output", text=ansi_to_html(clean), raw=clean, is_line=False)
                    break
                raise
    finally:
        stop_event.set()
        try:
            os.close(master)
        except Exception:
            pass

    proc.wait()
    emit("exit", code=proc.returncode, timestamp=time.strftime("%H:%M:%S"))
    return proc.returncode

def main():
    parser = argparse.ArgumentParser(description="AuditX PTY Runner")
    parser.add_argument("--cmd", required=True, help="Command to run")
    parser.add_argument("--targets", default="{}", help="JSON targets dictionary")
    parser.add_argument("--cwd", default=None, help="Working directory")

    args = parser.parse_args()

    targets_dict = {}
    if args.targets:
        try:
            targets_dict = json.loads(args.targets)
        except Exception:
            targets_dict = {}

    code = run_pty_session(args.cmd, targets_dict, args.cwd)
    sys.exit(code if code is not None else 0)

if __name__ == "__main__":
    main()
