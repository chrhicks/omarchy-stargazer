function report() {
  const nights = []
  const start = Date.parse('2026-09-06T16:00:00Z')
  for (let nightIndex = 0; nightIndex < 3; nightIndex++) {
    const rows = []
    for (let hourIndex = 0; hourIndex < 24; hourIndex++) {
      rows.push({
                  time: start + (nightIndex * 24 + hourIndex) * 3600000,
                  offset: -14400,
                  day: 'Mon',
                  hour: ('0' + ((12 + hourIndex) % 24)).slice(-2),
                  label: 'Fixture hour ' + hourIndex,
                  cloud_cover: (Math.sin((nightIndex * 24 + hourIndex) * .4) + 1) * 50,
                  temperature_2m: 20,
                  dew_point_2m: 10,
                  wind_speed_10m: 3,
                  wind_gusts_10m: 5,
                  precipitation_probability: 10,
                  cloud_cover_low: 20,
                  cloud_cover_mid: 30,
                  cloud_cover_high: 10
                })
    }
    nights.push({
                  start: start + nightIndex * 86400000,
                  end: start + (nightIndex + 1) * 86400000,
                  rows: rows,
                  label: 'Mon → Tue'
                })
  }
  return {
    ok: true,
    nights: nights,
    fetchedAt: Date.now(),
    updated: 'Fixture'
  }
}
