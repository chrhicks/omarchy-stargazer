import QtQuick
import QtTest
import qs.Commons
import "plugin" as Stargazer
import "plugin/ForecastModel.js" as ForecastModel
import "ForecastFixture.js" as Fixture

Item {
  id: stage

  width: 760 * settings.scale
  height: 1150 * settings.scale

  ProfileSettings {
    id: settings
  }

  Rectangle {
    anchors.fill: parent
    color: "#101315"
  }

  Stargazer.Panel {
    id: panel

    width: parent.width
    height: parent.height
    settings: ({
                 latitude: 40,
                 longitude: -74,
                 locationName: "Fixture"
               })
  }

  Stargazer.Panel {
    id: hiddenPanel

    settings: ({
                 latitude: 40,
                 longitude: -74,
                 locationName: "Hidden fixture"
               })

    Component.onCompleted: controller.hide()
  }

  Stargazer.Panel {
    id: setupPanel

    settings: ({})
    visible: false
  }

  SignalSpy {
    id: viewportChanges

    target: panel
    signalName: "viewStartChanged"
  }

  SignalSpy {
    id: hourChanges

    target: panel
    signalName: "selectedHourChanged"
  }

  SignalSpy {
    id: scenePaints

    signalName: "painted"
  }

  SignalSpy {
    id: cloudPaints

    signalName: "painted"
  }

  SignalSpy {
    id: skyPaints

    signalName: "painted"
  }

  SignalSpy {
    id: hiddenScenePaints

    signalName: "painted"
  }

  SignalSpy {
    id: hiddenCloudPaints

    signalName: "painted"
  }

  SignalSpy {
    id: hiddenSkyPaints

    signalName: "painted"
  }

  TestCase {
    property var readings: []

    function readingControls(item) {
      let controls = []
      if (item.objectName.startsWith("reading:"))
        controls.push(item)
      for (const child of item.children)
        controls = controls.concat(readingControls(child))
      return controls
    }

    function centerForecast() {
      panel.selectTime(panel.forecast.start + ForecastModel.dayMilliseconds)
    }

    function initTestCase() {
      Style.scale = settings.scale
      panel.report = Fixture.report()
      panel.forecast = ForecastModel.prepareForecast(panel.report, 40, -74)
      hiddenPanel.report = panel.report
      hiddenPanel.forecast = panel.forecast
      centerForecast()
      scenePaints.target = findChild(panel, "skyScene")
      cloudPaints.target = findChild(panel, "cloudTimeline")
      skyPaints.target = findChild(panel, "skyChart")
      hiddenScenePaints.target = findChild(hiddenPanel, "skyScene")
      hiddenCloudPaints.target = findChild(hiddenPanel, "cloudTimeline")
      hiddenSkyPaints.target = findChild(hiddenPanel, "skyChart")
      wait(300)
      readings = readingControls(panel)
      compare(readings.length, 13)
      grabImage(stage).save(settings.outputDirectory + "/panel.png")
    }

    function init() {
      panel.animateWindow = false
      panel.controller.show()
      panel.errorText = ""
      centerForecast()
      wait(100)
      panel.animateWindow = true
      viewportChanges.clear()
      hourChanges.clear()
      scenePaints.clear()
      cloudPaints.clear()
      skyPaints.clear()
      hiddenScenePaints.clear()
      hiddenCloudPaints.clear()
      hiddenSkyPaints.clear()
    }

    function test_scrubReplay() {
      const mouse = findChild(panel, settings.chart === "sky" ? "skyScrubber" : "scrubber")
      const start = Date.now()
      let previous = start
      let worstGap = 0
      mousePress(mouse, mouse.width / 2, mouse.height / 2)
      for (let index = 0; index < settings.moves; index++) {
        const x = mouse.width * (.5 + .45 * Math.sin(index * .12))
        mouseMove(mouse, x, mouse.height / 2, 1)
        wait(1)
        const now = Date.now()
        worstGap = Math.max(worstGap, now - previous)
        previous = now
      }
      mouseRelease(mouse, mouse.width / 2, mouse.height / 2)
      const elapsed = Date.now() - start
      wait(400)
      const settledChanges = viewportChanges.count
      wait(300)
      compare(viewportChanges.count, settledChanges, "No delayed navigation after settling")
      verify(hourChanges.count > 5, "Replay must actually change hours")
      verify(worstGap < 100, "An input callback stalled for over 100 ms")
      verify(scenePaints.count < settings.moves, "Scene work must be coalesced")
      compare(hiddenScenePaints.count, 0)
      compare(hiddenCloudPaints.count, 0)
      compare(hiddenSkyPaints.count, 0)
      for (const control of readings)
        compare(findChild(panel, control.objectName), control)
      console.log("PROFILE " + JSON.stringify({
                                                chart: settings.chart,
                                                moves: settings.moves,
                                                elapsed: elapsed,
                                                worstGap: worstGap,
                                                selectedHours: hourChanges.count,
                                                scenePaints: scenePaints.count,
                                                cloudPaints: cloudPaints.count,
                                                skyPaints: skyPaints.count
                                              }))
    }

    function test_closeDuringDrag_data() {
      return [
            {
              tag: "cloud",
              name: "scrubber"
            },
            {
              tag: "sky",
              name: "skyScrubber"
            }
          ]
    }

    function test_closeDuringDrag(data) {
      const mouse = findChild(panel, data.name)
      mousePress(mouse, mouse.width / 2, mouse.height / 2)
      mouseMove(mouse, mouse.width * .8, mouse.height / 2, 1)
      panel.close()
      wait(100)
      compare(mouse.pending, false)
      const selected = panel.selectedIndex
      const viewStart = panel.viewStart
      scenePaints.clear()
      mouseRelease(mouse, mouse.width * .8, mouse.height / 2)
      wait(350)
      compare(panel.selectedIndex, selected)
      compare(panel.viewStart, viewStart)
      compare(scenePaints.count, 0)
      panel.selectTime(panel.forecast.start)
      wait(300)
      compare(scenePaints.count, 0)
      panel.controller.show()
      wait(300)
      verify(scenePaints.count > 0)
    }

    function test_cancelDrag_data() {
      return test_closeDuringDrag_data()
    }

    function test_cancelDrag(data) {
      const mouse = findChild(panel, data.name)
      mousePress(mouse, mouse.width / 2, mouse.height / 2)
      mouseMove(mouse, mouse.width * .8, mouse.height / 2, 1)
      mouse.canceled()
      compare(mouse.pending, false)
      mouseRelease(mouse, mouse.width * .8, mouse.height / 2)
    }

    function test_clickParity() {
      const cloud = findChild(panel, "scrubber")
      const sky = findChild(panel, "skyScrubber")
      mouseClick(cloud, cloud.width * .65, cloud.height / 2)
      wait(300)
      const selected = panel.selectedHour.time
      centerForecast()
      wait(300)
      mouseClick(sky, sky.width * .65, sky.height / 2)
      wait(300)
      compare(panel.selectedHour.time, selected)
    }

    function test_hourNavigation() {
      panel.animateWindow = false
      const boundary = panel.forecast.nights[1].start
      panel.selectTime(boundary - ForecastModel.hourMilliseconds)
      panel.stepHour(1)
      compare(panel.selectedHour.time, boundary)
      panel.stepHour(-1)
      compare(panel.selectedHour.time, boundary - ForecastModel.hourMilliseconds)
      panel.selectTime(0)
      panel.stepHour(-1)
      compare(panel.selectedIndex, 0)
      panel.selectTime(Infinity)
      panel.stepHour(1)
      compare(panel.selectedIndex, panel.hourlyRows.length - 1)
      panel.selectNow()
      compare(panel.selectedHour.time, panel.currentHour.row.time)
    }

    function test_refreshPreservesSelection() {
      const selectedTime = panel.selectedHour.time
      panel.applyReport(Fixture.report())
      compare(panel.selectedHour.time, selectedTime)
      const tooltip = panel.tooltip
      panel.stepHour(1)
      compare(panel.tooltip, tooltip)
    }

    function test_firstRunAndLocationSetup() {
      const process = findChild(setupPanel, "forecastProcess")
      verify(process !== null)
      compare(setupPanel.configured, false)
      setupPanel.open()
      setupPanel.refresh(true)
      wait(400)
      compare(process.startCount, 0)
      verify(setupPanel.statusMessage().indexOf("Set your observing location") >= 0)
      setupPanel.settings = ({
                               latitude: 200,
                               longitude: 0
                             })
      wait(400)
      compare(process.startCount, 0)
      setupPanel.settings = ({
                               latitude: 51.4779,
                               longitude: 0.0015,
                               locationName: "Greenwich Observatory"
                             })
      wait(500)
      compare(setupPanel.configured, true)
      verify(process.startCount > 0)
      verify(process.command.indexOf("51.4779") >= 0)
      verify(process.command.indexOf("0.0015") >= 0)
      setupPanel.close()
      setupPanel.settings = ({})
    }

    function test_savedForecastIsLabelled() {
      const saved = Fixture.report()
      saved.stale = true
      saved.warning = "Network unavailable"
      panel.applyReport(saved)
      verify(panel.stale)
      verify(panel.statusMessage().indexOf("Saved forecast") >= 0)
      verify(panel.statusMessage().indexOf("Network unavailable") >= 0)
      verify(panel.tooltip.indexOf("Saved forecast") >= 0)
      panel.applyReport(Fixture.report())
      compare(panel.stale, false)
    }

    function test_malformedReportKeepsLastForecast() {
      const report = panel.report
      const forecast = panel.forecast
      panel.acceptReport('{"ok":true,"nights":null}')
      verify(panel.errorText.length > 0)
      compare(panel.report, report)
      compare(panel.forecast, forecast)
    }

    name: "FullPanel"
    when: windowShown
  }
}
