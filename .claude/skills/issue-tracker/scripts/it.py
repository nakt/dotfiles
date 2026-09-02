# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""it -- helper script for the issue-tracker skill.

This script makes no judgment calls. What to file, what the priority is, and
whether something is resolved are decisions left to SKILL.md (the LLM). Only
two kinds of things live here:

  1. Operations that need atomicity   claim / release / done / reap
  2. Mechanical scanning              list (returns only frontmatter + TL;DR)

claim is nothing more than an inbox -> wip rename. A rename is atomic on the
same filesystem and fails when the source is gone, so double-claims are
prevented without a lock file.

State is represented by directory (inbox / wip / done). owner and claimed_at
are kept in frontmatter, but they record "who, when" rather than state,
so it isn't duplicate state tracking.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

ROOT_NAME = "issues"
INBOX, WIP, DONE = "inbox", "wip", "done"
PRIORITY_ORDER = {"high": 0, "med": 1, "low": 2}
VALID_PRIORITIES = tuple(PRIORITY_ORDER)
# wip first so triage sees what is already in hand before the backlog.
STATUS_ORDER = {WIP: 0, INBOX: 1, DONE: 2}
TAG_RE = re.compile(r"[a-z0-9-]+")
TEMPLATE_PATH = Path(__file__).parent.parent / "templates" / "issue-template.md"
GIT_HINT = "hint: git add -A issues/ でステージしてください（移動元の削除と移動先の追加は対で扱う）"


# --------------------------------------------------------------------------
# Root resolution
# --------------------------------------------------------------------------


def find_root(create: bool = False) -> Path:
    """Walk up from the current directory to find issues/.

    No environment variable or config file. Exits with an error when not
    found -- silently falling back to creating one in the home directory
    would be the most dangerous failure mode.
    """
    if create:
        return Path.cwd() / ROOT_NAME

    cur = Path.cwd().resolve()
    for d in (cur, *cur.parents):
        cand = d / ROOT_NAME
        if (cand / INBOX).is_dir():
            return cand
    sys.exit(f"error: {ROOT_NAME}/ が見つかりません。`it init` で作成してください")


def bucket(root: Path, name: str) -> Path:
    return root / name


def all_files(root: Path, status: str | None = None) -> list[tuple[str, Path]]:
    """List of (status, path). done is scanned recursively across its year-month subdirectories."""
    out: list[tuple[str, Path]] = []
    for st in [status] if status else [INBOX, WIP, DONE]:
        base = bucket(root, st)
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.md")):
            out.append((st, p))
    return out


def find_one(root: Path, key: str) -> tuple[str, Path]:
    """Resolve to exactly one issue by exact id match, falling back to a prefix match."""
    hits = [(st, p) for st, p in all_files(root) if p.stem == key]
    if not hits:
        hits = [(st, p) for st, p in all_files(root) if p.stem.startswith(key)]
    if not hits:
        sys.exit(f"error: {key} に一致する issue がありません")
    if len(hits) > 1:
        sys.exit("error: 曖昧です: " + ", ".join(p.stem for _, p in hits))
    return hits[0]


# --------------------------------------------------------------------------
# frontmatter
# --------------------------------------------------------------------------

FM_RE = re.compile(r"\A---\n(.*?)\n---\n?(.*)\Z", re.DOTALL)
LOG_HEADING_RE = re.compile(r"^##[ \t]*ログ[ \t]*$", re.MULTILINE)
# Shared by parse and set_fields on purpose: reading and deleting block-style
# continuation lines must agree, or set_fields leaves orphans behind.
BLOCK_ITEM_RE = re.compile(r"^\s+- ")


def strip_comment(val: str) -> str:
    """Strip a YAML trailing comment (whitespace, then `#`).

    Quoted values are returned untouched -- a `#` inside quotes is part of the
    value. Requiring leading whitespace keeps `#` inside a bare value (a URL
    fragment, for instance) out of the match.
    """
    if val[:1] in ('"', "'"):
        return val
    return re.sub(r"(^|\s+)#.*$", "", val).strip()


