import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location("forecast", Path(__file__).parents[1] / "forecast.py")
forecast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(forecast)


def fixture(start="2026-10-30T00:00:00+00:00"):
    begin = datetime.fromisoformat(start)
    stamps = [int((begin + timedelta(hours=i)).timestamp()) for i in range(120)]
    return {
        "timezone": "America/New_York",
        "hourly_units": {"time": "unixtime", "temperature_2m": "°C", "wind_speed_10m": "m/s"},
        "hourly": {
            "time": stamps,
            **{key: [None if i == 5 else 20 for i in range(120)] for key in forecast.FIELDS},
        },
    }


class ForecastTests(unittest.TestCase):
    def test_fall_back_keeps_both_one_am_hours(self):
        now = datetime.fromisoformat("2026-10-31T20:00:00+00:00").timestamp()
        result = forecast.present(fixture(), now, "Test", now)
        rows = result["nights"][0]["rows"]
        self.assertEqual(len(rows), 25)
        ones = [r for r in rows if r["hour"] == "01"]
        self.assertEqual(len(ones), 2)
        self.assertNotEqual(ones[0]["offset"], ones[1]["offset"])

    def test_spring_forward_has_23_hours(self):
        now = datetime.fromisoformat("2026-03-07T20:00:00+00:00").timestamp()
        result = forecast.present(fixture("2026-03-06T00:00:00+00:00"), now, "Test", now)
        self.assertEqual(len(result["nights"][0]["rows"]), 23)

    def test_after_midnight_stays_with_current_observing_night(self):
        before = datetime.fromisoformat("2026-10-31T23:00:00-04:00").timestamp()
        after = datetime.fromisoformat("2026-11-01T01:00:00-04:00").timestamp()
        self.assertEqual(
            forecast.present(fixture(), before, "Test", before)["nights"][0]["start"],
            forecast.present(fixture(), before, "Test", after)["nights"][0]["start"],
        )

    def test_missing_value_is_not_zero(self):
        data = fixture()
        data["hourly"]["cloud_cover"][20] = None
        result = forecast.present(
            data, 0, "Test", datetime.fromisoformat("2026-10-30T14:00:00+00:00").timestamp()
        )
        self.assertIsNone(
            next(
                r
                for n in result["nights"]
                for r in n["rows"]
                if r["time"] == data["hourly"]["time"][20] * 1000
            )["cloud_cover"]
        )

    def test_incomplete_or_wrong_units_rejected(self):
        data = fixture()
        data["hourly"]["wind_speed_10m"].pop()
        with self.assertRaises(ValueError):
            forecast.validate(data)
        data = fixture()
        data["hourly_units"]["temperature_2m"] = "°F"
        with self.assertRaises(ValueError):
            forecast.validate(data)

    def test_cache_and_failed_refresh_preserve_last_good(self):
        now = datetime.fromisoformat("2026-10-31T20:00:00+00:00").timestamp()
        with tempfile.TemporaryDirectory() as directory:
            key = forecast.hashlib.sha256(b"40.00000,-74.00000").hexdigest()[:20]
            forecast.write_cache(Path(directory) / (key + ".json"), {"fetched": now, "data": fixture()})
            with patch.object(forecast, "urlopen", side_effect=OSError("offline")) as request:
                result = forecast.fetch(40, -74, cache_dir=directory, now=now + 60)
                self.assertFalse(result["stale"])
                request.assert_not_called()
                result = forecast.fetch(40, -74, cache_dir=directory, now=now + 1900)
                self.assertTrue(result["ok"])
                self.assertTrue(result["stale"])
                self.assertIn("saved", result["warning"])
                other = forecast.fetch(41, -74, cache_dir=directory, now=now + 1900)
                self.assertFalse(other["ok"])

    def test_option_like_site_name_reaches_fetch_unchanged(self):
        args = ["forecast.py", "--latitude", "0", "--longitude", "0", "--name=--example"]
        with patch("sys.argv", args), patch.object(forecast, "fetch", return_value={"ok": True}) as fetch:
            with redirect_stdout(io.StringIO()):
                forecast.main()
            fetch.assert_called_once_with(0, 0, "--example", False)

    def test_bad_coordinates_never_request_network(self):
        with patch.object(forecast, "urlopen") as request:
            self.assertFalse(forecast.fetch(float("nan"), 0)["ok"])
            self.assertFalse(forecast.fetch(91, 0)["ok"])
            request.assert_not_called()

    def test_network_success_is_cached_and_manual_refresh_has_cooldown(self):
        now = datetime.fromisoformat("2026-10-31T20:00:00+00:00").timestamp()
        response = MagicMock()
        response.__enter__.return_value.read.return_value = forecast.json.dumps(fixture()).encode()
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(forecast, "urlopen", return_value=response) as request:
                result = forecast.fetch(40, -74, cache_dir=directory, now=now)
                self.assertTrue(result["ok"])
                response.__enter__.return_value.read.assert_called_once_with(forecast.MAX_RESPONSE_BYTES + 1)
                self.assertEqual(request.call_args.kwargs["timeout"], forecast.REQUEST_TIMEOUT)
                forecast.fetch(40, -74, force=True, cache_dir=directory, now=now + 30)
                self.assertEqual(request.call_count, 1)
                forecast.fetch(40, -74, force=True, cache_dir=directory, now=now + 61)
                self.assertEqual(request.call_count, 2)

    def test_oversized_response_and_expired_saved_forecast_are_unavailable(self):
        now = datetime.fromisoformat("2026-10-31T20:00:00+00:00").timestamp()
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b"x" * (forecast.MAX_RESPONSE_BYTES + 1)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(forecast, "urlopen", return_value=response):
                self.assertFalse(forecast.fetch(40, -74, cache_dir=directory, now=now)["ok"])
        cached = {"fetched": now, "data": fixture()}
        self.assertFalse(forecast.saved_forecast(cached, "Test", now + 10 * 86400)["ok"])


if __name__ == "__main__":
    unittest.main()
