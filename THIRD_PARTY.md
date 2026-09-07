# Attribution

Stargazer's original code is MIT-licensed; see LICENSE.

## SunCalc 1.9.0

Copyright Vladimir Agafonkin. Distributed under the BSD 2-Clause license, retained in `vendor/SUNCALC-LICENSE`.

Source: https://github.com/mourner/suncalc/tree/v1.9.0

The vendored script keeps the original astronomical calculations. Its enclosing browser/module wrapper and export footer were removed so QML can import the script-level SunCalc object. No numerical formulas were changed. Approximate Sun/Moon positions support a desktop forecast display; they are not mount-control ephemerides.

## Forecast data

Weather is supplied by https://open-meteo.com/ under CC BY 4.0, subject to the provider's free-service usage terms. Attribution is shown in the panel. The plugin requests the location selected by its user, using the public forecast endpoint; it does not use Astrospheric data.

Documentation: https://open-meteo.com/en/docs
Terms: https://open-meteo.com/en/terms
License: https://creativecommons.org/licenses/by/4.0/

## Omarchy

The plugin imports the installed Omarchy shared UI components. They remain part of the host installation. Omarchy's documented bar/panel lifecycle was used as an integration reference; no packaged shell component is redistributed here.

## Place search

Place-name search uses Open-Meteo's geocoding API, whose location data is based on GeoNames. Attribution is shown in the location form. Search is explicit and optional; manual coordinate entry does not use geocoding.

Documentation: https://open-meteo.com/en/docs/geocoding-api
GeoNames attribution: https://www.geonames.org/
