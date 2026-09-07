import QtQuick
import QtTest
import "plugin" as Stargazer

Item {
  id: stage

  width: 800
  height: 1100

  QtObject {
    id: mockShell

    property var config: ({
                            bar: {
                              layout: {
                                center: [
                                  {
                                    id: "chicks.stargazer",
                                    temperatureUnit: "f"
                                  }
                                ],
                                right: [
                                  {
                                    id: "omarchy.weather"
                                  }
                                ]
                              }
                            }
                          })

    function mutateShellConfig(mutator) {
      const copy = JSON.parse(JSON.stringify(config))
      mutator(copy)
      config = copy
      panel.settings = copy.bar.layout.center[0]
    }
  }

  QtObject {
    id: mockBar

    property QtObject shell: mockShell
    property string fontFamily: "monospace"
  }

  Stargazer.Panel {
    id: panel

    width: 760
    height: 1000
    bar: mockBar
  }

  Component {
    id: panelFactory

    Stargazer.Panel {
      width: 760
      height: 1000
    }
  }

  TestCase {
    property var form

    function init() {
      panel.close()
      panel.settings = ({})
      panel.locationEditing = false
      panel.open()
      form = findChild(panel, "locationSetup")
      wait(100)
    }

    function enterSearch(query) {
      findChild(panel, "locationQuery").text = query
      form.search()
      wait(20)
    }

    function searchResponse(query) {
      return JSON.stringify({
                              query: query,
                              ok: true,
                              places: [
                                {
                                  name: "Greenwich",
                                  detail: "England, United Kingdom",
                                  latitude: 51.4779,
                                  longitude: .0015
                                }
                              ]
                            })
    }

    function test_searchSelectionSurvivesRecreation() {
      enterSearch("Greenwich")
      form.acceptSearch(searchResponse("Greenwich"))
      compare(form.results.length, 1)
      wait(50)
      mouseClick(findChild(panel, "locationResult0"), 20, 20)
      wait(350)
      compare(panel.choosingLocation, false)
      compare(panel.latitude, 51.4779)
      compare(mockShell.config.bar.layout.right[0].id, "omarchy.weather")
      compare(mockShell.config.bar.layout.center[0].temperatureUnit, "f")
      const recreated = panelFactory.createObject(stage, {
                                                    bar: mockBar,
                                                    settings: JSON.parse(JSON.stringify(
                                                                           mockShell.config.bar.layout.center[0]))
                                                  })
      compare(recreated.configured, true)
      compare(recreated.locationName, "Greenwich, England, United Kingdom")
      compare(recreated.longitude, .0015)
      recreated.destroy()
    }

    function test_typingDoesNotTriggerForecastShortcuts() {
      const field = findChild(panel, "locationQuery")
      field.forceActiveFocus()
      const unit = panel.fahrenheit
      keyClick(Qt.Key_R)
      keyClick(Qt.Key_U)
      keyClick(Qt.Key_N)
      keyClick(Qt.Key_W)
      compare(field.text.toLowerCase(), "runw")
      compare(panel.fahrenheit, unit)
      compare(form.submittedQuery, "")
    }

    function test_staleAndClosedSearchesAreIgnored() {
      enterSearch("Greenwich")
      enterSearch("London")
      form.acceptSearch(searchResponse("Greenwich"))
      compare(form.results.length, 0)
      panel.close()
      form.acceptSearch(searchResponse("London"))
      compare(form.results.length, 0)
    }

    function test_errorAndManualCoordinates() {
      enterSearch("Greenwich")
      form.acceptSearch(JSON.stringify({
                                         query: "Greenwich",
                                         ok: false,
                                         error: "Connection unavailable"
                                       }))
      compare(form.errorText, "Connection unavailable")
      mouseClick(findChild(panel, "locationMode"), 20, 15)
      wait(50)
      findChild(panel, "latitudeField").text = "999"
      findChild(panel, "longitudeField").text = "0"
      mouseClick(findChild(panel, "saveCoordinates"), 20, 15)
      verify(form.errorText.indexOf("latitude") >= 0)
      compare(panel.configured, false)
      findChild(panel, "latitudeField").text = "0"
      findChild(panel, "locationNameField").text = "Equator"
      mouseClick(findChild(panel, "saveCoordinates"), 20, 15)
      compare(panel.configured, true)
      compare(panel.locationName, "Equator")
    }

    function test_cancelKeepsSavedLocation() {
      panel.settings = ({
                          latitude: 51.4779,
                          longitude: .0015,
                          locationName: "Greenwich"
                        })
      panel.editLocation()
      findChild(panel, "locationQuery").forceActiveFocus()
      keyClick(Qt.Key_Escape)
      compare(panel.locationEditing, false)
      compare(panel.locationName, "Greenwich")
    }

    name: "LocationSetup"
    when: windowShown
  }
}
