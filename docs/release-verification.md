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

## 0.1.1 candidate: location setup

The new first-run location form is implemented and installed for local review. The marketplace submission remains on hold pending release review.

- The full checks pass, including 14 Python tests, location-settings JavaScript tests, both 600-move chart replays, and ten Qt location-form results (including setup/cleanup).
- Qt interaction tests click a search result and the manual-coordinate save button, check invalid input, cancel, stale responses and typing without triggering forecast shortcuts. Settings survive panel recreation through a host-settings stub.
- Live Open-Meteo place search was verified with Greenwich and a country-qualified search.
- Native first-run rendering was inspected. A temporary QA widget called the real panel's save method through the native bar; the selected public example location was written by Omarchy's settings writer, survived a shell restart, and loaded a forecast. The QA widget was removed and original user settings restored. This checks the real persistence path separately from the offscreen mouse/keyboard tests.
- Native physical typing/search-result selection remains distinct from these automated tests.

Independent release and security audits found no additional first-run blocker or confirmed security vulnerability. Maintainer-side review reproduced and fixed two usability findings: numpad Enter now selects a search result, and site names beginning with `--` reach the forecast helper unchanged. Regression checks cover Return, numpad Enter, Space, and option-like names through the form and helper argument parser.

### Final candidate pass

The full check suite passed again on the committed candidate. A temporary native QA widget exercised the installed form's real search and selection methods: a live country-qualified place search returned five results, selecting one persisted the location and loaded 72 forecast hours, and a full shell restart preserved the settings and loaded the forecast again. Native hour stepping, returning to Now, canceling location editing, and requesting refresh passed. The restarted forecast was visually inspected. The temporary widget was removed and the prior user settings were restored byte-for-byte, followed by another shell restart.

This native integration pass calls the actual form methods; Qt tests separately exercise mouse and keyboard input. The maintainer also reported that the fresh-start flow worked well on the desktop. No new release or marketplace submission was made.

When resetting a configured installation for first-run testing, restart the shell after clearing widget settings. Plugin rescan alone retained the running panel's old location during testing; a restart displayed the empty setup form. Verify the visible result before declaring the reset complete.