def read_scalar(val: str) -> str:
    """Decode a scalar value.

    `title` is written as a JSON string by `it new` / `it set` to keep a `#`
    in it out of comment stripping, so a value starting with `"` is read back
    with json. raw_decode rather than loads: strip_comment leaves a
    trailing comment attached to a quoted value, and raw_decode ignores
    whatever follows the string. Everything else is a bare value.
    """
    if val.startswith('"'):
        try:
            decoded, _ = json.JSONDecoder().raw_decode(val)
            if isinstance(decoded, str):
                return decoded
        except ValueError:
            pass
    return val.strip("'\"")


def parse(path: Path) -> tuple[dict, str, str]:
    """Return (frontmatter dict, raw frontmatter text, body).

    No YAML library (keeps dependencies at zero). Only needs to read the three
    forms this skill uses: `key: value`, and inline or block lists for
    tags / related / sources. Trailing comments are stripped from unquoted
    values. Writes go back line by line, so unparsed lines survive.
    """
    text = path.read_text(encoding="utf-8")
    m = FM_RE.match(text)
    if not m:
        return {}, "", text

    raw, body = m.group(1), m.group(2)
    data: dict = {}
    key = None
    for line in raw.split("\n"):
        if not line.strip():  # a blank line ends a block, as it does for set_fields
            key = None
            continue
        if key and BLOCK_ITEM_RE.match(line):  # block-style list
            if isinstance(data.get(key), list):
                data[key].append(strip_comment(line.lstrip()[1:].strip()))
            continue
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key, val = key.strip(), strip_comment(val.strip())
        if val.startswith("[") and val.endswith("]"):  # inline-style list
            items = [x.strip().strip("'\"") for x in val[1:-1].split(",")]
            data[key] = [x for x in items if x]
        elif val:
            data[key] = read_scalar(val)
        else:
            data[key] = []  # assume a list follows
    return data, raw, body


def set_fields(path: Path, **fields) -> None:
    """Replace frontmatter keys line by line; append missing keys at the end.

    Never regenerates the whole file, so comments, key order, and any
    notation this parser doesn't understand survive untouched. Pass None
    for a value to delete the key line. Block-style continuation lines that
    follow the key line go with it -- left behind, the next parse would read
    the old items back in and duplicate them.
    """
    text = path.read_text(encoding="utf-8")
    m = FM_RE.match(text)
    if not m:
        sys.exit(f"error: {path} に frontmatter がありません")

    lines = m.group(1).split("\n")
    for key, val in fields.items():
        pat = re.compile(rf"^{re.escape(key)}\s*:")
        idx = next((i for i, ln in enumerate(lines) if pat.match(ln)), None)
        if idx is None:
            if val is not None:
                lines.append(f"{key}: {val}")
            continue
        end = idx + 1
        while end < len(lines) and BLOCK_ITEM_RE.match(lines[end]):
            end += 1
        lines[idx:end] = [] if val is None else [f"{key}: {val}"]

    path.write_text("---\n" + "\n".join(lines) + "\n---\n" + m.group(2), encoding="utf-8")


def append_log(path: Path, line: str) -> None:
    """Insert one line at the end of the log section, creating the section at
    the end of the file when it is absent.

    The insertion point is just before the next `## ` heading rather than the
    end of the file, so a section written after the log (a completion note,
    for example) does not swallow the line.
    """
    text = path.read_text(encoding="utf-8").rstrip("\n")
    m = LOG_HEADING_RE.search(text)
    if not m:
        path.write_text(f"{text}\n\n## ログ\n\n{line}\n", encoding="utf-8")
        return

    nxt = re.search(r"^##\s", text[m.end() :], re.MULTILINE)
    end = (m.end() + nxt.start()) if nxt else len(text)
    section = text[m.end() : end].rstrip()  # keeps the newlines after the heading
    body = f"{section}\n{line}" if section else f"\n\n{line}"  # blank line when still empty
    tail = text[end:].strip("\n")
    path.write_text(text[: m.end()] + body + (f"\n\n{tail}\n" if tail else "\n"), encoding="utf-8")


