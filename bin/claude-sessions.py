#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["textual>=8"]
# ///
"""Visualize running Claude Code sessions from ~/.claude/sessions/*.json."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar

CLAUDE_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude"))
SESSIONS_DIR = CLAUDE_DIR / "sessions"
PROJECTS_DIR = CLAUDE_DIR / "projects"

# Nord palette: https://www.nordtheme.com/docs/colors-and-palettes
NORD = {
    "bg": "#2E3440",  # nord0
    "card": "#3B4252",  # nord1
    "select": "#434C5E",  # nord2
    "border": "#4C566A",  # nord3
    "dim": "#7B88A1",  # nord3 brightened for readable secondary text
    "fg": "#D8DEE9",  # nord4
    "bright": "#ECEFF4",  # nord6
    "frost": "#88C0D0",  # nord8
    "blue": "#81A1C1",  # nord9
    "red": "#BF616A",  # nord11
    "orange": "#D08770",  # nord12
    "yellow": "#EBCB8B",  # nord13
    "yellow_dim": "#7D7157",  # nord13 blended into nord1, for the flash off phase
    "green": "#A3BE8C",  # nord14
    "purple": "#B48EAD",  # nord15
}
STATUS_ORDER = {"waiting": 0, "busy": 1, "idle": 2}
STATUS_COLOR = {"waiting": NORD["yellow"], "busy": NORD["green"], "idle": NORD["dim"]}
STATUS_ICON = {"waiting": "⏸", "busy": "●", "idle": "○"}
PROMPT_MAX_LEN = 200
FLASH_INTERVAL = 0.5


@dataclass
class TranscriptInfo:
    """Fields extracted incrementally from a session transcript (.jsonl)."""

    title: str | None = None
    last_prompt: str | None = None
    model: str | None = None
    context_tokens: int | None = None
    last_tool: str | None = None
    tool_running: bool = False
    permission_mode: str | None = None


@dataclass
class TranscriptReader:
    """Reads only the bytes appended since the previous read."""

    path: Path
    offset: int = 0
    info: TranscriptInfo = field(default_factory=TranscriptInfo)

    def update(self) -> TranscriptInfo:
        try:
            size = self.path.stat().st_size
        except OSError:
            return self.info
        if size < self.offset:
            self.offset, self.info = 0, TranscriptInfo()
        if size == self.offset:
            return self.info
        with self.path.open("rb") as f:
            f.seek(self.offset)
            chunk = f.read()
        end = chunk.rfind(b"\n")
        if end < 0:
            return self.info
        self.offset += end + 1
        for line in chunk[:end].splitlines():
            try:
                self._apply(json.loads(line))
            except (json.JSONDecodeError, TypeError, AttributeError):
                continue
        return self.info

    def _apply(self, rec: dict) -> None:
        info = self.info
        kind = rec.get("type")
        if kind == "ai-title":
            info.title = rec.get("aiTitle") or info.title
        elif kind == "last-prompt":
            info.last_prompt = rec.get("lastPrompt") or info.last_prompt
        elif kind == "permission-mode":
            info.permission_mode = rec.get("permissionMode") or info.permission_mode
        elif kind == "assistant" and not rec.get("isSidechain"):
            msg = rec.get("message") or {}
            info.model = msg.get("model") or info.model
            usage = msg.get("usage") or {}
            if usage:
                info.context_tokens = (
                    usage.get("input_tokens", 0)
                    + usage.get("cache_read_input_tokens", 0)
                    + usage.get("cache_creation_input_tokens", 0)
                )
            tools = [
                c.get("name")
                for c in msg.get("content") or []
                if isinstance(c, dict) and c.get("type") == "tool_use"
            ]
            if tools:
                info.last_tool, info.tool_running = tools[-1], True
        elif kind == "user" and not rec.get("isSidechain"):
            content = (rec.get("message") or {}).get("content")
            if isinstance(content, list) and any(
                isinstance(c, dict) and c.get("type") == "tool_result" for c in content
            ):
                info.tool_running = False


@dataclass
class Session:
    pid: int
    session_id: str
    name: str
    cwd: str
    status: str
    waiting_for: str | None
    started_at: float
    status_updated_at: float
    tmux: str | None
    transcript: TranscriptInfo


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def find_transcript(session_id: str, cwd: str) -> Path | None:
    guess = PROJECTS_DIR / re.sub(r"[^A-Za-z0-9]", "-", cwd) / f"{session_id}.jsonl"
    if guess.exists():
        return guess
    # The session may have moved (e.g. into a worktree), so search all projects.
    return next(PROJECTS_DIR.glob(f"*/{session_id}.jsonl"), None)


def repo_root(path: Path) -> str | None:
    """Return the main worktree root so that linked worktrees are included."""
    try:
        common = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
            cwd=path,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return str(Path(common).parent)


class SessionStore:
    def __init__(self) -> None:
        self._readers: dict[str, TranscriptReader] = {}

    def load(self, root: str | None) -> list[Session]:
        sessions = []
        for file in SESSIONS_DIR.glob("*.json"):
            try:
                data = json.loads(file.read_text())
            except (OSError, json.JSONDecodeError):
                continue
            pid, sid, cwd = data.get("pid"), data.get("sessionId"), data.get("cwd", "")
            if not isinstance(pid, int) or not sid or not pid_alive(pid):
                continue
            if root and not (cwd == root or cwd.startswith(root + os.sep)):
                continue
            sessions.append(
                Session(
                    pid=pid,
                    session_id=sid,
                    name=data.get("name") or Path(cwd).name,
                    cwd=cwd,
                    status=data.get("status", "idle"),
                    waiting_for=data.get("waitingFor"),
                    started_at=data.get("startedAt", 0) / 1000,
                    status_updated_at=data.get("statusUpdatedAt", 0) / 1000,
                    tmux=data.get("tmux"),
                    transcript=self._transcript(sid, cwd),
                )
            )
        sessions.sort(
            # Newest first; the order is fixed so cards never move on status changes.
            key=lambda s: -s.started_at
        )
        return sessions

    def _transcript(self, session_id: str, cwd: str) -> TranscriptInfo:
        reader = self._readers.get(session_id)
        # Entering a worktree moves the transcript to another project dir.
        if reader is None or not reader.path.exists():
            path = find_transcript(session_id, cwd)
            if path is None:
                return TranscriptInfo()
            reader = self._readers[session_id] = TranscriptReader(path)
        return reader.update()


def human_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h{seconds % 3600 // 60:02d}m"
    return f"{seconds // 86400}d{seconds % 86400 // 3600}h"


def context_bar(tokens: int, width: int = 10) -> str:
    # Model IDs in transcripts do not say whether the 1M context window is on,
    # so assume 200k and switch to 1M once usage exceeds it.
    limit = 200_000 if tokens <= 200_000 else 1_000_000
    ratio = min(tokens / limit, 1.0)
    filled = round(ratio * width)
    color = (
        NORD["green"]
        if ratio < 0.6
        else NORD["yellow"]
        if ratio < 0.85
        else NORD["red"]
    )
    bar = f"[{color}]{'━' * filled}[/][{NORD['border']}]{'━' * (width - filled)}[/]"
    return f"{bar} [{NORD['dim']}]{tokens // 1000}k/{limit // 1000}k[/]"


def shorten_home(path: str) -> str:
    home = str(Path.home())
    return "~" + path[len(home) :] if path.startswith(home) else path


def truncate_middle(path: str, width: int) -> str:
    """Keep the first and last path components and elide the middle ones."""
    from rich.cells import cell_len

    if cell_len(path) <= width:
        return path
    parts = path.split("/")
    head, tail = parts[0], [parts[-1]]
    for part in reversed(parts[1:-1]):
        if cell_len("/".join([head, "…", part, *tail])) > width:
            break
        tail.insert(0, part)
    result = "/".join([head, "…", *tail])
    if cell_len(result) > width:
        result = "…" + parts[-1][-(width - 1) :]
    return result


def display_cwd(cwd: str, width: int) -> str:
    repo, sep, worktree = cwd.partition("/.claude/worktrees/")
    if sep:
        return f"{Path(repo).name} ⎇ {worktree}"
    path = shorten_home(cwd)
    # "/Volumes/<disk>" only says which disk the path is on, so drop "/Volumes/".
    path = path.removeprefix("/Volumes/")
    return truncate_middle(path, width)


def escape(text: str) -> str:
    return text.replace("[", r"\[")


def card_title(s: Session) -> str:
    color = STATUS_COLOR.get(s.status, NORD["fg"])
    icon = STATUS_ICON.get(s.status, "?")
    return f"[{color}]{icon}[/] [bold {NORD['bright']}]{escape(s.name)}[/]"


def card_subtitle(s: Session, now: float, flash_on: bool = True) -> str:
    color = STATUS_COLOR.get(s.status, NORD["fg"])
    if s.status == "waiting":
        color = f"bold {NORD['yellow']}" if flash_on else NORD["yellow_dim"]
    uptime = f"up {human_duration(now - s.started_at)}"
    # For waiting sessions, show the reason (e.g. "input needed") instead of the status.
    label = s.waiting_for or s.status if s.status == "waiting" else s.status
    return (
        f"[{color}]{escape(label)} {human_duration(now - s.status_updated_at)}[/]"
        f"[{NORD['dim']}] · {uptime}[/]"
    )


def render_card(s: Session, now: float, width: int) -> str:
    t = s.transcript
    dim = NORD["dim"]
    lines = []
    if t.title:
        lines.append(f"[bold {NORD['frost']}]{escape(t.title)}[/]")
    if t.last_prompt:
        prompt = " ".join(t.last_prompt.split())[:PROMPT_MAX_LEN]
        lines.append(f"[{NORD['fg']}]› {escape(prompt)}[/]")
    lines.append(f"[{dim}]{escape(display_cwd(s.cwd, width))}[/]")
    if t.context_tokens:
        lines.append(context_bar(t.context_tokens))
    meta = []
    if t.model:
        meta.append(f"[{NORD['purple']}]{escape(t.model.removeprefix('claude-'))}[/]")
    if t.permission_mode and t.permission_mode != "default":
        meta.append(f"[{NORD['orange']}]{escape(t.permission_mode)}[/]")
    # The last tool is almost always Bash once idle, so show it only while in use
    # (while busy it is running; while waiting it is usually awaiting permission).
    if t.last_tool and t.tool_running and s.status in ("busy", "waiting"):
        color = NORD["green"] if s.status == "busy" else NORD["yellow"]
        meta.append(f"[{color}]▶ {escape(t.last_tool)}[/]")
    if s.tmux:
        meta.append(f"[{NORD['blue']}]tmux[/]")
    if meta:
        lines.append(" ".join(meta))
    return "\n".join(lines)


def run_tui(store: SessionStore, root: str | None, interval: float) -> None:
    from textual.app import App, ComposeResult
    from textual.binding import Binding
    from textual.containers import Horizontal
    from textual.widgets import Footer, ListItem, ListView, Static

    class SessionItem(ListItem):
        def __init__(self, session: Session) -> None:
            super().__init__(Static(classes="card"))
            self.session = session
            self.body = ""
            self.now = time.time()

        def refresh_card(self, session: Session, now: float, flash_on: bool) -> None:
            self.session = session
            self.now = now
            # Before the first layout the width is 0, so fall back to a wide value.
            width = self.content_size.width or 200
            # Assign only changed values: every assignment triggers a repaint.
            title = card_title(session)
            subtitle = card_subtitle(session, now, flash_on)
            if self.border_title != title:
                self.border_title = title
            if self.border_subtitle != subtitle:
                self.border_subtitle = subtitle
            body = render_card(session, now, width)
            if body != self.body:
                self.body = body
                self.query_one(Static).update(body)
            self.set_class(session.status == "waiting", "waiting")

        def flash(self, flash_on: bool) -> None:
            if self.session.status == "waiting":
                self.border_subtitle = card_subtitle(self.session, self.now, flash_on)

    class SessionsApp(App):
        CSS = """
        Screen { background: #2E3440; }
        ListView { background: #2E3440; padding: 0 1; }
        ListView > SessionItem {
            background: #3B4252;
            color: #D8DEE9;
            border: round #4C566A;
            border-title-align: left;
            border-subtitle-align: right;
            padding: 0 1;
            margin-bottom: 1;
        }
        ListView > SessionItem.waiting { border: round #EBCB8B; }
        ListView > SessionItem.-highlight,
        ListView:focus > SessionItem.-highlight {
            background: #434C5E;
            border: round #88C0D0;
        }
        ListView > SessionItem.waiting.-highlight,
        ListView:focus > SessionItem.waiting.-highlight { border: round #EBCB8B; }
        SessionItem .card { background: transparent; text-wrap: nowrap; text-overflow: ellipsis; }
        #header {
            height: auto;
            padding: 0 2;
            margin: 0 1 1 1;
            border-bottom: solid #4C566A;
        }
        #counts { width: 1fr; }
        #scope { width: auto; }
        Footer { background: #3B4252; }
        """
        BINDINGS: ClassVar = [
            Binding("q", "quit", "Quit"),
            # ctrl+q collides with VS Code, so also quit on ctrl+c like other CLIs.
            Binding("ctrl+c", "quit", show=False, priority=True),
            Binding("enter", "jump", "tmux jump"),
            Binding("a", "toggle_scope", "All/Repo"),
            Binding("j", "cursor_down", show=False),
            Binding("k", "cursor_up", show=False),
        ]

        def __init__(self) -> None:
            super().__init__()
            self.root = root
            self.repo = root or repo_root(Path.cwd())
            self.order: list[int] = []
            self.flash_on = True

        def compose(self) -> ComposeResult:
            with Horizontal(id="header"):
                yield Static(id="counts")
                yield Static(id="scope")
            yield ListView()
            yield Footer()

        async def on_mount(self) -> None:
            self.title = "Claude sessions"
            self.theme = "nord"
            await self.refresh_sessions()
            self.set_interval(interval, self.refresh_sessions)
            self.set_interval(FLASH_INTERVAL, self.toggle_flash)

        def toggle_flash(self) -> None:
            self.flash_on = not self.flash_on
            for item in self.query(SessionItem):
                item.flash(self.flash_on)

        async def refresh_sessions(self) -> None:
            sessions = store.load(self.root)
            now = time.time()
            view = self.query_one(ListView)
            order = [s.pid for s in sessions]
            if order != self.order:
                await self._reorder(view, sessions)
                self.order = order
            items = {item.session.pid: item for item in view.query(SessionItem)}
            for s in sessions:
                items[s.pid].refresh_card(s, now, self.flash_on)
            counts = {k: sum(s.status == k for s in sessions) for k in STATUS_ORDER}
            scope = "repo" if self.root else "all"
            waiting_color = (
                f"bold {NORD['yellow']}" if counts["waiting"] else NORD["dim"]
            )
            parts = [
                f"[{NORD['green']}]● {counts['busy']} busy[/]",
                f"[{NORD['dim']}]○ {counts['idle']} idle[/]",
                f"[{waiting_color}]⏸ {counts['waiting']} waiting[/]",
            ]
            self._update_static("#counts", "   ".join(parts))
            self._update_static("#scope", f"[{NORD['dim']}]{escape(scope)}[/]")

        def _update_static(self, selector: str, content: str) -> None:
            widget = self.query_one(selector, Static)
            if getattr(widget, "last_content", None) != content:
                widget.last_content = content
                widget.update(content)

        async def _reorder(self, view, sessions: list[Session]) -> None:
            """Reuse existing cards and only move them, instead of rebuilding the list."""
            selected = self._selected_pid()
            items = {item.session.pid: item for item in view.query(SessionItem)}
            alive = {s.pid for s in sessions}
            for pid in [pid for pid in items if pid not in alive]:
                await items.pop(pid).remove()
            new = [SessionItem(s) for s in sessions if s.pid not in items]
            if new:
                await view.extend(new)
                items.update((item.session.pid, item) for item in new)
            for i, s in enumerate(sessions):
                if view.children[i] is not items[s.pid]:
                    view.move_child(items[s.pid], before=i)
            order = [s.pid for s in sessions]
            if selected in order:
                view.index = order.index(selected)
            elif order and view.index is None:
                view.index = 0

        def _selected_pid(self) -> int | None:
            item = self.query_one(ListView).highlighted_child
            return item.session.pid if isinstance(item, SessionItem) else None

        def action_cursor_down(self) -> None:
            self.query_one(ListView).action_cursor_down()

        def action_cursor_up(self) -> None:
            self.query_one(ListView).action_cursor_up()

        async def action_toggle_scope(self) -> None:
            if self.root:
                self.root = None
            elif self.repo:
                self.root = self.repo
            else:
                self.notify("Not inside a git repository", severity="warning")
            await self.refresh_sessions()

        def on_list_view_selected(self, event: ListView.Selected) -> None:
            self.action_jump()

        def action_jump(self) -> None:
            item = self.query_one(ListView).highlighted_child
            if not isinstance(item, SessionItem):
                return
            target = item.session.tmux
            if not target:
                self.notify("This session is not running in tmux", severity="warning")
                return
            pane = target.rsplit(".", 1)[-1]
            cmd = [
                "tmux",
                "switch-client",
                "-t",
                pane,
                ";",
                "select-window",
                "-t",
                pane,
                ";",
                "select-pane",
                "-t",
                pane,
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                self.notify(result.stderr.strip() or "tmux failed", severity="error")

    SessionsApp().run()


def dump(store: SessionStore, root: str | None) -> None:
    """Print cards once as plain text (for debugging without a TUI)."""
    from rich.console import Console

    console = Console()
    now = time.time()
    for s in store.load(root):
        console.print(render_card(s, now, console.width))
        console.rule(style="grey30")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        action="store_true",
        help="only sessions under the current git repository",
    )
    parser.add_argument(
        "--interval", type=float, default=1.0, help="refresh interval in seconds"
    )
    parser.add_argument("--once", action="store_true", help="print once and exit")
    args = parser.parse_args()

    root = None
    if args.repo:
        root = repo_root(Path.cwd())
        if root is None:
            parser.error("--repo: current directory is not inside a git repository")

    store = SessionStore()
    if args.once:
        dump(store, root)
    else:
        run_tui(store, root, args.interval)


if __name__ == "__main__":
    main()
