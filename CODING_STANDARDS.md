# Coding standards

Write for a mid-level engineer who knows JavaScript and is new to this plugin. They should be able to trace a user action, find the code to change, and understand its consequences without reading the project's history.

## Readability and responsibility

- Use domain names: selected hour, viewport start, cloud coverage, cache age. Reserve short coordinate names for local drawing math.
- Give each component or function one recognizable responsibility. Extract around a concept, not a line count; avoid generic helpers that merely move complexity elsewhere.
- Prefer guard clauses and named intermediate values to nested branches or nested ternaries. Treat Biome's cognitive-complexity limit of 15 as a review threshold, not proof that a function is understandable.
- Pass component inputs through properties and results through signals. Keep the main panel responsible for selection, refresh, and host integration. Drawing components do not fetch data or mutate selection.
- Use explicit persistent controls for fixed readings. Avoid positional coupling between a data array and several UI groups.
- Comments explain a constraint or a non-obvious reason. Names and structure should explain ordinary control flow. Keep diagrams and incident reports out of the implementation's critical reading path.

## Formatting and tools

- Use the checked-in formatter configurations: qmlformat for QML/QML JavaScript, Ruff for Python, and Biome for Node test files. Do not reformat vendored SunCalc.
- QML and JavaScript use two spaces; Python uses four. Expand multiple statements onto separate lines. Prefer `const`, then `let`; QML-imported script state uses top-level `var` where it must be exposed to QML.
- Declare component inputs and signals explicitly. Bind inline components to their owning context with `pragma ComponentBehavior: Bound` when they reference outer IDs.
- Host APIs sometimes expose dynamic QtObject members. Keep that dynamic typing at the host boundary rather than disabling missing-property warnings globally.
- `python3 tools/check.py` checks formatting, lint, model tests, and both full-panel drag replays. Use `--format` to apply the configured formatters first. Development tool paths can be supplied through `RUFF`, `BIOME`, and the corresponding uppercase Qt tool names.

Biome cannot directly lint QML or QML's `.import` syntax. Its complexity rule is enforced for Node tests and serves as a review reference for QML handlers and helpers. `qmllint` checks the actual QML and imported JavaScript; Ruff's separate Python complexity check measures branching, not cognitive complexity.

## Behavior and performance

- Keep forecast values, calculated astronomy, and illustrative rendering distinct. Missing values remain missing.
- Validate external data before replacing a usable report. Catch expected I/O and data errors at their boundary; do not hide unrelated programming errors behind a generic failure message.
- Prepare astronomy per report. Reuse the cloud image, keep controls alive while scrubbing, and consume only the latest pointer position. Closing a panel must discard pending navigation.
- Test observable behavior with real component code. Mock host surfaces and network boundaries; do not rewrite handlers to make them testable.
- For rendering or interaction refactors, compare images and run the complete panel. Passing model tests alone says nothing about shared-shell responsiveness.

References: [Biome cognitive complexity](https://biomejs.dev/linter/rules/no-excessive-cognitive-complexity/javascript/), [Qt component scopes](https://doc.qt.io/qt-6/qtqml-documents-structure.html#componentbehavior), [qmllint](https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html).
