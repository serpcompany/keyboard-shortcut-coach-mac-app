#!/usr/bin/env python3
"""Throwaway localhost launcher for comparing the two pre-project UI experiments."""

from __future__ import annotations

import argparse
import json
import os
import secrets
import shlex
import signal
import subprocess
import threading
import time
import webbrowser
from collections import deque
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


HERE = Path(__file__).resolve().parent
REPO_PARENT = HERE.parents[2]
GITIFY_WORKTREE = Path(
    os.environ.get(
        "KEYLUME_GITIFY_WORKTREE",
        REPO_PARENT / "clone-keylume-ios-app-issue-4",
    )
).resolve()
HEYCLICKY_WORKTREE = Path(
    os.environ.get(
        "KEYLUME_HEYCLICKY_WORKTREE",
        REPO_PARENT / "clone-keylume-ios-app-issue-5",
    )
).resolve()

EXPECTED = {
    "gitify": {
        "worktree": GITIFY_WORKTREE,
        "branch": "feat/4-gitify-coaching-inbox",
        "commit": "60e3ca3e9eb369d1e2c00c098590156c284e73f3",
    },
    "heyclicky": {
        "worktree": HEYCLICKY_WORKTREE,
        "branch": "feat/5-heyclicky-presentation-modes",
        "commit": "ec844dc83d543e91fcf858acab1ae860a832cdb5",
    },
}

MODES = {
    "all",
    "topCenterPresence",
    "compactExpandedShelf",
    "cursorHalo",
    "statusFeedback",
    "pointerCard",
    "decisionBanner",
}

EVIDENCE_ROOTS = {
    "gitify": GITIFY_WORKTREE / "docs/app-replica/evidence/issue-4-gitify-v1",
    "heyclicky": HEYCLICKY_WORKTREE / "docs/evidence/issue-5-presentation-gallery",
}

TOKEN = secrets.token_urlsafe(24)
EVENTS: deque[dict[str, Any]] = deque(maxlen=30)
EVENT_LOCK = threading.Lock()


def app_path(kind: str) -> Path:
    return EXPECTED[kind]["worktree"] / ".build/release/KeylumeClone.app"


def executable_path(kind: str) -> Path:
    return app_path(kind) / "Contents/MacOS/KeylumeClone"


