#!/usr/bin/env python3
"""Search public place names through Open-Meteo; no automatic location lookup."""

import argparse
import json
import math
from http.client import HTTPException
from urllib.parse import urlencode
from urllib.request import urlopen

SEARCH_URL = "https://geocoding-api.open-meteo.com/v1/search"
MAX_RESPONSE_BYTES = 200_000


def coordinate(value, limit):
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
        and abs(value) <= limit
    )


def place(result):
    name = result.get("name")
    latitude, longitude = result.get("latitude"), result.get("longitude")
    if not isinstance(name, str) or not name.strip():
        return None
    if not coordinate(latitude, 90) or not coordinate(longitude, 180):
        return None
    context = [result.get("admin2"), result.get("admin1"), result.get("country")]
    details = list(dict.fromkeys(part for part in context if isinstance(part, str) and part and part != name))
    return {
        "name": name[:160],
        "detail": ", ".join(details)[:240],
        "latitude": latitude,
        "longitude": longitude,
    }


def search(query):
    query = query.strip()
    if not 2 <= len(query) <= 120:
        return {"query": query, "ok": False, "error": "Enter a town or postal code (2–120 characters)."}
    parameters = urlencode({"name": query, "count": 6, "language": "en", "format": "json"})
    try:
        with urlopen(SEARCH_URL + "?" + parameters, timeout=10) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise ValueError("Oversized response")
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get("error"):
            raise ValueError("Invalid response")
        results = data.get("results", [])
        if not isinstance(results, list):
            raise ValueError("Invalid results")
        places = [place(result) for result in results[:6] if isinstance(result, dict)]
        return {"query": query, "ok": True, "places": [result for result in places if result]}
    except (OSError, ValueError, HTTPException):
        return {
            "query": query,
            "ok": False,
            "error": "Could not search places. Check your connection and try again, or enter coordinates.",
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query")
    args = parser.parse_args()
    print(json.dumps(search(args.query), allow_nan=False))


if __name__ == "__main__":
    main()
