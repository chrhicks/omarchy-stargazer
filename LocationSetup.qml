pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui as Ui
import "LocationSettings.js" as LocationSettings

Column {
  id: root

  readonly property var fonts: Style.font
  property string currentName: ""
  property string currentLatitude: ""
  property string currentLongitude: ""
  property bool canCancel: false
  property color ink: Color.foreground
  property color accent: Color.accent
  property string face: root.fonts.family
  property bool manual: false
  property string errorText: ""
  property var results: []
  property bool searched: false
  property string submittedQuery: ""
  readonly property bool searching: searchProcess.running

  signal locationSelected(var values)
  signal cancelRequested

  function begin() {
    resetSearch()
    manual = false
    siteName.text = canCancel ? currentName : ""
    latitude.text = currentLatitude
    longitude.text = currentLongitude
    query.text = ""
    Qt.callLater(() => query.forceActiveFocus())
  }

  function resetSearch() {
    submittedQuery = ""
    searchProcess.running = false
    results = []
    searched = false
    errorText = ""
  }

  function search() {
    const term = query.text.trim()
    if (term.length < 2) {
      errorText = "Enter at least two characters to search."
      return
    }
    resetSearch()
    submittedQuery = term
    const script = decodeURIComponent(Qt.resolvedUrl("geocode.py").toString().replace(/^file:\/\//, ""))
    searchProcess.command = ["python3", script, "--", term]
    searchProcess.running = true
  }

  function acceptSearch(text) {
    if (!visible || manual || !submittedQuery || query.text.trim() !== submittedQuery)
      return
    try {
      const response = JSON.parse(text)
      if (response.query !== submittedQuery)
        return
      if (!response.ok || !Array.isArray(response.places)) {
        errorText = response.error || "Could not read the search results. Try again."
        return
      }
      results = response.places
      searched = true
    } catch (error) {
      errorText = "Could not read the search results. Try again."
    }
  }

  function choosePlace(place) {
    const name = place.name + (place.detail ? ", " + place.detail : "")
    save(name, place.latitude, place.longitude)
  }

  function save(name, lat, lon) {
    try {
      errorText = ""
      locationSelected(LocationSettings.location(name, lat, lon))
    } catch (error) {
      errorText = error.message
    }
  }

  function focusSearch() {
    if (manual)
      siteName.forceActiveFocus()
    else
      query.forceActiveFocus()
  }

  spacing: Style.space(14)
  objectName: "locationSetup"

  onActiveFocusChanged: if (activeFocus)
                          focusSearch()
  Component.onCompleted: if (visible)
                           begin()
  onVisibleChanged: if (visible)
                      begin()
                    else
                      resetSearch()

  Process {
    id: searchProcess

    objectName: "locationSearchProcess"

    stdout: StdioCollector {
      onStreamFinished: root.acceptSearch(text)
    }
  }

  Copy {
    width: parent.width
    text: root.canCancel ? "Change observing location" : "Choose your observing location"
    color: root.ink
    font.family: root.face
    font.pixelSize: root.canCancel ? root.fonts.subtitle : root.fonts.title
    font.bold: true
  }

  Column {
    width: parent.width
    visible: !root.manual
    spacing: Style.space(10)

    Copy {
      width: parent.width
      text: "Search by town or postal code. Add a country to narrow it down, such as Greenwich, United Kingdom."
      wrapMode: Text.WordWrap
    }

    RowLayout {
      width: parent.width

      Field {
        id: query

        objectName: "locationQuery"
        Layout.fillWidth: true
        placeholderText: "Town or postal code"
        maximumLength: 120

        onTextEdited: root.resetSearch()
        onAccepted: root.search()
      }

      PanelButton {
        label: root.searching ? "Searching…" : "Search"
        enabled: !root.searching && query.text.trim().length >= 2
        ink: root.ink
        accent: root.accent

        onClicked: root.search()
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: root.results

        delegate: Rectangle {
          id: result

          required property var modelData
          required property int index

          objectName: "locationResult" + index
          width: parent.width
          height: labels.implicitHeight + Style.space(20)
          activeFocusOnTab: true
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, activeFocus || hover.containsMouse
                         ? .14 : .04)
          border.width: 1
          border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, activeFocus ? .6 : .15)
          radius: Style.cornerRadius
          Accessible.role: Accessible.Button
          Accessible.name: modelData.name + ", " + modelData.detail

          Keys.onReturnPressed: root.choosePlace(modelData)
          Keys.onSpacePressed: root.choosePlace(modelData)
          Accessible.onPressAction: root.choosePlace(modelData)

          Column {
            id: labels

            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(3)

            Copy {
              width: parent.width
              text: result.modelData.name
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: root.ink
              font.family: root.face
              font.pixelSize: root.fonts.body
              font.bold: true
            }

            Copy {
              width: parent.width
              text: result.modelData.detail
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: root.ink
              opacity: .7
              font.family: root.face
              font.pixelSize: root.fonts.bodySmall
            }
          }

          MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.choosePlace(result.modelData)
          }
        }
      }
    }

    Copy {
      visible: root.searched && !root.results.length
      text: "No matching places. Try a nearby town or enter coordinates."
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(10)
    visible: root.manual

    Copy {
      text: "Enter the coordinates of your observing site."
    }

    Field {
      id: siteName

      objectName: "locationNameField"
      width: parent.width
      placeholderText: "Observing site name (optional)"
      maximumLength: 160
    }

    RowLayout {
      width: parent.width

      Column {
        Layout.fillWidth: true
        spacing: Style.space(5)

        Copy {
          text: "Latitude"
        }

        Field {
          id: latitude

          objectName: "latitudeField"
          width: parent.width
          placeholderText: "−90 to 90"
          maximumLength: 24
        }
      }

      Column {
        Layout.fillWidth: true
        spacing: Style.space(5)

        Copy {
          text: "Longitude"
        }

        Field {
          id: longitude

          objectName: "longitudeField"
          width: parent.width
          placeholderText: "−180 to 180"
          maximumLength: 24

          onAccepted: root.save(siteName.text, latitude.text, longitude.text)
        }
      }
    }

    PanelButton {
      objectName: "saveCoordinates"
      label: "Use this location"
      ink: root.ink
      accent: root.accent

      onClicked: root.save(siteName.text, latitude.text, longitude.text)
    }
  }

  Copy {
    width: parent.width
    visible: root.errorText !== ""
    text: root.errorText
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Color.urgent
    font.family: root.face
    font.pixelSize: root.fonts.body
  }

  Row {
    spacing: Style.space(8)

    PanelButton {
      objectName: "locationMode"
      label: root.manual ? "Search for a place" : "Enter coordinates"
      ink: root.ink
      accent: root.accent

      onClicked: {
        root.resetSearch()
        root.manual = !root.manual
        root.focusSearch()
      }
    }

    PanelButton {
      label: "Cancel"
      visible: root.canCancel
      ink: root.ink
      accent: root.accent

      onClicked: root.cancelRequested()
    }
  }

  Copy {
    width: parent.width
    text: "Search uses Open-Meteo / GeoNames. Your selected coordinates are sent to Open-Meteo for forecasts."
    wrapMode: Text.WordWrap
    color: root.ink
    opacity: .6
    font.family: root.face
    font.pixelSize: root.fonts.bodySmall
  }

  component Copy: Text {
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.body
    textFormat: Text.PlainText
  }
  component Field: Ui.TextField {
    foreground: root.ink
    accent: root.accent
  }
}
