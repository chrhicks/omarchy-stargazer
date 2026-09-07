# Release verification — 0.1.0

Verified on 7 September 2026 with Omarchy 4.0.2, Qt 6.11.2, and two 3840×2160 monitors at 1.5× desktop scale. This is the tested environment, not a claim of compatibility with every Omarchy or Qt release.

## Automated checks

`python3 tools/check.py` passes QML formatting and zero-warning lint against the installed host, Ruff, Biome, nine Python tests, JavaScript forecast/cloud tests, manifest validation, and both full-panel Qt replays.

Each chart replay passes 13 Qt results including setup/cleanup. Coverage includes 600 drag moves, cancellation and closing during drag, click parity, hour boundaries, Now, refresh preserving selection, malformed data preserving the last good forecast, and persistent reading controls. The release sky replay's worst input gap was 13 ms; this is a synthetic software-renderer measurement, not a frame-rate guarantee.

First-run checks verify no process starts without valid coordinates, setup guidance is visible, and valid location settings start the forecast command. Saved forecasts have an explicit status and tooltip label. Python tests exercise missing values, DST, cache/cooldown behavior, failed refreshes, invalid coordinates, and oversized responses without contacting the provider.

## Visual and host checks

- Native forecast loading and panel placement inspected with top, bottom, left, and right bars. Alternate positions were restored after testing.
- Native panel routing inspected on both monitors; the shell responded after each check.
- Native scrubbing has positive user confirmation. Offscreen replays exercise both chart surfaces using the actual panel components.
- Dark and light color combinations inspected using the actual panel with isolated host stubs. A live desktop-wide theme switch is not part of this check.
- `preview.png` is an offscreen rendering of the real panel using a real Open-Meteo forecast for the public Greenwich Observatory location, retrieved on 7 September 2026. Host process/clock objects are stubbed; the screenshot shows a selected future hour. It contains no personal desktop capture.

## Installation lifecycle

The normal `omarchy plugin add https://github.com/chrhicks/omarchy-stargazer --enable` path was exercised against the public repository. A fresh installation displayed location setup guidance in the native panel. The up-to-date update path passed. Removal deleted the Git checkout and preserved unrelated shell settings. Reinstallation passed, and the original widget settings were restored exactly.

The final documentation commit is also used to exercise a real fast-forward through `omarchy plugin update` before tagging. No installation script or privileged setup is required; users configure their own location after enabling the widget.

## Compatibility limits

Monitor hot-unplug, mixed-DPI combinations, other GPUs, native touchpad gesture stealing, and extended soak testing remain outside this release's verified coverage. No map, specialized seeing/transparency forecast, or precise sky-map rendering is provided. Unit buttons change the session view; persistent defaults use widget settings.
