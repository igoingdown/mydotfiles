"""Install an immutable release while preserving the legacy domain import API."""
from __future__ import annotations

import ast
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

from .common import ReportError, atomic_json, safe_event
from .pipeline import Arguments, run_lock


def _write(path, content, mode=0o700):
    fd, temporary = tempfile.mkstemp(prefix="." + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _guard(tree):
    guards = []
    for node in tree.body:
        if isinstance(node, ast.If):
            test = node.test
            if (isinstance(test, ast.Compare) and isinstance(test.left, ast.Name) and test.left.id == "__name__"
                    and len(test.ops) == 1 and isinstance(test.ops[0], ast.Eq) and len(test.comparators) == 1
                    and isinstance(test.comparators[0], ast.Constant) and test.comparators[0].value == "__main__"):
                guards.append(node)
    if len(guards) != 1 or guards[0] is not tree.body[-1] or guards[0].orelse:
        raise ReportError("LegacyEntryUnsupported")
    return guards[0]


def _dispatch(entry, config, mode):
    # repr builds Python literals; these paths never go through shell parsing.
    return ("    import runpy as _report_runpy\n    import sys as _report_sys\n"
            f"    _report_sys.path.insert(0, {str(entry.parent)!r})\n"
            f"    _report_sys.argv = [{str(entry)!r}, '--config', {str(config)!r}, '--mode', {mode!r}] + _report_sys.argv[1:]\n"
            f"    _report_runpy.run_path({str(entry)!r}, run_name='__main__')\n")


def domain_entry(original, entry, config):
    try:
        text = original.decode("utf-8")
        tree = ast.parse(text)
        guard = _guard(tree)
        lines = text.splitlines(keepends=True)
        result = "".join(lines[:guard.lineno]) + _dispatch(entry, config, "halfday")
        compile(result, "domain-entry", "exec")
        # No imported function, constant or initialization statement may change.
        updated = ast.parse(result)
        if ast.dump(ast.Module(body=tree.body[:-1], type_ignores=[])) != ast.dump(ast.Module(body=updated.body[:-1], type_ignores=[])):
            raise ReportError("LegacyEntryUnsupported")
        return result.encode("utf-8")
    except (UnicodeError, SyntaxError):
        raise ReportError("LegacyEntryUnsupported") from None


def daily_entry(entry, config):
    text = f"#!{sys.executable}\n# Installed numeric slow-query report entry.\nif __name__ == '__main__':\n" + _dispatch(entry, config, "daily")
    compile(text, "daily-entry", "exec")
    return text.encode("utf-8")


def _disabled_domain(original):
    text = original.decode("utf-8")
    guard = _guard(ast.parse(text))
    return ("".join(text.splitlines(keepends=True)[:guard.lineno]) +
            "    print('{\"event\":\"ReportDisabled\",\"category\":\"InstallFailure\"}')\n    raise SystemExit(1)\n").encode("utf-8")


def install(source, *, config, state_dir, release_dir, daily_path, domain_path):
    source, config, state_dir, release_dir, daily_path, domain_path = map(Path, (source, config, state_dir, release_dir, daily_path, domain_path))
    if any(not p.is_absolute() for p in (source, config, state_dir, release_dir, daily_path, domain_path)) or daily_path == domain_path:
        raise ReportError("InvalidInstallArguments")
    with run_lock(state_dir):
        originals = {p: p.read_bytes() for p in (daily_path, domain_path)}
        sources = {Path("slowquery_daily.py"): (source / "slowquery_daily.py").read_bytes()}
        sources.update({Path("slowquery_report") / p.name: p.read_bytes()
                        for p in (source / "slowquery_report").glob("*.py") if not p.name.startswith("test_")})
        if len(sources) < 6:
            raise ReportError("InvalidRelease")
        digest = hashlib.sha256()
        for name, content in sorted(sources.items()):
            compile(content, str(name), "exec")
            digest.update(str(name).encode() + b"\0" + content + b"\0")
        release = release_dir / digest.hexdigest()[:20]
        release.mkdir(parents=True, exist_ok=True, mode=0o700)
        for name, content in sources.items():
            target = release / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            if target.exists():
                if target.read_bytes() != content:
                    raise ReportError("ReleaseChanged")
            else:
                _write(target, content, 0o600)
        entry = release / "slowquery_daily.py"
        replacements = {daily_path: daily_entry(entry, config), domain_path: domain_entry(originals[domain_path], entry, config)}
        backup = state_dir / "entry-backups" / digest.hexdigest()[:20]
        backup.mkdir(parents=True, exist_ok=True, mode=0o700)
        for index, (path, content) in enumerate(originals.items()):
            target = backup / (str(index) + ".py")
            if not target.exists():
                _write(target, content, 0o600)
            if path.read_bytes() != content:
                raise ReportError("EntryChanged")
        try:
            for path, content in replacements.items():
                if path.read_bytes() != originals[path]:
                    raise ReportError("EntryChanged")
                _write(path, content)
        except Exception:
            # Old entry backups are for compatibility/reference. Never put the
            # previous SQL-fetching main back into scheduled execution on error.
            disabled = (f"#!{sys.executable}\nprint('{{\"event\":\"ReportDisabled\",\"category\":\"InstallFailure\"}}')\nraise SystemExit(1)\n").encode()
            failures = 0
            for target, stopped in ((daily_path, disabled), (domain_path, _disabled_domain(originals[domain_path]))):
                try:
                    _write(target, stopped)
                except Exception:
                    # A permanently unwritable entry must not prevent stopping
                    # the independent, writable entry as well.
                    failures += 1
            if failures:
                safe_event("InstallDisableFailed", failed=failures)
            raise ReportError("InstallFailure") from None
        atomic_json(state_dir / "installed.json", {"schema_version": 1, "release": str(release),
                    "daily_entry": str(daily_path), "domain_entry": str(domain_path), "config": str(config)})
        safe_event("ReportInstalled", verified=True)
        return release


def main(argv=None):
    os.umask(0o077)
    parser = Arguments(description="Replace existing report entry points; keep cron timing and import APIs.")
    for name in ("config", "state-dir", "release-dir", "daily-path", "domain-path"):
        parser.add_argument("--" + name, type=Path, required=True)
    try:
        args = parser.parse_args(argv)
        install(Path(__file__).resolve().parents[1], **vars(args))
        return 0
    except ReportError as error:
        safe_event("InstallFailed", category=error.category)
        return 1
    except Exception:
        safe_event("InstallFailed", category="UnexpectedFailure")
        return 1
