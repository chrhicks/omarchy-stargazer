#!/usr/bin/env python3
"""Prepare an isolated Qt replay of the real panel, without changing the desktop."""

import argparse
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def copy_plugin(source, output):
    plugin = output / "plugin"
    plugin.mkdir(parents=True, exist_ok=True)
    for pattern in ("*.qml", "*.js"):
        for path in source.glob(pattern):
            shutil.copy2(path, plugin / path.name)
    shutil.copytree(source / "vendor", plugin / "vendor", dirs_exist_ok=True)
    # Only host process/clock imports change. UI, handlers and models stay intact.
    for path in plugin.glob("*.qml"):
        original = path.read_text()
        adapted = original.replace("import Quickshell\n", "")
        adapted = adapted.replace("import Quickshell.Io\n", 'import "../Host"\n')
        path.write_text(adapted)


def prepare_fixture(source, output, moves, scale, chart):
    output.mkdir(parents=True, exist_ok=True)
    copy_plugin(source, output)
    shutil.copytree(source / "tests/mocks", output, dirs_exist_ok=True)
    key_catcher = Path("/usr/share/omarchy/shell/Ui/PanelKeyCatcher.qml")
    shutil.copy2(key_catcher, output / "qs/Ui/PanelKeyCatcher.qml")
    shutil.copy2(source / "tests/tst_panel.qml", output / "tst_profile.qml")
    shutil.copy2(source / "tests/tst_location.qml", output / "tst_location.qml")
    shutil.copy2(source / "tests/ForecastFixture.js", output / "ForecastFixture.js")
    settings = f"""import QtQuick
QtObject {{
  property int moves: {moves}
  property real scale: {scale}
  property string chart: {json.dumps(chart)}
  property string outputDirectory: {json.dumps(str(output.resolve()))}
}}
"""
    (output / "ProfileSettings.qml").write_text(settings)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path, default=Path("/tmp/stargazer-panel-profile"))
    parser.add_argument("--moves", type=int, default=600)
    parser.add_argument("--scale", type=float, default=1.4)
    parser.add_argument("--chart", choices=("cloud", "sky"), default="cloud")
    args = parser.parse_args()
    if args.moves < 30 or not 0 < args.scale <= 3:
        parser.error("Use at least 30 moves and a scale between 0 (exclusive) and 3")
    prepare_fixture(args.source, args.out, args.moves, args.scale, args.chart)
    print(args.out)


if __name__ == "__main__":
    main()
