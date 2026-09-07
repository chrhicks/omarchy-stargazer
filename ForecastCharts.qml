pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ForecastModel.js" as ForecastModel

Column {
  id: root

  readonly property var fonts: Style.font
  required property var forecast
  required property var hour
  required property real viewStart
  required property bool active
  required property color ink
  required property color accent
  required property string face
  readonly property color background: Color.background
  readonly property bool dragging: cloudScrubber.pressed || skyScrubber.pressed
  readonly property var rows: forecast ? forecast.rows : []
  readonly property var viewport: ({
                                     start: viewStart,
                                     end: viewStart + ForecastModel.dayMilliseconds
                                   })

  signal timeSelected(real timestamp)

  function repaint() {
    if (!active)
      return
    cloudCanvas.requestPaint()
    skyCanvas.requestPaint()
  }

  function timeX(timestamp) {
    return ForecastModel.timelineX(timestamp, viewport, width, Style.space(12))
  }

  function tint(opacity) {
    return Qt.rgba(ink.r, ink.g, ink.b, opacity)
  }

  spacing: Style.space(10)

  onHourChanged: repaint()
  onViewStartChanged: repaint()
  onActiveChanged: repaint()
  onInkChanged: repaint()
  onAccentChanged: repaint()
  onBackgroundChanged: repaint()

  Column {
    width: parent.width
    spacing: Style.space(6)
    topPadding: Style.space(6)

    RowLayout {
      width: parent.width

      Copy {
        text: "CLOUD COVER"
        font.bold: true
        Layout.fillWidth: true
      }

      Copy {
        text: "Lower is clearer"
        opacity: .6
      }
    }

    Canvas {
      id: cloudCanvas

      readonly property real plotHeight: height - Style.space(30)

      function coverY(cover) {
        return plotHeight - 3 - cover / 100 * (plotHeight - 6)
      }

      function paintCurve(context) {
        context.strokeStyle = root.tint(.6)
        context.lineWidth = 1.5
        context.beginPath()
        const segments = ForecastModel.cloudCurve(root.rows)
        for (const segment of segments) {
          const left = root.timeX(segment.start.time)
          const right = root.timeX(segment.end.time)
          const third = (right - left) / 3
          context.moveTo(left, coverY(segment.start.cloud_cover))
          context.bezierCurveTo(left + third, coverY(segment.control1), right - third, coverY(segment.control2),
                                right, coverY(segment.end.cloud_cover))
        }
        context.stroke()
      }

      function paintHourLabels(context) {
        context.fillStyle = root.tint(.6)
        context.font = root.fonts.bodySmall + "px sans-serif"
        context.textAlign = "center"
        for (const row of root.rows) {
          if (Number(row.hour) % 3 !== 0)
            continue
          const tick = root.timeX(row.time)
          if (tick < 0 || tick > width)
            continue
          const label = row.hour === "00" ? row.day + " 00" : row.hour
          context.fillText(label, tick, height - 2)
        }
      }

      function paintHandle(context) {
        const cursor = root.timeX(root.hour.time)
        const rail = plotHeight + Style.space(7)
        context.strokeStyle = root.ink
        context.lineWidth = 2
        context.beginPath()
        context.moveTo(cursor, 0)
        context.lineTo(cursor, plotHeight + Style.space(6))
        context.stroke()

        context.strokeStyle = root.tint(.28)
        context.beginPath()
        context.moveTo(Style.space(12), rail)
        context.lineTo(width - Style.space(12), rail)
        context.stroke()

        context.fillStyle = root.background
        context.strokeStyle = root.ink
        context.beginPath()
        context.arc(cursor, rail, Style.space(7), 0, Math.PI * 2)
        context.fill()
        context.stroke()
        context.fillStyle = root.ink
        context.beginPath()
        context.arc(cursor, rail, Style.space(2), 0, Math.PI * 2)
        context.fill()
      }

      objectName: "cloudTimeline"
      width: parent.width
      height: Style.space(72)
      Accessible.role: Accessible.Slider
      Accessible.name: "Forecast time, " + (root.hour ? root.hour.label : "unavailable")
      Accessible.description:
        "Drag the timeline to slide across days, or use left and right arrow keys to change the hour"

      onWidthChanged: root.repaint()
      onHeightChanged: root.repaint()
      onPaint: {
        const context = getContext("2d")
        context.clearRect(0, 0, width, height)
        if (!root.hour || !root.rows.length)
          return
        paintCurve(context)
        paintHourLabels(context)
        paintHandle(context)
      }

      TimeScrubber {
        id: cloudScrubber

        objectName: "scrubber"
        selectedTime: root.hour ? root.hour.time : 0
        viewStart: root.viewStart
        active: root.active
        available: root.hour !== null

        onTimeSelected: timestamp => root.timeSelected(timestamp)
      }
    }

    Copy {
      text: "Drag either chart to slide time · ← → one hour"
      opacity: .65
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(6)
    topPadding: Style.space(12)

    Copy {
      text: "SUN & MOON"
      font.bold: true
    }

    Canvas {
      id: skyCanvas

      function altitudeY(altitude) {
        return height - (altitude + 90) / 180 * height
      }

      function paintDarkness(context) {
        context.fillStyle = Qt.rgba(root.accent.r, root.accent.g, root.accent.b, .10)
        for (const span of root.forecast.dark) {
          const left = root.timeX(span.start)
          context.fillRect(left, 0, root.timeX(span.end) - left, height)
        }
      }

      function paintHorizon(context) {
        const inset = Style.space(12)
        context.strokeStyle = root.tint(.25)
        context.lineWidth = 1
        context.beginPath()
        context.moveTo(inset, altitudeY(0))
        context.lineTo(width - inset, altitudeY(0))
        context.stroke()
        context.fillStyle = root.tint(.65)
        context.font = root.fonts.bodySmall + "px sans-serif"
        context.fillText("Horizon", inset, altitudeY(0) - 5)
      }

      function paintTrack(context, body) {
        const isSun = body === "sun"
        context.strokeStyle = isSun ? root.accent : root.ink
        context.lineWidth = isSun ? 1 : 2
        context.beginPath()
        const tracks = root.forecast.tracks
        for (let index = 0; index < tracks.length; index++) {
          const sample = tracks[index]
          const x = root.timeX(sample.time)
          const y = altitudeY(sample.sky[body])
          // Leave every third Sun segment open to distinguish it from the Moon.
          if (index === 0 || (isSun && index % 3 === 0))
            context.moveTo(x, y)
          else
            context.lineTo(x, y)
        }
        context.stroke()
      }

      function paintCursor(context) {
        context.strokeStyle = root.ink
        context.lineWidth = 1
        context.beginPath()
        context.moveTo(root.timeX(root.hour.time), 0)
        context.lineTo(root.timeX(root.hour.time), height)
        context.stroke()
      }

      objectName: "skyChart"
      width: parent.width
      height: Style.space(82)
      Accessible.role: Accessible.Slider
      Accessible.name: "Sun and Moon forecast time, " + (root.hour ? root.hour.label : "unavailable")
      Accessible.description: "Drag to slide across days, or use left and right arrow keys"

      onWidthChanged: root.repaint()
      onHeightChanged: root.repaint()
      onPaint: {
        const context = getContext("2d")
        context.clearRect(0, 0, width, height)
        if (!root.forecast || !root.hour)
          return
        paintDarkness(context)
        paintHorizon(context)
        paintTrack(context, "sun")
        paintTrack(context, "moon")
        paintCursor(context)
      }

      TimeScrubber {
        id: skyScrubber

        objectName: "skyScrubber"
        selectedTime: root.hour ? root.hour.time : 0
        viewStart: root.viewStart
        active: root.active
        available: root.hour !== null

        onTimeSelected: timestamp => root.timeSelected(timestamp)
      }
    }

    RowLayout {
      width: parent.width

      Copy {
        text: "Sun · dashed"
        color: root.accent
      }

      Copy {
        text: "  Moon · solid"
      }

      Item {
        Layout.fillWidth: true
      }

      Copy {
        text: "Shaded: Sun below −18°"
        opacity: .6
      }
    }
  }

  component Copy: Text {
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.bodySmall
    textFormat: Text.PlainText
  }
}
