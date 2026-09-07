.import "vendor/suncalc.js" as Astronomy

var hourMilliseconds = 3600000
var dayMilliseconds = 24 * hourMilliseconds
var minuteMilliseconds = 60000
var astronomicalDarkAltitude = -18

function finite(number) {
  return typeof number === 'number' && isFinite(number)
}

function value(number, suffix, digits) {
  if (!finite(number))
    return '—'
  return number.toFixed(digits || 0) + (suffix || '')
}

function temperature(celsius, fahrenheit) {
  if (!finite(celsius))
    return '—'
  const degrees = fahrenheit ? celsius * 9 / 5 + 32 : celsius
  return value(degrees, '°')
}

function wind(metresPerSecond, mph) {
  if (!finite(metresPerSecond))
    return '—'
  const speed = metresPerSecond * (mph ? 2.236936 : 3.6)
  return value(speed, mph ? ' mph' : ' km/h')
}

function daylightLabel(sunAltitude) {
  if (sunAltitude < astronomicalDarkAltitude)
    return 'Astronomical dark'
  if (sunAltitude < -.833)
    return 'Twilight'
  return 'Daylight'
}

function phaseName(phase) {
  if (phase < .03 || phase > .97)
    return 'New Moon'
  if (phase < .22)
    return 'Waxing crescent'
  if (phase < .28)
    return 'First quarter'
  if (phase < .47)
    return 'Waxing gibbous'
  if (phase < .53)
    return 'Full Moon'
  if (phase < .72)
    return 'Waning gibbous'
  if (phase < .78)
    return 'Last quarter'
  return 'Waning crescent'
}

function sky(time, latitude, longitude) {
  const date = new Date(time)
  const sun = Astronomy.SunCalc.getPosition(date, latitude, longitude)
  const moon = Astronomy.SunCalc.getMoonPosition(date, latitude, longitude)
  const illumination = Astronomy.SunCalc.getMoonIllumination(date)
  return {
    sun: sun.altitude * 180 / Math.PI,
    moon: moon.altitude * 180 / Math.PI,
    fraction: illumination.fraction,
    phase: phaseName(illumination.phase)
  }
}

function darkSpans(night, latitude, longitude) {
  const spans = []
  let begin = null
  // Absolute timestamps preserve 23/25-hour nights; crossings are within a minute.
  for (let time = night.start; time <= night.end; time += minuteMilliseconds) {
    const altitude = Astronomy.SunCalc.getPosition(new Date(time), latitude, longitude).altitude
    const dark = altitude < -Math.PI / 10
    if (dark && begin === null)
      begin = time
    if ((!dark || time === night.end) && begin !== null) {
      spans.push({
                   start: begin,
                   end: time
                 })
      begin = null
    }
  }
  return spans
}

function enrich(night, latitude, longitude) {
  if (!night)
    return null
  const rows = night.rows.map(row => {
    const result = Object.assign({}, row)
    result.sky = sky(row.time, latitude, longitude)
    return result
  })
  return {
    label: night.label,
    start: night.start,
    end: night.end,
    rows: rows,
    dark: darkSpans(night, latitude, longitude)
  }
}

function nearest(rows, time) {
  let bestIndex = 0
  let bestDistance = Infinity
  for (let index = 0; index < rows.length; index++) {
    const distance = Math.abs(rows[index].time - time)
    if (distance < bestDistance) {
      bestIndex = index
      bestDistance = distance
    }
  }
  return bestIndex
}

function clock(time, night) {
  let offset = night.rows.length ? night.rows[0].offset : 0
  for (const row of night.rows) {
    if (row.time <= time)
      offset = row.offset
  }
  const localTime = new Date(time + offset * 1000)
  const hours = ('0' + localTime.getUTCHours()).slice(-2)
  const minutes = ('0' + localTime.getUTCMinutes()).slice(-2)
  return hours + ':' + minutes
}

