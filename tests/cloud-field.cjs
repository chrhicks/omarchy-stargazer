const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const vm = require('node:vm')

function cloudRenderer() {
  const context = vm.createContext({})
  const source = fs.readFileSync(path.join(__dirname, '../CloudField.js'), 'utf8')
  vm.runInContext(source, context)
  return context
}

function canvasContext() {
  return {
    allocations: 0,
    lastImage: null,
    createImageData(width, height) {
      this.allocations++
      return { data: new Uint8ClampedArray(width * height * 4) }
    },
    drawImage(image) {
      this.lastImage = image
    },
    save() {},
    scale() {},
    restore() {},
  }
}

const foreground = { r: 0.8, g: 0.8, b: 0.8 }
const background = { r: 0.05, g: 0.06, b: 0.07 }

function paint(renderer, context, cover) {
  renderer.paint(context, 750, 190, cover, 0.3, foreground, background)
}

test('scrubbing reuses the cloud image and reproduces each coverage state', () => {
  const renderer = cloudRenderer()
  const context = canvasContext()
  paint(renderer, context, 0)
  assert.equal(context.allocations, 0)
  paint(renderer, context, 0.5)
  const image = context.lastImage
  const initialPixels = Array.from(image.data)
  for (let frame = 0; frame < 200; frame++) paint(renderer, context, frame / 200)
  paint(renderer, context, 0.5)
  assert.equal(context.allocations, 1)
  assert.equal(context.lastImage, image)
  assert.deepEqual(Array.from(image.data), initialPixels)
})

test('a recreated Canvas context receives its own image buffer', () => {
  const renderer = cloudRenderer()
  const original = canvasContext()
  const replacement = canvasContext()
  paint(renderer, original, 0.5)
  paint(renderer, replacement, 0.5)
  assert.equal(replacement.allocations, 1)
  assert.notEqual(original.lastImage, replacement.lastImage)
  assert.deepEqual(Array.from(original.lastImage.data), Array.from(replacement.lastImage.data))
})
