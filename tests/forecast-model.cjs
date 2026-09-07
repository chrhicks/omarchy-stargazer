const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')

const root = path.join(__dirname, '..')
const astronomy = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(root, 'vendor/suncalc.js'), 'utf8'), astronomy)
const model = vm.createContext({ Astronomy: { SunCalc: astronomy.SunCalc } })
const source = fs.readFileSync(path.join(root, 'ForecastModel.js'), 'utf8')
vm.runInContext(source.replace(/^\.import[^\n]*\n/, ''), model)

const HOUR = 3600000
const DAY = 24 * HOUR
const start = Date.parse('2026-09-06T16:00:00Z')

function night(hours = 24, begins = start) {
  return {
    start: begins,
    end: begins + hours * HOUR,
    label: 'Example',
    rows: Array.from({ length: hours }, (_, index) => ({ time: begins + index * HOUR, offset: -14400 })),
  }
}

test('astronomical darkness crossings, illumination, and midnight labels', () => {
  const enriched = model.enrich(night(), 40, -74)
  assert.equal(enriched.dark.length, 1)
  const darkness = enriched.dark[0]
  assert.ok(darkness.start > start && darkness.end < start + DAY)
  assert.ok(Math.abs(model.sky(darkness.start, 40, -74).sun + 18) < 0.3)
  assert.ok(Math.abs(model.sky(darkness.end, 40, -74).sun + 18) < 0.3)
  assert.ok(enriched.rows.every((row) => row.sky.fraction >= 0 && row.sky.fraction <= 1))
  assert.equal(model.clock(Date.parse('2026-09-07T04:00:00Z'), enriched), '00:00')
})

test('polar daylight and darkness', () => {
  const summer = night(24, Date.parse('2026-06-21T00:00:00Z'))
  const winter = night(24, Date.parse('2026-12-21T00:00:00Z'))
  assert.equal(model.enrich(summer, 89.9, 0).dark.length, 0)
  assert.equal(model.darkLabel(model.enrich(winter, 89.9, 0)), 'Dark throughout this window')
})

test('unit conversions preserve missing values', () => {
  assert.equal(model.value(null, '%'), '—')
  assert.equal(model.wind(null, true), '—')
  assert.equal(model.temperature(0, true), '32°')
  assert.equal(model.wind(10, true), '22 mph')
})

for (const hours of [23, 24, 25]) {
  test(`plotted and clicked hours agree in a ${hours}-hour night`, () => {
    const axis = night(hours)
    for (const width of [320, 750]) {
      axis.rows.forEach((row, index) => {
        const x = model.timelineX(row.time, axis, width, 12)
        assert.equal(model.timelineIndex(x, axis, width, 12), index)
      })
      assert.equal(model.timelineIndex(-50, axis, width, 12), 0)
      assert.equal(model.timelineIndex(width + 50, axis, width, 12), hours - 1)
      assert.equal(model.timelineX(axis.start, axis, width, 12), 12)
      assert.equal(model.timelineX(axis.end, axis, width, 12), width - 12)
    }
  })

  test(`Now respects real timestamps in a ${hours}-hour night`, () => {
    const observingNight = night(hours)
    const report = { nights: [observingNight] }
    observingNight.rows.forEach((row, index) => {
      assert.equal(model.currentHour(report, row.time + HOUR - 1).rowIndex, index)
    })
    assert.equal(model.currentHour(report, start - 1), null)
    assert.equal(model.currentHour(report, observingNight.end), null)
  })

  test(`sliding across ${hours}-hour nights is continuous and bounded`, () => {
    const report = { nights: [0, 1, 2].map((index) => night(hours, start + index * hours * HOUR)) }
    const forecast = model.prepareForecast(report, 40, -74)
    assert.equal(forecast.rows.length, hours * 3)
    assert.equal(forecast.rows[hours].nightIndex, 1)
    assert.equal(model.windowStart(forecast, start - DAY), forecast.start)
    assert.equal(model.windowStart(forecast, forecast.end + DAY), forecast.end - DAY)
    const boundary = report.nights[1].start
    assert.equal(model.windowStart(forecast, boundary) - model.windowStart(forecast, boundary - HOUR), HOUR)
    assert.equal(model.windowStart(forecast, boundary) + DAY / 2, boundary)
    assert.equal(forecast.tracks[0].time, forecast.start)
    assert.equal(forecast.tracks[forecast.tracks.length - 1].time, forecast.end)
  })
}

test('Now handles noon, unavailable reports, and a missing hour', () => {
  assert.equal(model.currentHour(null, start), null)
  assert.equal(model.currentHour({ nights: [night(), night(24, start + DAY)] }, start + DAY).nightIndex, 1)
  const missing = night()
  missing.rows.splice(3, 1)
  assert.equal(model.currentHour({ nights: [missing] }, start + 3 * HOUR), null)
})

test('cloud curves stay bounded and never bridge missing forecast hours', () => {
  const coverages = [
    [0, 0, 100, 100, 0],
    [0, 15, 50, 80, 100],
    [100, 50, 20, 10, 0],
    [10, null, 80, 100],
    [0, 100, 0, 100, 0],
  ]
  for (const values of coverages) {
    const rows = values.map((cloud_cover, index) => ({ time: start + index * HOUR, cloud_cover }))
    const segments = model.cloudCurve(rows)
    for (const segment of segments) {
      const minimum = Math.min(segment.start.cloud_cover, segment.end.cloud_cover)
      const maximum = Math.max(segment.start.cloud_cover, segment.end.cloud_cover)
      assert.ok(segment.control1 >= minimum && segment.control1 <= maximum)
      assert.ok(segment.control2 >= minimum && segment.control2 <= maximum)
      assert.equal(segment.end.time - segment.start.time, HOUR)
    }
    if (values.includes(null)) assert.equal(segments.length, 1)
  }
  assert.equal(
    model.cloudCurve([
      { time: start, cloud_cover: 0 },
      { time: start + 2 * HOUR, cloud_cover: 100 },
    ]).length,
    0,
  )
})

test('dragging left advances time and dragging right reverses it', () => {
  assert.equal(model.draggedTime(start, -375, 750), start + DAY / 2)
  assert.equal(model.draggedTime(start, 375, 750), start - DAY / 2)
})