function darkLabel(night) {
  if (!night.dark.length)
    return 'No astronomical darkness'
  const span = night.dark[0]
  if (span.start === night.start && span.end === night.end)
    return 'Dark throughout this window'
  return 'Dark ' + clock(span.start, night) + '–' + clock(span.end, night)
}

// Both plots use this absolute-time axis, including 23/25-hour DST nights.
function timelineX(time, viewport, width, padding) {
  const fraction = (time - viewport.start) / (viewport.end - viewport.start)
  return padding + fraction * (width - 2 * padding)
}

function timelineIndex(x, night, width, padding) {
  const fraction = Math.max(0, Math.min(1, (x - padding) / Math.max(1, width - 2 * padding)))
  return nearest(night.rows, night.start + fraction * (night.end - night.start))
}

function containingHourIndex(rows, time) {
  return rows.findIndex(row => row.time <= time && time < row.time + hourMilliseconds)
}

// "Now" means the hour containing this instant, never a stale edge row.
function currentHour(report, time) {
  if (!report || !report.nights)
    return null
  for (let nightIndex = 0; nightIndex < report.nights.length; nightIndex++) {
    const night = report.nights[nightIndex]
    if (time < night.start || time >= night.end)
      continue
    const rowIndex = containingHourIndex(night.rows, time)
    if (rowIndex >= 0)
      return {
        nightIndex: nightIndex,
        rowIndex: rowIndex,
        row: night.rows[rowIndex]
      }
  }
  return null
}

function adjacentCloudHours(rows, leftIndex, rightIndex) {
  const left = rows[leftIndex]
  const right = rows[rightIndex]
  return left && right && finite(left.cloud_cover) && finite(right.cloud_cover) && right.time - left.time
      === hourMilliseconds

}

function cloudTangent(rows, index) {
  if (!adjacentCloudHours(rows, index - 1, index) || !adjacentCloudHours(rows, index, index + 1))
    return 0
  const incoming = rows[index].cloud_cover - rows[index - 1].cloud_cover
  const outgoing = rows[index + 1].cloud_cover - rows[index].cloud_cover
  if (incoming * outgoing <= 0)
    return 0
  return 2 * incoming * outgoing / (incoming + outgoing)
}

// Monotone cubic controls avoid overshoot and never bridge missing hours.
function cloudCurve(rows) {
  const segments = []
  for (let index = 1; index < rows.length; index++) {
    if (!adjacentCloudHours(rows, index - 1, index))
      continue
    segments.push({
                    start: rows[index - 1],
                    end: rows[index],
                    control1: rows[index - 1].cloud_cover + cloudTangent(rows, index - 1) / 3,
                    control2: rows[index].cloud_cover - cloudTangent(rows, index) / 3
                  })
  }
  return segments
}

function astronomyTracks(start, end, latitude, longitude) {
  const tracks = []
  for (let time = start; time <= end; time += hourMilliseconds / 2) {
    tracks.push({
                  time: time,
                  sky: sky(time, latitude, longitude)
                })
  }
  return tracks
}

// Calculated once per report. Moving the viewport only changes coordinates.
function prepareForecast(report, latitude, longitude) {
  const nights = report.nights.map(night => enrich(night, latitude, longitude))
  const rows = []
  const dark = []
  nights.forEach((night, index) => {
    night.rows.forEach(row => {
      row.nightIndex = index
      rows.push(row)
    })
    night.dark.forEach(span => dark.push(span))
  })
  const start = nights[0].start
  const end = nights[nights.length - 1].end
  return {
    nights: nights,
    rows: rows,
    dark: dark,
    tracks: astronomyTracks(start, end, latitude, longitude),
    start: start,
    end: end
  }
}

function windowStart(forecast, time) {
  const latestStart = Math.max(forecast.start, forecast.end - dayMilliseconds)
  return Math.max(forecast.start, Math.min(time - dayMilliseconds / 2, latestStart))
}

function draggedTime(time, distance, width) {
  return time - distance / Math.max(1, width) * dayMilliseconds
}
