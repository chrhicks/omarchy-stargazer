import io
import json
import unittest
from unittest.mock import patch

import geocode


class GeocodeTests(unittest.TestCase):
    def response(self, data):
        return io.BytesIO(json.dumps(data).encode())

    def test_search_encodes_query_and_disambiguates_results(self):
        results = [
            {
                "name": "Greenwich",
                "admin1": "England",
                "country": "United Kingdom",
                "latitude": 51.48,
                "longitude": 0,
            }
        ]
        with patch.object(geocode, "urlopen", return_value=self.response({"results": results})) as request:
            result = geocode.search(" Greenwich, UK ")
        self.assertTrue(result["ok"])
        self.assertEqual(result["query"], "Greenwich, UK")
        self.assertEqual(result["places"][0]["detail"], "England, United Kingdom")
        self.assertIn("name=Greenwich%2C+UK", request.call_args.args[0])
        self.assertEqual(request.call_args.kwargs["timeout"], 10)

    def test_short_query_does_not_request_network(self):
        with patch.object(geocode, "urlopen") as request:
            self.assertFalse(geocode.search("x")["ok"])
            self.assertFalse(geocode.search("x" * 121)["ok"])
        request.assert_not_called()

    def test_no_results_and_invalid_coordinates(self):
        with patch.object(geocode, "urlopen", return_value=self.response({})):
            self.assertEqual(geocode.search("Unknown")["places"], [])
        invalid = [
            {"name": "Invalid", "latitude": 999, "longitude": 0},
            {"name": "Invalid", "latitude": True, "longitude": 0},
        ]
        with patch.object(geocode, "urlopen", return_value=self.response({"results": invalid})):
            self.assertEqual(geocode.search("Invalid")["places"], [])

    def test_network_and_malformed_responses_are_actionable(self):
        with patch.object(geocode, "urlopen", side_effect=OSError("offline")):
            self.assertIn("enter coordinates", geocode.search("Greenwich")["error"])
        for data in [[], {"results": "bad"}, {"error": True}]:
            with self.subTest(data=data), patch.object(geocode, "urlopen", return_value=self.response(data)):
                self.assertFalse(geocode.search("Greenwich")["ok"])
        with patch.object(
            geocode, "urlopen", return_value=io.BytesIO(b"x" * (geocode.MAX_RESPONSE_BYTES + 1))
        ):
            self.assertFalse(geocode.search("Greenwich")["ok"])
