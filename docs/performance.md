# Scrubbing performance

Vigorous scrubbing originally stalled the shared desktop shell. Full-panel profiling isolated repeated control reconstruction and image allocation. The corrected implementation retains controls and image buffers and has positive native interaction confirmation.

## What failed

The earlier interaction fixture exercised the actual drag handler and charts but omitted the scene and detail controls. It proved navigation correctness while missing the expensive interaction between rendering and delegate allocation. A complete-panel replay reproduces the slowdown without touching the running shell.

Two costs compound:

1. The six-reading Repeater used a new JavaScript object array as its model on every chosen hour. Qt destroyed and rebuilt six Columns and twelve inline Copy controls. The Qt trace shows repeated initialization of ForecastModel.js and SunCalc for the recreated components, even though navigation does not call astronomy calculations. The old 30-move trace contains 324 entries for each script; the candidate contains 48, including initial construction. Selection alone consumed 2,991 ms inclusive in the old trace. These nested durations must not be added together.
2. Each cloudy scene paint allocated a new 192×64 CanvasImageData object. Retaining the controls alone was insufficient: a 180-move replay still took 5.9 seconds. Retaining the image buffer as well brought the same workload below a second. Allocation pressure is implicated by these ablations; the precise garbage-collector mechanism has not been separately established.

