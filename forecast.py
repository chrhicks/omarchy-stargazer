#!/usr/bin/env python3
"""Fetch an observing forecast and maintain a private, per-location cache."""

import argparse
import fcntl
import hashlib
import json
import math
import os
import tempfile
import time
from datetime import datetime, timedelta
from datetime import time as day_time
from http.client import HTTPException
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen
from zoneinfo import ZoneInfo

FIELDS = (
    "cloud_cover",
    "cloud_cover_low",
    "cloud_cover_mid",
    "cloud_cover_high",
    "temperature_2m",
    "dew_point_2m",
    "wind_speed_10m",
    "wind_gusts_10m",
    "precipitation_probability",
)
TTL = 1800
MANUAL_REFRESH_INTERVAL = 60
REQUEST_TIMEOUT = 12
MAX_RESPONSE_BYTES = 2_000_000
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
DATA_ERRORS = (ValueError, KeyError, TypeError)


def is_finite_number(value):
    return isinstance(value, (int, float)) and math.isfinite(value)


def validate(data):
    """Validate provider arrays and units before using either network or cache data."""
    if not isinstance(data, dict) or data.get("error"):
        raise ValueError("Forecast provider returned no usable data")
    zone = ZoneInfo(data["timezone"])
    hourly = data["hourly"]
    timestamps = hourly["time"]
    if not isinstance(timestamps, list) or not 24 <= len(timestamps) <= 200:
        raise ValueError("Unexpected forecast length")
    if any(not is_finite_number(stamp) for stamp in timestamps):
        raise ValueError("Invalid forecast timestamps")
    if any(later <= earlier for earlier, later in zip(timestamps, timestamps[1:])):
        raise ValueError("Forecast times are out of order")
    for field in FIELDS:
        values = hourly.get(field)
        if not isinstance(values, list) or len(values) != len(timestamps):
            raise ValueError("Incomplete forecast arrays")
        if any(value is not None and not is_finite_number(value) for value in values):
            raise ValueError("Invalid forecast value")
    expected_units = {"time": "unixtime", "temperature_2m": "°C", "wind_speed_10m": "m/s"}
    if any(data["hourly_units"].get(field) != unit for field, unit in expected_units.items()):
        raise ValueError("Unexpected forecast units")
    return zone


def hourly_row(hourly, index, zone):
    timestamp = hourly["time"][index]
    local_time = datetime.fromtimestamp(timestamp, zone)
    return {
        "time": timestamp * 1000,
        "hour": local_time.strftime("%H"),
        "day": local_time.strftime("%a"),
        "label": local_time.strftime("%a %d %b · %H:%M %Z"),
        "offset": int(local_time.utcoffset().total_seconds()),
        **{field: hourly[field][index] for field in FIELDS},
    }


def observing_night(hourly, date, zone):
    start = datetime.combine(date, day_time(12), zone)
    end = datetime.combine(date + timedelta(days=1), day_time(12), zone)
    start_stamp = start.timestamp()
    end_stamp = end.timestamp()
    rows = [
        hourly_row(hourly, index, zone)
        for index, timestamp in enumerate(hourly["time"])
        if start_stamp <= timestamp < end_stamp
    ]
    return {
        "label": start.strftime("%a") + " → " + end.strftime("%a"),
        "start": start_stamp * 1000,
        "end": end_stamp * 1000,
        "rows": rows,
    }


def present(data, fetched, name, now):
    zone = validate(data)
    local_time = datetime.fromtimestamp(now, zone)
    first_day = local_time.date() - timedelta(days=1 if local_time.hour < 12 else 0)
    nights = []
    for offset in range(3):
        night = observing_night(data["hourly"], first_day + timedelta(days=offset), zone)
        if night["rows"]:
            nights.append(night)
    if not nights:
        raise ValueError("Cached forecast no longer covers the observing night")
    return {
        "ok": True,
        "location": name or "Observing location",
        "timezone": data["timezone"],
        "fetchedAt": fetched * 1000,
        "updated": datetime.fromtimestamp(fetched, zone).strftime("%H:%M %Z"),
        "stale": now - fetched > TTL,
        "nights": nights,
    }


def read_cache(path):
    try:
        result = json.loads(path.read_text())
        validate(result["data"])
        if not isinstance(result["fetched"], (int, float)):
            return None
        return result
    except (OSError, ValueError, KeyError, TypeError):
        return None


def write_cache(path, value):
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".forecast-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(value, stream, allow_nan=False)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def request_forecast(latitude, longitude):
    query = urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "hourly": ",".join(FIELDS),
            "wind_speed_unit": "ms",
            "past_days": 1,
            "forecast_days": 4,
            "timezone": "auto",
            "timeformat": "unixtime",
        }
    )
    with urlopen(FORECAST_URL + "?" + query, timeout=REQUEST_TIMEOUT) as response:
        payload = response.read(MAX_RESPONSE_BYTES + 1)
    if len(payload) > MAX_RESPONSE_BYTES:
        raise ValueError("Forecast response too large")
    return json.loads(payload)


def saved_forecast(cached, name, now):
    if cached:
        try:
            result = present(cached["data"], cached["fetched"], name, now)
            result.update(stale=True, warning="Refresh failed · showing saved forecast")
            return result
        except DATA_ERRORS:
            pass  # A saved report can age out of the requested observing nights.
    return {"ok": False, "error": "Forecast unavailable. Check your connection and refresh."}


def refresh_cache(path, cached, latitude, longitude, name, now):
    try:
        data = request_forecast(latitude, longitude)
        result = present(data, now, name, now)
        write_cache(path, {"fetched": now, "data": data})
        return result
    except (OSError, HTTPException, ValueError, KeyError, TypeError):
        return saved_forecast(cached, name, now)


def valid_coordinates(latitude, longitude):
    return (
        math.isfinite(latitude)
        and -90 <= latitude <= 90
        and math.isfinite(longitude)
        and -180 <= longitude <= 180
    )


def fetch(latitude, longitude, name="", force=False, cache_dir=None, now=None):
    now = time.time() if now is None else now
    if not valid_coordinates(latitude, longitude):
        return {"ok": False, "error": "Set valid latitude and longitude in Stargazer settings."}
    default_cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "omarchy-stargazer"
    directory = Path(cache_dir or default_cache)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    key = hashlib.sha256(f"{latitude:.5f},{longitude:.5f}".encode()).hexdigest()[:20]
    cache_path = directory / (key + ".json")
    # Monitor instances share this lock, including the request and atomic write.
    with (directory / (key + ".lock")).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        cached = read_cache(cache_path)
        minimum_age = MANUAL_REFRESH_INTERVAL if force else TTL
        if cached and now - cached["fetched"] < minimum_age:
            return present(cached["data"], cached["fetched"], name, now)
        return refresh_cache(cache_path, cached, latitude, longitude, name, now)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--latitude", type=float, required=True)
    parser.add_argument("--longitude", type=float, required=True)
    parser.add_argument("--name", default="Observing location")
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()
    try:
        result = fetch(args.latitude, args.longitude, args.name, args.refresh)
    except (OSError, ValueError, KeyError, TypeError):
        result = {"ok": False, "error": "Could not access the forecast cache."}
    print(json.dumps(result, allow_nan=False))


if __name__ == "__main__":
    main()
