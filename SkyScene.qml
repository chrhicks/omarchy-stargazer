pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "ForecastModel.js" as ForecastModel
import "CloudField.js" as Clouds

Item {
  id: root

  readonly property var fonts: Style.font
  required property var hour
  required property bool active
  required property color ink
  required property string face
  readonly property color background: Color.background
  readonly property real daylight: hour ? Math.max(0, Math.min(1, (hour.sky.sun + 18) / 35)) : 0
  readonly property string conditions: {
    if (!hour)
      return ""
    if (!ForecastModel.finite(hour.cloud_cover))
      return "Cloud forecast unavailable"
    const light = hour.sky.sun < -18 ? "Night" : ForecastModel.daylightLabel(hour.sky.sun)
    return ForecastModel.value(hour.cloud_cover, "% cloud") + " · " + light
  }

  function repaint() {
    if (active)
      canvas.requestPaint()
  }

  function tint(opacity) {
    return Qt.rgba(ink.r, ink.g, ink.b, opacity)
  }

  // Stable illustrative stars, not constellations or a navigational sky map.
  function starPosition(seed) {
    return (Math.sin(seed * 127.1 + 7) * 43758.5453 % 1 + 1) % 1
  }

  function paintSky(context) {
    const gradient = context.createLinearGradient(0, 0, 0, height)
    gradient.addColorStop(0, tint(.025 + daylight * .12))
    gradient.addColorStop(1, tint(.10 + daylight * .12))
    context.fillStyle = gradient
    context.fillRect(0, 0, width, height)
  }

  function paintStar(context, x, y, radius, brightness, prominent) {
    if (prominent) {
      const halo = context.createRadialGradient(x, y, 0, x, y, radius * 4)
      halo.addColorStop(0, tint(brightness * .24))
      halo.addColorStop(1, tint(0))
      context.fillStyle = halo
      context.fillRect(x - radius * 4, y - radius * 4, radius * 8, radius * 8)
    }
    context.fillStyle = tint(brightness)
    context.beginPath()
    context.arc(x, y, radius, 0, Math.PI * 2)
    context.fill()
  }

  function paintStars(context) {
    const cover = hour.cloud_cover
    const cloudVisibility = ForecastModel.finite(cover) ? Math.pow(1 - Math.max(0, Math.min(100, cover)) / 100,
                                                                   1.4) : 0
    const nightLight = Math.pow(1 - daylight, 3) * cloudVisibility
    for (let index = 0; index < 130; index++) {
      const x = starPosition(index + 1) * width
      const y = starPosition(index + 419) * height * .81
      const horizonFade = Math.max(.08, 1 - Math.pow(y / (height * .86), 3))
      const prominent = index < 8
      const radius = Style.space(prominent ? .85 + starPosition(index + 90) * .35 : .3 + starPosition(index
                                                                                                      + 90) * .3)
      const intensity = prominent ? .7 : .10 + starPosition(index + 177) * .24
      const brightness = intensity * nightLight * horizonFade
      if (brightness < .015)
        continue
      paintStar(context, x, y, radius, brightness, prominent)
    }
  }

  function paintSunAndMoon(context) {
    if (hour.sky.sun > 0) {
      context.fillStyle = tint(.8)
      context.beginPath()
      context.arc(width * .72, height * .82 - hour.sky.sun / 90 * height * .65, Style.space(10), 0, Math.PI
                  * 2)
      context.fill()
    }
    if (hour.sky.moon <= 0)
      return
    const moonX = width * .72
    const moonY = height * .82 - hour.sky.moon / 90 * height * .65
    context.strokeStyle = tint(.9)
    context.lineWidth = 1.5
    context.beginPath()
    context.arc(moonX, moonY, Style.space(9), 0, Math.PI * 2)
    context.stroke()
    context.fillStyle = tint(.9)
    context.font = root.fonts.bodySmall + "px sans-serif"
    context.fillText("Moon", moonX + Style.space(16), moonY + 4)
  }

  function paintClouds(context) {
    if (!ForecastModel.finite(hour.cloud_cover))
      return
    const cover = Math.max(0, Math.min(100, hour.cloud_cover)) / 100
    Clouds.paint(context, width, height, cover, daylight, ink, background)
  }

  function paintLandscape(context) {
    // Distant ridge followed by a dark foreground; preserve layer order.
    context.fillStyle = tint(.09)
    context.beginPath()
    context.moveTo(0, height)
    for (let index = 0; index <= 40; index++) {
      const ridge = .82 + Math.sin(index * .21) * .028 + Math.cos(index * .57) * .012
      context.lineTo(index * width / 40, height * ridge)
    }
    context.lineTo(width, height)
    context.closePath()
    context.fill()

    context.fillStyle = background
    context.beginPath()
    context.moveTo(0, height)
    for (let index = 0; index <= 30; index++) {
      const ridge = .87 + Math.sin(index * .47) * .018 + Math.sin(index * 1.7) * .007
      context.lineTo(index * width / 30, height * ridge)
    }
    context.lineTo(width, height)
    context.closePath()
    context.fill()
  }

  function paintCaptionShade(context) {
    const shade = context.createLinearGradient(0, 0, width * .47, 0)
    shade.addColorStop(0, Qt.rgba(background.r, background.g, background.b, .72))
    shade.addColorStop(1, Qt.rgba(background.r, background.g, background.b, 0))
    context.fillStyle = shade
    context.fillRect(0, 0, width * .47, height)
  }

  onHourChanged: repaint()
  onActiveChanged: repaint()
  onInkChanged: repaint()
  onBackgroundChanged: repaint()

  Canvas {
    id: canvas

    objectName: "skyScene"
    smooth: true
    anchors.fill: parent

    onWidthChanged: root.repaint()
    onHeightChanged: root.repaint()
    onPaint: {
      const context = getContext("2d")
      context.clearRect(0, 0, width, height)
      if (!root.hour)
        return
      root.paintSky(context)
      root.paintStars(context)
      root.paintSunAndMoon(context)
      root.paintClouds(context)
      root.paintLandscape(context)
      root.paintCaptionShade(context)
    }
  }

  Column {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: Style.space(14)
    spacing: Style.space(4)

    Copy {
      text: root.hour ? root.hour.day + " · " + root.hour.hour + ":00" : ""
      font.pixelSize: Style.space(25)
    }

    Copy {
      text: root.conditions
    }
  }

  Copy {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(10)
    text: root.hour && root.hour.sky.moon <= 0 ? "Moon below horizon" :
                                                 "Illustrative sky · Moon height calculated"
    opacity: .65
  }

  component Copy: Text {
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.bodySmall
    textFormat: Text.PlainText
  }
}