def write_section(path: Path, name: str, text: str, replace: bool) -> None:
    """Append to the given `## <name>` section (replace=True overwrites it).

    An existing section is edited in place; a missing one is created at the
    end of the file, which puts it after the log section. append_log knows
    about that and still writes inside the log section.
    """
    doc = path.read_text(encoding="utf-8").rstrip("\n")
    pat = re.compile(rf"^(##[ \t]*{re.escape(name)}[ \t]*)$", re.MULTILINE)
    m = pat.search(doc)
    if not m:
        path.write_text(f"{doc}\n\n## {name}\n\n{text}\n", encoding="utf-8")
        return

    nxt = re.search(r"^##\s", doc[m.end() :], re.MULTILINE)
    end = m.end() + (nxt.start() if nxt else len(doc) - m.end())
    body = "" if replace else doc[m.end() : end].strip()
    merged = f"{body}\n\n{text}".strip() if body else text
    path.write_text(f"{doc[: m.end()]}\n\n{merged}\n\n{doc[end:].lstrip()}".rstrip("\n") + "\n", encoding="utf-8")


def tag_list(fm: dict) -> list[str]:
    """Frontmatter tags as a list. A lone bare tag parses as a string, and a
    key with no value parses as an empty list."""
    tags = fm.get("tags") or []
    return [tags] if isinstance(tags, str) else list(tags)


def touch(path: Path) -> None:
    """Set updated to today. Every mutating subcommand routes through this,
    so the LLM side never needs its own updated-bumping logic."""
    set_fields(path, updated=today())


def tldr(body: str) -> str:
    """First non-blank line of the TL;DR section, or "" if it's empty.

    Lets triage skip reading the whole file. HTML comments are dropped
    first so a template placeholder is not mistaken for content. Always
    stops at the next heading -- otherwise an empty TL;DR would fall through
    and pick up content from a later section (e.g. the log).
    """
    body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
    m = re.search(r"^##\s*TL;?DR.*$", body, re.MULTILINE | re.IGNORECASE)
    tail = body[m.end() :] if m else body
    for line in tail.split("\n"):
        line = line.strip()
        if line.startswith("#"):
            return ""
        if line:
            return line
    return ""


# --------------------------------------------------------------------------
# Time
# --------------------------------------------------------------------------


def today() -> str:
    return datetime.now().strftime("%Y%m%d")


def stamp() -> str:
    return datetime.now().strftime("%Y%m%dT%H%M")


def parse_stamp(s: str) -> datetime | None:
    for fmt in ("%Y%m%dT%H%M", "%Y%m%d"):
        try:
            return datetime.strptime(s, fmt)
        except (ValueError, TypeError):
            continue
    return None


def parse_duration(s: str) -> timedelta:
    m = re.fullmatch(r"(\d+)([mhd]?)", s.strip())
    if not m:
        sys.exit(f"error: 期間の書式が不正です: {s}（例: 60m, 2h, 1d）")
    n, unit = int(m.group(1)), m.group(2) or "m"
    key = {"m": "minutes", "h": "hours", "d": "days"}[unit]
    return timedelta(**{key: n})


def agent_name(explicit: str | None) -> str:
    """--agent, then $IT_AGENT, then the working directory name.

    A pid would differ on every invocation, so it could never answer "what is
    this agent holding right now". One task per worktree makes the working
    directory name line up with whoever is working.
    """
    return explicit or os.environ.get("IT_AGENT") or Path.cwd().name


# --------------------------------------------------------------------------
# Listing
# --------------------------------------------------------------------------


def summarize(status: str, path: Path) -> dict:
    fm, _, body = parse(path)
    tags = tag_list(fm)
    # A hand-edited `priority:` written as a YAML list parses to a list, which
    # sort_key cannot hash. Degrade to blank here; cmd_check reads the raw
    # frontmatter and still reports it.
    priority = fm.get("priority")
    return {
        "id": path.stem,
        "status": status,
        "title": fm.get("title", path.stem),
        "priority": priority if isinstance(priority, str) else "",
        "tags": tags,
        "hold": "hold" in tags,
        "owner": fm.get("owner") or "",
        "claimed_at": fm.get("claimed_at") or "",
        "created": fm.get("created") or "",
        "updated": fm.get("updated") or "",
        "tldr": tldr(body),
        "path": str(path),
    }


