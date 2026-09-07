// An illustrative texture: forecast cover reveals more of a fixed cloud field.
// Script state belongs to the importing scene. Do not share mutable Canvas data
// across components with .pragma library.
var fieldWidth = 192
var fieldHeight = 64
var field = null
var image = null
var imageContext = null

function hash(x, y) {
  const number = Math.sin(x * 127.1 + y * 311.7 + 19.3) * 43758.5453
  return number - Math.floor(number)
}

function smooth(start, end, position) {
  const fraction = Math.max(0, Math.min(1, (position - start) / (end - start)))
  return fraction * fraction * (3 - 2 * fraction)
}

function noise(x, y) {
  const left = Math.floor(x)
  const top = Math.floor(y)
  const horizontal = smooth(0, 1, x - left)
  const vertical = smooth(0, 1, y - top)
  const topLeft = hash(left, top)
  const topRight = hash(left + 1, top)
  const bottomLeft = hash(left, top + 1)
  const bottomRight = hash(left + 1, top + 1)
  return (topLeft + (topRight - topLeft) * horizontal) * (1 - vertical) + (bottomLeft + (bottomRight
                                                                                         - bottomLeft)
                                                                           * horizontal) * vertical
}

function fractal(x, y) {
  return noise(x, y) * .55 + noise(x * 2.07, y * 2.07) * .27 + noise(x * 4.13, y * 4.13) * .13 + noise(x
                                                                                                       * 8.29, y
                                                                                                       * 8.29) * .05
}

function textureRank(density, sorted) {
  let lower = 0
  let upper = sorted.length - 1
  while (lower < upper) {
    const middle = (lower + upper) >> 1
    if (sorted[middle] < density)
      lower = middle + 1
    else
      upper = middle
  }
  return lower / (sorted.length - 1)
}

function prepare() {
  if (field)
    return
  const raw = []
  for (let y = 0; y < fieldHeight; y++) {
    for (let x = 0; x < fieldWidth; x++) {
      const horizontal = x / (fieldWidth - 1)
      const vertical = y / (fieldHeight - 1)
      const warp = fractal(horizontal * 3 + 29, vertical * 3 + 17)
      raw.push(fractal(horizontal * 4 + vertical * 1.8 + warp * 1.2, vertical * 9 + warp * 2.2))
    }
  }
  const sorted = raw.slice().sort((left, right) => left - right)
  // Ranks let increasing cover open/close irregular regions evenly.
  field = raw.map(density => textureRank(density, sorted))
}

function opacity(density, cover) {
  if (cover <= 0)
    return 0
  const edge = 1 - Math.min(1, cover)
  return smooth(edge - .13, edge + .13, density) * Math.min(1, cover / .08)
}

function paint(context, width, height, cover, daylight, foreground, background) {
  if (cover <= 0)
    return
  prepare()
  // Reusing this buffer is essential: per-paint allocation stalled the shell.
  if (!image || imageContext !== context) {
    image = context.createImageData(fieldWidth, fieldHeight)
    imageContext = context
  }
  const pixels = image.data
  // QColor access crosses into QML; read channels once, outside the pixel loop.
  const red = background.r * 255
  const green = background.g * 255
  const blue = background.b * 255
  const redDelta = foreground.r * 255 - red
  const greenDelta = foreground.g * 255 - green
  const blueDelta = foreground.b * 255 - blue
  for (let index = 0; index < field.length; index++) {
    const density = field[index]
    const alpha = opacity(density, cover) * .92
    const light = .12 + daylight * .26 + density * .13
    const pixel = index * 4
    pixels[pixel] = red + redDelta * light
    pixels[pixel + 1] = green + greenDelta * light
    pixels[pixel + 2] = blue + blueDelta * light
    pixels[pixel + 3] = alpha * 255
  }
  // Painter scaling preserves soft interpolation; destination resizing in
  // drawImage would apply nearest-neighbor sampling before the smooth step.
  context.save()
  context.scale(width / fieldWidth, height / fieldHeight)
  context.drawImage(image, 0, 0, fieldWidth, fieldHeight, 0, 0, fieldWidth, fieldHeight)
  context.restore()
}
