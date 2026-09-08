# Contributing to Stargazer

Stargazer is an independent Omarchy shell plugin for observing-night forecasts. The [README](README.md) describes its features and development commands; [coding standards](CODING_STANDARDS.md) describe the implementation conventions.

## Design and scope

The bar entry is compact, and the panel uses Omarchy's themed typography, keyboard navigation, and panel coordination. Its continuous forecast timeline distinguishes weather measurements, calculated astronomy, and illustrative sky rendering. Generic weather data does not support specialized seeing or transparency scores.

The implementation uses QML, JavaScript, and the Python standard library. Forecast failures preserve the last good forecast. Personal locations, credentials, and caches belong outside the repository.

## Host integration and verification

Host integration changes should be checked against the installed shell's API contracts without modifying packaged Omarchy files. Installation and removal testing must preserve unrelated user settings.

The README documents the checks to run for code changes. Manifest validation, offscreen tests, and native interaction establish different evidence; contribution descriptions should report what was tested and any practical limits.

The maintainer handles public releases and marketplace submissions.