def sort_key(item: dict) -> tuple:
    """Order by status group, then priority, then id.

    A blank priority sorts with med rather than below low: triage infers one
    for it later, so it is unranked, not deprioritized.
    """
    return (STATUS_ORDER.get(item["status"], len(STATUS_ORDER)), PRIORITY_ORDER.get(item["priority"], 1), item["id"])


def cmd_list(args, root: Path) -> None:
    """Default to inbox + wip; done only when --status done asks for it.

    SKILL.md runs this in its Current state block, so it executes on every
    invocation. Including done would put the whole archive into context each
    time, which is what splitting done into year-month directories avoids.
    """
    statuses = [args.status] if args.status else [WIP, INBOX]
    items = [summarize(st, p) for st in statuses for _, p in all_files(root, st)]
    if not args.include_hold:
        # hold means "not now" inside inbox; something already claimed stays visible.
        items = [i for i in items if not (i["status"] == INBOX and i["hold"])]
    items.sort(key=sort_key)

    if args.json:
        print(json.dumps(items, ensure_ascii=False, indent=2))
        return
    if not items:
        print("(該当なし)")
        return
    for i in items:
        owner = f" @{i['owner']}" if i["owner"] else ""
        hold = " [hold]" if i["hold"] else ""
        pri = i["priority"] or "-"
        print(f"{i['id']}  [{i['status']}]{hold} {pri:<4}{owner}  {i['title']}")
        if i["tldr"]:
            print(f"    {i['tldr']}")


# --------------------------------------------------------------------------
# State transitions
# --------------------------------------------------------------------------