def git_head(worktree: Path) -> str | None:
    try:
        return subprocess.check_output(
            ["git", "-C", str(worktree), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=3,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        return None


def allowed_processes() -> list[dict[str, Any]]:
    allowed = {str(executable_path(kind)): kind for kind in EXPECTED}
    try:
        output = subprocess.check_output(
            ["ps", "-axo", "pid=,command="], text=True, timeout=3
        )
    except (OSError, subprocess.SubprocessError):
        return []

    matches: list[dict[str, Any]] = []
    for line in output.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        pid_text, _, command = stripped.partition(" ")
        try:
            pid = int(pid_text)
            tokens = shlex.split(command)
        except (ValueError, TypeError):
            continue
        if not tokens:
            continue
        kind = allowed.get(tokens[0])
        if kind:
            matches.append({"pid": pid, "kind": kind, "command": command})
    return matches


def record(level: str, message: str) -> None:
    with EVENT_LOCK:
        EVENTS.appendleft(
            {"at": time.strftime("%H:%M:%S"), "level": level, "message": message}
        )


def status() -> dict[str, Any]:
    variants: dict[str, Any] = {}
    for kind, config in EXPECTED.items():
        current = git_head(config["worktree"])
        variants[kind] = {
            "worktree": str(config["worktree"]),
            "branch": config["branch"],
            "expectedCommit": config["commit"],
            "currentCommit": current,
            "commitMatches": current == config["commit"],
            "app": str(app_path(kind)),
            "artifactReady": executable_path(kind).is_file(),
        }
    with EVENT_LOCK:
        events = list(EVENTS)
    return {
        "ok": True,
        "variants": variants,
        "running": allowed_processes(),
        "events": events,
    }


def stop_allowed() -> list[int]:
    stopped: list[int] = []
    for process in allowed_processes():
        try:
            os.kill(process["pid"], signal.SIGTERM)
            stopped.append(process["pid"])
        except ProcessLookupError:
            pass
    if stopped:
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline and allowed_processes():
            time.sleep(0.1)
        record("info", f"Stopped allowed experiment process(es): {', '.join(map(str, stopped))}")
    else:
        record("info", "No experiment process was running")
    return stopped


def launch(kind: str, mode: str | None = None) -> dict[str, Any]:
    if kind not in EXPECTED:
        raise ValueError("Unknown experiment")
    if kind == "heyclicky" and mode not in MODES:
        raise ValueError("Unknown HeyClicky presentation mode")

    app = app_path(kind)
    if not executable_path(kind).is_file():
        raise FileNotFoundError(
            f"Packaged artifact is missing. Build it with: cd {EXPECTED[kind]['worktree']} && zsh scripts/package_app.sh release -"
        )

    stopped = stop_allowed()
    command = ["open", "-n", str(app)]
    if kind == "heyclicky":
        command.extend(["--args", f"--showcase={mode}"])
    subprocess.run(command, check=True, timeout=10)

    # The Gitify experiment opens its persistent history window on app reopen.
    if kind == "gitify":
        time.sleep(1.0)
        subprocess.run(["open", str(app)], check=True, timeout=10)

    label = "Gitify-style trial" if kind == "gitify" else f"HeyClicky mode: {mode}"
    record("success", f"Launched {label}")
    time.sleep(0.7)
    return {"ok": True, "launched": kind, "mode": mode, "stopped": stopped, "state": status()}


class Handler(BaseHTTPRequestHandler):
    server_version = "KeylumeUILab/0.1"

    def log_message(self, format: str, *args: Any) -> None:
        return

    def send_json(self, payload: dict[str, Any], code: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            html = (HERE / "index.html").read_text().replace("__UI_LAB_TOKEN__", TOKEN)
            body = html.encode()
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith("/assets/"):
            parts = path.split("/")
            if len(parts) == 4 and parts[2] in EVIDENCE_ROOTS:
                filename = parts[3]
                asset = EVIDENCE_ROOTS[parts[2]] / filename
                if (
                    filename == Path(filename).name
                    and filename.endswith(".png")
                    and asset.is_file()
                ):
                    body = asset.read_bytes()
                    self.send_response(HTTPStatus.OK)
                    self.send_header("Content-Type", "image/png")
                    self.send_header("Content-Length", str(len(body)))
                    self.send_header("Cache-Control", "no-store")
                    self.end_headers()
                    self.wfile.write(body)
                    return
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        if path in {"/api/status", "/health"}:
            self.send_json(status())
            return
        self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        if self.headers.get("X-UI-Lab-Token") != TOKEN:
            self.send_json({"ok": False, "error": "Invalid local lab token"}, HTTPStatus.FORBIDDEN)
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length > 4096:
            self.send_json({"ok": False, "error": "Request too large"}, HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
            return
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
            path = urlparse(self.path).path
            if path == "/api/stop":
                stopped = stop_allowed()
                self.send_json({"ok": True, "stopped": stopped, "state": status()})
                return
            if path == "/api/launch":
                self.send_json(launch(payload.get("kind", ""), payload.get("mode")))
                return
            self.send_json({"ok": False, "error": "Unknown action"}, HTTPStatus.NOT_FOUND)
        except FileNotFoundError as error:
            record("error", str(error))
            self.send_json({"ok": False, "error": str(error), "state": status()}, HTTPStatus.CONFLICT)
        except (ValueError, json.JSONDecodeError) as error:
            record("error", str(error))
            self.send_json({"ok": False, "error": str(error), "state": status()}, HTTPStatus.BAD_REQUEST)
        except (OSError, subprocess.SubprocessError) as error:
            record("error", f"Launch failed: {error}")
            self.send_json({"ok": False, "error": f"Launch failed: {error}", "state": status()}, HTTPStatus.INTERNAL_SERVER_ERROR)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--open", action="store_true", dest="open_browser")
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}/?variant=compare"
    record("info", "Pre-project UI Lab started")
    print(f"Pre-Project UI Lab: {url}")
    print("Press Ctrl+C to stop the lab. Experiment apps are not stopped automatically.")
    if args.open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