Qt Canvas defaults to Immediate rendering on the GUI thread. Stargazer lives in the shared shell process, so blocking that thread can delay other shell controls. This explains the shared-shell risk; the isolated trace does not prove that Hyprland itself froze. [Qt Canvas documentation](https://doc.qt.io/qt-6/qml-qtquick-canvas.html).

Qt documents that ordinary JavaScript resources are instantiated per importing component. Moving CloudField alone to a shared `.pragma library` was tested and did not solve the problem, so it is not part of the fix. [JavaScript resources](https://doc.qt.io/qt-6/qtqml-javascript-resources.html).

## Incident-era call and dependency map

This map describes the implementation investigated during the freeze. The later readability refactor separates scene, charts, readings, and pointer input into named QML components; use the source files and README for their current boundaries.

```text
BarWidget Loader (one per host widget / monitor)
  -> Panel creation -> settings injection
  -> latitude/longitude change -> changedLocation -> clear report/forecast
       -> 250 ms reloadTimer -> refresh(false)
  -> click -> host toggle/open; Panel.open -> controller.show + refresh(false)
  -> middle click / R / Refresh -> refresh(true)
  -> 30-minute timer -> refresh(false)

refresh (configured + !fetcher.running)
  -> Quickshell Process -> python3 forecast.py
     -> validate coordinates -> per-location flock -> read_cache
     -> fresh cache / manual cooldown: reuse
     -> otherwise HTTPS Open-Meteo (12-second request timeout, bounded response)
        -> validate -> atomic write_cache; failure -> last-good or explicit error
     -> present -> timezone labels + three observing nights -> JSON stdout
  -> streamFinished -> JSON.parse -> prepareForecast (once per report)
     -> enrich each night -> sky for hourly rows
        -> SunCalc getPosition / getMoonPosition / getMoonIllumination
     -> getPosition at one-minute intervals for dark spans
     -> sky at half-hour intervals for chart tracks
     -> select previous time or current hour -> enable viewport animation later

cloud timeline MouseArea
  -> press: capture pointer, selected timestamp, viewport start
  -> move: drag threshold -> draggedTime -> overwrite ONE pending timestamp
  -> 16 ms Timer while pressed AND opened: consume latest -> selectTime
  -> release: flush latest -> snap to selected hour (or click-to-select)
  -> cancel/close: discard pending; close stops viewport animation

keyboard Left/Right -> stepHour -----------------------+
keyboard Up/Down / night tabs -> selectNight ----------+-> selectTime
Now / N -> currentHour -> selectTime ------------------+   -> clamp timestamp
   (missing current data -> refresh)                  |   -> nearest (linear ~72 rows)
moon chart click -> timelineIndex -> nearest ----------+   -> selected
                                                          -> windowStart -> viewStart
selected -> chosen -> text / detail values / nightIndex / scene annotations
                  -> repaintSky (only opened): request 3 Canvas paints
viewStart -> night viewport + cursor + chart mapping
          -> request cloud + sky chart paints (only opened)
          -> 220 ms animation for discrete navigation; disabled during drag

skyScene paint -> daylight + 130 deterministic stars + Moon marker
               -> Clouds.paint -> prepare field ONCE
                  -> fractal -> noise -> hash/smooth
               -> reuse one RGBA image per context -> opacity + pixel loop
               -> Qt drawImage / compositing
cloudTimeline paint -> cloudCurve (~72 rows, bounded cubic segments)
                    -> timelineX -> clipped path + hourly ticks + cursor
skyChart paint -> cached dark spans + ~145 half-hour track samples
               -> timelineX -> clipped Sun/Moon paths + cursor

SystemClock (minute) -> currentHour + stale + tooltip (independent of selection)
unit toggles -> formatted reading values and tooltip
ink/accent changes -> repaintSky; width changes -> Canvas repaint
close / Escape / host panel switch -> controller -> opened=false
```

There are no network requests, subprocess launches, or fresh astronomy calculations in the drag path. The Python lock can wait behind another monitor's request, but it runs outside the GUI process. Each monitor still owns a forecast/model instance; cache locking prevents duplicate simultaneous fetches for the same location. Refresh preparation remains synchronous in QML (10–12 ms in these synthetic runs), and cold cloud-field preparation is noticeably more expensive than warm paints. Neither occurs per pointer move.

The cloud curve currently allocates small segment objects each chart paint. It measured at most 1 ms at p95 here; caching it or adding workers is not justified by this trace. Current-hour lookup scans a small report once per clock/report change. Width changes can cause an initial hidden Canvas callback, but a settled closed panel performs no repeated navigation paints in the fixture.

## Changes

- Keep the six detail delegates alive with a fixed numeric Repeater model; update their reading bindings.
- Retain the cloud image for its Canvas context and overwrite all pixels. Read QColor channels outside the pixel loop. Keep context ownership local to the component.
- Coalesce pointer positions into one latest value at a 16 ms cadence. This bounds application work; it cannot make the OS input queue disappear if unrelated GUI work blocks the thread.
- Remove the duplicate selected-change repaint (chosen already handles it).
- Gate selection-triggered paints on visibility; discard pending drag on cancel/close, stop animation, reject late releases while closed, repaint on reopening.

No reduced cloud resolution or appearance change is included. All 12 before/after PNGs (clear/15%/50%/overcast × night/twilight/day) were byte-identical.

## Measurements

Qt 6.11.2, offscreen software backend, synthetic three-night forecast, full actual Panel.qml with minimal host stubs, 1.4× spacing (~1064 px panel). Input replays use sine-wave pointer movement with Qt test waits, so elapsed time includes input scheduling. Millisecond timers limit small-duration precision. Each row is a separate bounded run, not a statistical benchmark suite.

| Workload / change | Elapsed input replay | Worst input gap |
|---|---:|---:|
| Original full panel, 30 moves, profiler | 3,846 ms | 282 ms |
| Original full panel, 180 moves | exceeded 15 s timeout | — |
| Scene omitted, 180 moves | 513 ms | 6 ms |
| Cloud pixel work omitted, 180 moves | 594 ms | 9 ms |
| Detail controls omitted, 30 moves | 138 ms | 17 ms |
| Stable controls only, 180 moves | 5,864 ms | 93 ms |
| Stable controls + retained image, 180 moves | 821 ms | 16 ms |
| Final coalesced candidate, 30 moves, profiler | 111 ms | 11 ms |
| Candidate, 1,800 moves | 5,818 ms | 12 ms |
| Candidate, 6,000 moves | 19,780 ms | 14 ms |
| Candidate + second closed panel, 600 moves | 2,003 ms | 12 ms |

The 6,000-move run had warm scene p95 4 ms / maximum 6 ms and selection p95 ≤1 ms. The complete process including warmup and lifecycle tests used 9.58 user CPU seconds, 0.40 system seconds, and peak RSS 181,320 KiB over ~22.6 seconds. This establishes bounded behavior for that run, not zero cost or a long-term memory-leak result. Profiling instrumentation itself retains timing samples.

Regression assertions pass: exactly six detail creations and one cloud-image allocation in the active panel; zero additional Canvas callbacks in the second closed panel after warmup; no viewport changes after settling; close during drag discards pending work; late release does not change selection; hidden selection causes no scene paint; reopening repaints; explicit cancellation clears pending; animated night shortcut reaches its target. Synthetic canceled() checks the handler; native Flickable gesture stealing still needs human testing.

## Reproduce without touching the desktop

Requires installed Qt Quick Test, Python 3, and the Omarchy PanelKeyCatcher source. The current fixture copies actual runtime components, substitutes only process/clock imports, and uses Qt SignalSpy for navigation and paint counts. It no longer rewrites handler bodies. Host processes are inert; no provider request is possible. Style metrics approximate native geometry.

```sh
python3 tools/profile-panel.py --out /tmp/stargazer-panel-profile --moves 600 --scale 1.4 --chart sky
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME= QT_STYLE_OVERRIDE=Fusion timeout 20 /usr/lib/qt6/bin/qmltestrunner -import /tmp/stargazer-panel-profile -input /tmp/stargazer-panel-profile/tst_profile.qml
```

Use `--moves 6000` with a 40-second timeout for a longer replay, or `--chart cloud` for the other surface. Lifecycle checks always run. The broad 100 ms input-gap assertion is a regression threshold, not a frame-time guarantee. The old `--omit` ablations and injected per-function timing arrays belong to the investigation above; the current tests deliberately avoid that fragile transformation. Node tests separately verify cloud-image reuse and context replacement.

Qt's profiler needs a debugging-enabled Quick Test runner. For deeper local inspection, build a temporary main calling `QQmlDebuggingEnabler` then `quick_test_main`, linked with `Qt6QuickTest` and `Qt6Qml`; invoke qmlprofiler with `--include javascript,creating,binding,memory,handlingsignal`. Local debugging IPC may need sandbox permission. Traces are large and are not committed. Count script `%entry` events and inspect selection/Repeater creation stacks; inclusive durations overlap.

## Native verification

The fixed implementation has positive native scrubbing confirmation. See [release verification](release-verification.md) for current coverage and remaining compatibility limits. The measurements above describe isolated software-renderer runs, not every GPU or input device.

## Follow-up: both charts and revised readings

The shared TimeScrubber now handles both plots, with independent latest-input slots and animation disabled while either is pressed. The scanning pass uses thirteen fixed reading delegates, all asserted to be created once. Run the replay with `--chart sky` to exercise the Sun/Moon surface; the default exercises cloud cover. Both pass lifecycle checks, and clicking the same horizontal location selects the same hour. The updated600-move sky replay measured2016ms/maxgap14ms, scene p955ms/max6ms, selection p951ms. These are isolated Qt checks with the revised actual panel. Earlier six-delegate counts above describe the prior layout.

## Readability refactor

The complete panel's synthetic render is pixel-identical to the accepted layout, and all 12 cloud fixtures remain byte-identical after splitting drawing into named operations. Full-panel tests check that the thirteen reading objects survive navigation and that a malformed new report leaves the prior report/forecast intact. Qt lint passes with zero warnings. The scene handler previously scored16 under Biome's cognitive-complexity rule; a one-time check of extracted authored JavaScript functions and block handlers passes the default15 threshold after refactoring. This is not direct Biome support for QML.