def move(src: Path, dst: Path) -> bool:
    """Move atomically. Returns False if the source is gone (lost the race)."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.rename(src, dst)
        return True
    except OSError:
        return False


def cmd_claim(args, root: Path) -> None:
    """inbox -> wip. Whether this rename succeeds or fails is the exclusion.

    Without --id, candidates are tried in priority order until one succeeds.
    When multiple agents race for the same top-priority issue, the loser
    automatically falls through to the next candidate, so callers don't need
    their own retry loop.
    """
    who = agent_name(args.agent)

    if args.id:
        st, path = find_one(root, args.id)
        if st != INBOX:
            sys.exit(f"error: {path.stem} は {st} にあります（claim できるのは inbox のみ）")
        candidates = [path]
    else:
        items = [summarize(INBOX, p) for _, p in all_files(root, INBOX)]
        items = [i for i in items if not i["hold"]]
        items.sort(key=sort_key)
        candidates = [Path(i["path"]) for i in items]

    for src in candidates:
        dst = bucket(root, WIP) / src.name
        if not move(src, dst):
            continue  # a competing agent claimed it first
        # owner is written after the rename succeeds; if this crashes, reap picks it up later.
        set_fields(dst, owner=who, claimed_at=stamp(), updated=today())
        append_log(dst, f"- {today()} claim: {who}")
        print(json.dumps(summarize(WIP, dst), ensure_ascii=False) if args.json else dst)
        print(GIT_HINT, file=sys.stderr)  # stderr so --json output stays machine-readable
        return

    sys.exit("error: claim できる issue がありません")


def cmd_release(args, root: Path) -> None:
    """wip -> inbox. Used when giving up on an in-progress issue."""
    st, path = find_one(root, args.id)
    if st != WIP:
        sys.exit(f"error: {path.stem} は {st} にあります")
    dst = bucket(root, INBOX) / path.name
    if not move(path, dst):
        sys.exit("error: 移動に失敗しました")
    set_fields(dst, owner=None, claimed_at=None, updated=today())
    append_log(dst, f"- {today()} release: {args.reason or '着手を中断'}")
    print(dst)


def cmd_done(args, root: Path) -> None:
    """inbox|wip -> done/YYYY-MM/.

    Releasing hold, writing the note, logging, and moving are one call
    because a separate sequence of commands could leave only some of them
    applied. The note's content can only come from conversation context, so
    this script never generates it -- it only copies what it is handed.
    """
    st, path = find_one(root, args.id)
    if st == DONE:
        sys.exit(f"error: {path.stem} は既に done です")

    fm, _, _ = parse(path)
    tags = tag_list(fm)
    if "hold" in tags:  # closing an issue overrides "not now"
        set_fields(path, tags="[" + ", ".join(t for t in tags if t != "hold") + "]")
        append_log(path, f"- {today()} unhold: done に向けて解除")

    text = read_text_arg(None if args.note == "-" else args.note) if args.note is not None else ""
    if text.strip():
        write_section(path, args.section, text, replace=False)
    # Logged whether or not a note was given, so the closing shows up in the
    # timeline like claim / release / reap do. The headline is the note's own
    # first line, not a generated summary of it.
    headline = text.split("\n", 1)[0].strip()
    append_log(path, f"- {today()} done: {headline}" if headline else f"- {today()} done")

    dst = bucket(root, DONE) / datetime.now().strftime("%Y-%m") / path.name
    if not move(path, dst):
        sys.exit("error: 移動に失敗しました")
    set_fields(dst, owner=None, claimed_at=None, updated=today())
    print(dst)
    print(GIT_HINT, file=sys.stderr)


def cmd_reap(args, root: Path) -> None:
    """Return abandoned wip issues to inbox.

    Reclaims issues left held by an agent that crashed. Staleness is the
    later of claimed_at and mtime: log / note / set all rewrite updated and
    so move mtime, and an agent still recording progress must not be
    reclaimed out from under itself. mtime alone covers a crash mid-claim,
    where claimed_at was never written.
    """
    limit = datetime.now() - parse_duration(args.stale)
    reaped = []
    for _, path in all_files(root, WIP):
        fm, _, _ = parse(path)
        claimed = parse_stamp(fm.get("claimed_at", ""))
        mtime = datetime.fromtimestamp(path.stat().st_mtime)
        at = max(claimed, mtime) if claimed else mtime
        if at > limit:
            continue
        if args.dry_run:
            reaped.append(path.stem)
            continue
        dst = bucket(root, INBOX) / path.name
        if move(path, dst):
            set_fields(dst, owner=None, claimed_at=None, updated=today())
            append_log(dst, f"- {today()} reap: {args.stale} 以上放置されたため inbox へ戻した")
            reaped.append(dst.stem)

    print(json.dumps(reaped, ensure_ascii=False) if args.json else ("\n".join(reaped) or "(回収対象なし)"))


# --------------------------------------------------------------------------
# Filing
# --------------------------------------------------------------------------


def cmd_new(args, root: Path) -> None:
    """Allocate an id and file a new issue from the template.

    id = YYYYMMDD-slug. Same-day slug collisions get -2, -3 suffixes.
    Collision checking is done here rather than by the LLM to avoid extra
    Read calls. --body writes the whole body in the same call, so nothing
    else has to rewrite the frontmatter this just produced.
    """
    slug = re.sub(r"[^a-z0-9-]+", "-", args.slug.lower()).strip("-")
    if not slug:
        sys.exit("error: slug が空です")

    existing = {p.stem for _, p in all_files(root)}
    base = f"{today()}-{slug}"
    issue_id = base
    for n in range(2, 100):
        if issue_id not in existing:
            break
        issue_id = f"{base}-{n}"

    tpl_path = Path(args.template).expanduser() if args.template else TEMPLATE_PATH
    if not tpl_path.exists():
        sys.exit(f"error: テンプレートが見つかりません: {tpl_path}")
    text = tpl_path.read_text(encoding="utf-8")
    title = json.dumps(args.title, ensure_ascii=False)  # quoted so a "#" in it isn't read as a comment
    for k, v in {"{id}": issue_id, "{title}": title, "{created}": today(), "{updated}": today()}.items():
        text = text.replace(k, v)

    if args.body is not None:
        # Keep the frontmatter this just filled in and replace only what follows,
        # so the caller never has to rewrite `---` blocks by hand.
        m = FM_RE.match(text)
        if not m:
            sys.exit(f"error: テンプレートに frontmatter がありません: {tpl_path}")
        body = read_text_arg(None if args.body == "-" else args.body)
        text = f"---\n{m.group(1)}\n---\n\n{body.strip()}\n"

    dst = bucket(root, INBOX) / f"{issue_id}.md"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding="utf-8")
    if args.priority:
        set_fields(dst, priority=args.priority)
    if args.body is not None and not LOG_HEADING_RE.search(text):
        # A body given without a log section would leave mtime as the only
        # trace that the issue was filed.
        append_log(dst, f"- {today()} created")
    print(dst)


def read_text_arg(value: str | None) -> str:
    """Read from stdin when no argument is given.

    Passing long prose as a shell argument invites quoting mistakes, so
    notes and section bodies can be piped in via heredoc instead.
    """
    if value is not None:
        return value
    if sys.stdin.isatty():
        sys.exit("error: 本文を引数か標準入力で渡してください")
    return sys.stdin.read().strip()


def cmd_set(args, root: Path) -> None:
    """The only entry point for rewriting frontmatter.

    Letting the LLM touch frontmatter via Edit risks indentation drift or
    duplicated `---` markers that this parser can no longer read. Structured
    field edits are centralized here; SKILL.md's convention is to never Edit
    frontmatter directly.
    """
    _, path = find_one(root, args.id)
    fm, _, _ = parse(path)

    changes: dict = {}
    if args.title:
        changes["title"] = json.dumps(args.title, ensure_ascii=False)
    if args.priority:
        changes["priority"] = args.priority

    if args.add_tag or args.rm_tag:
        tags = [t for t in tag_list(fm) if t not in (args.rm_tag or [])]
        for t in args.add_tag or []:
            if t not in tags:
                tags.append(t)
        changes["tags"] = "[" + ", ".join(tags) + "]"

    if not changes:
        sys.exit("error: 変更内容が指定されていません")

    set_fields(path, **changes)
    touch(path)
    print(path)


def cmd_log(args, root: Path) -> None:
    """Append a dated line to the log section, for recording progress."""
    _, path = find_one(root, args.id)
    append_log(path, f"- {today()} {read_text_arg(args.text)}")
    touch(path)
    print(path)


def cmd_note(args, root: Path) -> None:
    """Write into a body section. Appends by default; --replace overwrites.

    The initial body goes in through `new --body`, so this is for adding
    findings to an issue that already exists.
    """
    _, path = find_one(root, args.id)
    write_section(path, args.section, read_text_arg(args.text), args.replace)
    touch(path)
    print(path)


def cmd_check(args, root: Path) -> None:
    """Validate every issue's frontmatter.

    Catches damage from a stray Edit here, before it surfaces during triage,
    and doubles as the gate for migrating an existing issues/ tree onto this
    layout.
    """
    bad = []
    for st, path in all_files(root):
        fm, raw, _ = parse(path)
        if not raw:
            bad.append(f"{path}: frontmatter がありません")
            continue
        for key in ("id", "title", "created"):
            if not fm.get(key):
                bad.append(f"{path}: {key} がありません")
        if fm.get("id") and fm["id"] != path.stem:
            bad.append(f"{path}: id ({fm['id']}) がファイル名と一致しません")
        # An unset priority parses as [] (a valueless key assumes a block list follows).
        pri = fm.get("priority")
        if pri and pri not in VALID_PRIORITIES:
            bad.append(f"{path}: priority が不正です: {pri}（{'|'.join(VALID_PRIORITIES)} か空）")
        for t in tag_list(fm):
            if not TAG_RE.fullmatch(t):
                bad.append(f"{path}: tag が不正です: {t}")
        if st == WIP and not fm.get("owner"):
            bad.append(f"{path}: wip なのに owner がありません")
        if st != WIP:
            # Key presence, not truthiness: a leftover `owner:` with no value parses as [].
            for key in ("owner", "claimed_at"):
                if key in fm:
                    bad.append(f"{path}: {st} なのに {key} が残っています")

    if bad:
        print("\n".join(bad))
        sys.exit(1)
    print("ok")


def cmd_init(args, root: Path) -> None:
    """Create issues/. The point is to stop searching and use the cwd.

    Reusing the upward-search logic for init would grab a parent's issues/
    if one exists, creating it somewhere other than where the caller meant.
    A parent copy is reported instead, because that is the one every other
    subcommand would have resolved to from here.
    """
    for name in (INBOX, WIP, DONE):
        (root / name).mkdir(parents=True, exist_ok=True)
    print(f"initialized: {root}")
    for d in Path.cwd().resolve().parents:
        if (d / ROOT_NAME / INBOX).is_dir():
            print(
                f"warning: 上位にも {d / ROOT_NAME} があります。置き場所が意図どおりか確認してください", file=sys.stderr
            )
            break


def cmd_path(args, root: Path) -> None:
    """Print the resolved issues/ path, to catch a wrong-location mistake before it happens."""
    print(root)


# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="it", description="issue-tracker ヘルパー")
    sub = p.add_subparsers(dest="cmd", required=True)

    def add(name, fn, help_):
        sp = sub.add_parser(name, help=help_)
        sp.set_defaults(fn=fn)
        return sp

    add("init", cmd_init, "issues/ を作る")
    add("path", cmd_path, "解決した issues/ を表示する")

    sp = add("list", cmd_list, "frontmatter と TL;DR だけを一覧する")
    sp.add_argument("--status", choices=[INBOX, WIP, DONE])
    sp.add_argument("--include-hold", action="store_true")
    sp.add_argument("--json", action="store_true")

    sp = add("new", cmd_new, "起票する")
    sp.add_argument("slug")
    sp.add_argument("--title", required=True)
    sp.add_argument("--priority", choices=["high", "med", "low"])
    sp.add_argument("--template", help=f"既定: {TEMPLATE_PATH}")
    sp.add_argument("--body", nargs="?", const="-", help="本文（frontmatter 以降）。値を省くと標準入力から読む")

    sp = add("claim", cmd_claim, "inbox → wip（原子的に着手する）")
    sp.add_argument("--id", help="省略時は優先度順に自動で選ぶ")
    sp.add_argument("--agent")
    sp.add_argument("--json", action="store_true")

    sp = add("release", cmd_release, "wip → inbox（着手をやめる）")
    sp.add_argument("id")
    sp.add_argument("--reason")

    sp = add("done", cmd_done, "→ done/YYYY-MM/")
    sp.add_argument("id")
    sp.add_argument("--note", nargs="?", const="-", help="完了メモ。値を省くと標準入力から読む")
    sp.add_argument("--section", default="完了メモ", help="完了メモを書く節の名前")

    sp = add("set", cmd_set, "frontmatter を書き換える")
    sp.add_argument("id")
    sp.add_argument("--title")
    sp.add_argument("--priority", choices=["high", "med", "low"])
    sp.add_argument("--add-tag", action="append", metavar="TAG")
    sp.add_argument("--rm-tag", action="append", metavar="TAG")

    sp = add("log", cmd_log, "ログに1行足す")
    sp.add_argument("id")
    sp.add_argument("text", nargs="?")

    sp = add("note", cmd_note, "本文の節に書き込む")
    sp.add_argument("id")
    sp.add_argument("section")
    sp.add_argument("text", nargs="?")
    sp.add_argument("--replace", action="store_true", help="追記でなく差し替える")

    add("check", cmd_check, "frontmatter の破損を検査する")

    sp = add("reap", cmd_reap, "放置された wip を inbox に戻す")
    sp.add_argument("--stale", default="60m")
    sp.add_argument("--dry-run", action="store_true")
    sp.add_argument("--json", action="store_true")

    return p


def main() -> None:
    args = build_parser().parse_args()
    args.fn(args, find_root(create=args.cmd == "init"))


if __name__ == "__main__":
    main()
