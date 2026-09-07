#!/usr/bin/env python3
"""Check authored code, model behavior, and both full-panel drag surfaces."""

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QT_ENV = {
    **os.environ,
    "QT_QPA_PLATFORM": "offscreen",
    "QT_QUICK_BACKEND": "software",
    "QT_QPA_PLATFORMTHEME": "",
    "QT_STYLE_OVERRIDE": "Fusion",
}


def tool(name):
    override = os.environ.get(name.upper())
    executable = override or shutil.which(name)
    if executable:
        return executable
    qt_executable = Path("/usr/lib/qt6/bin") / name
    if qt_executable.is_file():
        return str(qt_executable)
    raise SystemExit(f"Missing {name}; install the development tool or set {name.upper()} to its path")


def run(command, **kwargs):
    print("+ " + " ".join(str(argument) for argument in command), flush=True)
    return subprocess.run(command, cwd=ROOT, env=QT_ENV, check=True, **kwargs)


def format_qml(write):
    files = sorted(ROOT.glob("*.qml")) + sorted(ROOT.glob("*.js"))
    files += sorted((ROOT / "tests").rglob("*.qml")) + sorted((ROOT / "tests").glob("*.js"))
    formatter = tool("qmlformat")
    for path in files:
        if write:
            run([formatter, "--inplace", path])
            continue
        result = run([formatter, path], capture_output=True, text=True)
        if result.stdout != path.read_text():
            raise SystemExit(f"Formatting differs: {path.relative_to(ROOT)}; run tools/check.py --format")


def lint_qml(imports):
    host = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell"
    (imports / "qs").symlink_to(host, target_is_directory=True)
    files = sorted(ROOT.glob("*.qml")) + sorted(ROOT.glob("*.js"))
    run([tool("qmllint"), "-I", imports, "-W", "0", *files])


def replay_panel(output, chart):
    run([tool("python3"), ROOT / "tools/profile-panel.py", "--out", output, "--chart", chart])
    run([tool("qmltestrunner"), "-import", output, "-input", output / "tst_profile.qml"], timeout=30)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", action="store_true", help="Apply formatters before checking")
    args = parser.parse_args()
    format_qml(args.format)
    ruff = tool("ruff")
    biome = tool("biome")
    run([ruff, "format", *([] if args.format else ["--check"]), "."])
    run([ruff, "check", "."])
    run([biome, "check", *(["--write"] if args.format else []), "tests"])
    run([tool("python3"), "-m", "unittest", "discover", "-s", "tests", "-v"])
    run([tool("node"), "--test", "tests/forecast-model.cjs", "tests/cloud-field.cjs"])
    with tempfile.TemporaryDirectory(prefix="stargazer-check-") as temporary:
        directory = Path(temporary)
        lint_qml(directory)
        replay_panel(directory / "cloud", "cloud")
        replay_panel(directory / "sky", "sky")
    run([tool("omarchy"), "plugin", "validate", ROOT])


if __name__ == "__main__":
    main()
