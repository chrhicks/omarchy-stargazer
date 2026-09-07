pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ForecastModel.js" as ForecastModel

Panel {
  id: root

  readonly property var fonts: Style.font
  readonly property var hostBar: bar
  property var anchorItem: null
  property var hostWidget: null
  property var report: null
  property var forecast: null
  property real viewStart: 0
  property bool animateWindow: false
  readonly property int selectedNightIndex: selectedHour ? selectedHour.nightIndex : 0
  property int selectedIndex: 0
  property string errorText: ""
  property bool selectNowAfterRefresh: false
  property bool fahrenheit: setting("temperatureUnit", "c") === "f"
  property bool mph: setting("windUnit", "mph") === "mph"
  readonly property string locationName: String(setting("locationName", "Observing location"))
  readonly property real latitude: coordinate(setting("latitude", ""))
  readonly property real longitude: coordinate(setting("longitude", ""))
  readonly property bool configured: isFinite(latitude) && isFinite(longitude) && Math.abs(latitude) <= 90
                                     && Math.abs(longitude) <= 180
  readonly property var hourlyRows: forecast ? forecast.rows : []
  readonly property var selectedHour: {
    if (!hourlyRows.length)
      return null
    return hourlyRows[Math.min(selectedIndex, hourlyRows.length - 1)]
  }
  readonly property var currentHour: ForecastModel.currentHour(report, clock.date.getTime())
  readonly property color ink: root.barForeground
  readonly property color accent: Color.accent
  readonly property string face: hostBar ? hostBar.fontFamily : root.fonts.family
  readonly property bool stale: report && (report.stale || clock.date.getTime() - report.fetchedAt > 2100000)
  readonly property string tooltip: forecastTooltip()

  function forecastTooltip() {
    const heading = "Stargazer · " + locationName
    if (!currentHour)
      return heading + "\nCurrent-hour forecast unavailable"
    const row = currentHour.row
    const clouds = ForecastModel.value(row.cloud_cover, "% cloud")
    const wind = ForecastModel.wind(row.wind_speed_10m, mph)
    const status = stale ? "\nSaved forecast" : ""
    return heading + "\nNow · " + row.label + "\n" + clouds + " · " + wind + status
  }

  function statusMessage() {
    if (!configured) {
      return "Set your observing location in the plugin settings: latitude, longitude and locationName. "
          + "See the Stargazer README for commands."
    }
    if (errorText)
      return errorText
    if (stale)
      return "Saved forecast · " + (report.warning || "waiting for an update")
    return ""
  }

  function applyReport(data) {
    const previousTime = selectedHour ? selectedHour.time : null
    const preparedForecast = ForecastModel.prepareForecast(data, latitude, longitude)
    animateWindow = false
    report = data
    forecast = preparedForecast
    const shouldSelectNow = selectNowAfterRefresh || previousTime === null
    if (shouldSelectNow && currentHour) {
      selectNowAfterRefresh = false
      selectNow()
    } else {
      selectTime(previousTime === null ? clock.date.getTime() : previousTime)
    }
    Qt.callLater(() => {
      root.animateWindow = true
    })
  }

  function acceptReport(text) {
    try {
      const data = JSON.parse(text)
      if (!data.ok) {
        errorText = data.error || "Forecast unavailable"
        return
      }
      applyReport(data)
    } catch (error) {
      errorText = "Could not read the forecast. Press R to retry."
    }
  }

  function coordinate(value) {
    if (value === "" || value === null)
      return NaN
    return Number(value)
  }

  function open() {
    controller.show()
    refresh(false)
  }

  function close() {
    controller.hide()
  }

  function switchPanel(direction) {
    if (!hostBar || !hostBar.switchPanelFrom)
      return false
    return hostBar.switchPanelFrom(hostWidget || root, direction)
  }

  function selectTime(time) {
    if (!forecast || !hourlyRows.length)
      return
    const bounded = Math.max(hourlyRows[0].time, Math.min(time, hourlyRows[hourlyRows.length - 1].time))
    selectedIndex = ForecastModel.nearest(hourlyRows, bounded)
    viewStart = ForecastModel.windowStart(forecast, bounded)
  }

  function stepHour(direction) {
    if (!hourlyRows.length)
      return
    const nextIndex = Math.max(0, Math.min(hourlyRows.length - 1, selectedIndex + direction))
    selectTime(hourlyRows[nextIndex].time)
  }

  function selectNight(index) {
    if (!forecast)
      return
    const offset = selectedHour ? selectedHour.time - forecast.nights[selectedNightIndex].start :
                                  ForecastModel.dayMilliseconds / 2
    const target = forecast.nights[Math.max(0, Math.min(index, forecast.nights.length - 1))]
    selectTime(target.start + offset)
  }

  function selectNow() {
    if (!currentHour) {
      selectNowAfterRefresh = true
      refresh(true)
      return
    }
    selectTime(currentHour.row.time)
  }

  function refresh(force) {
    if (!configured || fetcher.running)
      return
    errorText = ""
    const script = decodeURIComponent(Qt.resolvedUrl("forecast.py").toString().replace(/^file:\/\//, ""))
    fetcher.command = ["python3", script, "--latitude", String(latitude), "--longitude", String(longitude), "--name",
                       locationName]
    if (force)
      fetcher.command = fetcher.command.concat(["--refresh"])
    fetcher.running = true
  }

  function changedLocation() {
    fetcher.running = false
    report = null
    forecast = null
    selectedIndex = 0
    animateWindow = false
    reloadTimer.restart()
  }

  moduleName: "chicks.stargazer"
  manageIpc: false

  Behavior on viewStart {
    enabled: root.opened && root.animateWindow && !charts.dragging

    NumberAnimation {
      id: viewAnimation

      duration: 220
      easing.type: Easing.InOutQuad
    }
  }

  onLatitudeChanged: changedLocation()
  onLongitudeChanged: changedLocation()
  onLocationNameChanged: reloadTimer.restart()
  onOpenedChanged: if (!opened)
                     viewAnimation.stop()

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  Timer {
    id: reloadTimer

    interval: 250

    onTriggered: root.refresh(false)
  }

  Timer {
    interval: 1800000
    running: root.configured
    repeat: true

    onTriggered: root.refresh(false)
  }

  Process {
    id: fetcher

    stdout: StdioCollector {
      onStreamFinished: root.acceptReport(text)
    }
  }

  KeyboardPanel {
    id: popup

    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: fittedContentWidth(Style.space(760))
    contentHeight: fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys

      anchors.fill: parent

      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction)
      }
      onMoveRequested: function (dx, dy) {
        if (dy)
          root.selectNight(root.selectedNightIndex + dy)
        if (dx)
          root.stepHour(dx)
      }
      onTextKey: function (text) {
        const key = text.toLowerCase()
        if (key === "n")
          root.selectNow()
        if (key === "r")
          root.refresh(true)
        if (key === "u")
          root.fahrenheit = !root.fahrenheit
        if (key === "w")
          root.mph = !root.mph
      }

      Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content

          width: parent.width
          spacing: Style.space(16)

          RowLayout {
            width: parent.width

            Column {
              Layout.fillWidth: true
              spacing: Style.space(3)

              Copy {
                text: "STARGAZER"
                font.pixelSize: root.fonts.bodySmall
                color: root.accent
                font.letterSpacing: 2
              }

              Copy {
                text: root.locationName
                font.pixelSize: root.fonts.title
                font.bold: true
              }
            }

            Action {
              label: "Now"

              onClicked: root.selectNow()
            }

            Action {
              label: root.fahrenheit ? "°F" : "°C"

              onClicked: root.fahrenheit = !root.fahrenheit
            }

            Action {
              label: root.mph ? "mph" : "km/h"

              onClicked: root.mph = !root.mph
            }

            Action {
              label: fetcher.running ? "Refreshing…" : "Refresh"

              onClicked: root.refresh(true)
            }
          }

          Copy {
            width: parent.width
            visible: !root.configured || root.errorText !== "" || root.stale
            wrapMode: Text.WordWrap
            color: root.stale || root.errorText ? Color.urgent : root.ink
            text: root.statusMessage()
          }

          Copy {
            visible: root.configured && !root.report && !root.errorText
            text: "Fetching your observing forecast…"
            opacity: .7
          }

          Row {
            spacing: Style.space(8)

            Repeater {
              model: root.report ? root.report.nights : []

              Action {
                required property var modelData
                required property int index

                label: modelData.label
                selected: root.selectedNightIndex === index

                onClicked: root.selectNight(index)
              }
            }
          }

          Column {
            width: parent.width
            visible: root.forecast !== null
            spacing: Style.space(10)

            RowLayout {
              width: parent.width

              Copy {
                text: "24-HOUR FORECAST"
                font.pixelSize: root.fonts.bodySmall
                opacity: .7
                Layout.fillWidth: true
              }

              Copy {
                text: root.forecast ? ForecastModel.darkLabel(root.forecast.nights[root.selectedNightIndex]) :
                                      ""
                font.pixelSize: root.fonts.bodySmall
              }
            }

            SkyScene {
              width: parent.width
              height: Style.space(190)
              hour: root.selectedHour
              active: root.opened
              ink: root.ink
              face: root.face
            }

            ForecastCharts {
              id: charts

              width: parent.width
              forecast: root.forecast
              hour: root.selectedHour
              viewStart: root.viewStart
              active: root.opened
              ink: root.ink
              accent: root.accent
              face: root.face

              onTimeSelected: timestamp => root.selectTime(timestamp)
            }

            Rectangle {
              width: parent.width
              height: 1
              color: root.ink
              opacity: .15
            }

            ForecastReadings {
              width: parent.width
              hour: root.selectedHour
              fahrenheit: root.fahrenheit
              mph: root.mph
              ink: root.ink
              face: root.face
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: root.ink
            opacity: .15
          }

          RowLayout {
            width: parent.width

            Copy {
              Layout.fillWidth: true
              text: "Weather: Open-Meteo · astronomy: SunCalc"
              font.pixelSize: root.fonts.bodySmall
              opacity: .6
            }

            Copy {
              text: root.report ? "Updated " + root.report.updated : ""
              font.pixelSize: root.fonts.bodySmall
              opacity: .6
            }
          }

          Copy {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Forecast, not live measurements. Seeing and transparency are not included."
            font.pixelSize: root.fonts.bodySmall
            opacity: .55
          }
        }
      }
    }
  }

  component Action: Rectangle {
    id: action

    property string label: ""
    property bool selected: false

    signal clicked

    implicitWidth: caption.implicitWidth + Style.space(20)
    implicitHeight: Style.space(32)
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, action.selected ? .16 : pointer.containsMouse
                                                                                  ? .09 : 0)
    border.width: 1
    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, action.selected ? .6 : .15)
    radius: Math.min(Style.cornerRadius, Style.space(5))

    Copy {
      id: caption

      anchors.centerIn: parent
      text: action.label
      font.pixelSize: root.fonts.bodySmall
    }

    MouseArea {
      id: pointer

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: action.clicked()
    }
  }
  component Copy: Text {
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.body
    textFormat: Text.PlainText
  }
}
