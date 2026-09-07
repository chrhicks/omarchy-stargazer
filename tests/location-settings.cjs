const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')
const settings = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(__dirname, '../LocationSettings.js'), 'utf8'), settings)

test('location validation rejects missing or out-of-range coordinates and accepts zero', () => {
  for (const [lat, lon] of [
    ['', '0'],
    ['0', ''],
    ['91', '0'],
    ['0', '-181'],
    ['NaN', '0'],
    ['0x10', '0'],
    ['1e2', '0'],
  ]) {
    assert.throws(() => settings.location('Site', lat, lon))
  }
  assert.equal(settings.location(' Equator ', '0', '0').locationName, 'Equator')
  assert.equal(settings.location('', '-90', '180').latitude, '-90')
})

test('saving location preserves unrelated widgets and existing unit preferences', () => {
  const config = {
    version: 1,
    idle: { lock: 300 },
    bar: {
      layout: {
        left: ['omarchy.menu'],
        center: [{ id: 'chicks.stargazer', temperatureUnit: 'f', windUnit: 'kmh' }],
        right: [{ id: 'omarchy.weather', latitude: '1', longitude: '2' }],
      },
    },
  }
  const before = JSON.parse(JSON.stringify(config))
  settings.writeLocation(config, settings.location('Greenwich', '51.4779', '0.0015'))
  assert.deepEqual(config.idle, before.idle)
  assert.deepEqual(config.bar.layout.right, before.bar.layout.right)
  assert.deepEqual(config.bar.layout.left, before.bar.layout.left)
  assert.equal(config.bar.layout.center[0].temperatureUnit, 'f')
  assert.equal(config.bar.layout.center[0].longitude, '0.0015')
})

test('shorthand entries are expanded and a removed widget is never recreated', () => {
  const config = { bar: { layout: { right: ['chicks.stargazer'] } } }
  settings.writeLocation(config, settings.location('Site', 1, 2))
  assert.equal(config.bar.layout.right[0].id, 'chicks.stargazer')
  assert.throws(() => settings.writeLocation({ bar: { layout: {} } }, {}))
})
