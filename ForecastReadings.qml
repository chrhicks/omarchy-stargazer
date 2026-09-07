pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import "ForecastModel.js" as ForecastModel

Column {
  id: root

  readonly property var fonts: Style.font
  required property var hour
  required property bool fahrenheit
  required property bool mph
  required property color ink
  required property string face

  spacing: Style.space(10)

  Copy {
    text: root.hour ? root.hour.label : ""
    font.pixelSize: root.fonts.subtitle
    font.bold: true
  }

  Row {
    width: parent.width
    spacing: Style.space(32)

    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: Style.space(8)

      Copy {
        text: "WEATHER"
        font.pixelSize: root.fonts.bodySmall
        font.bold: true
        opacity: .7
      }

      ReadingRow {
        width: parent.width
        label: "Temperature"
        value: ForecastModel.temperature(root.hour?.temperature_2m, root.fahrenheit)
      }

      ReadingRow {
        width: parent.width
        label: "Dew point"
        value: ForecastModel.temperature(root.hour?.dew_point_2m, root.fahrenheit)
      }

      ReadingRow {
        width: parent.width
        label: "Wind"
        value: ForecastModel.wind(root.hour?.wind_speed_10m, root.mph)
      }

      ReadingRow {
        width: parent.width
        label: "Gusts"
        value: ForecastModel.wind(root.hour?.wind_gusts_10m, root.mph)
      }

      ReadingRow {
        width: parent.width
        label: "Rain chance"
        value: ForecastModel.value(root.hour?.precipitation_probability, "%")
      }
    }

    Column {
      width: (parent.width - parent.spacing) / 2
      spacing: Style.space(8)

      Copy {
        text: "CLOUDS"
        font.pixelSize: root.fonts.bodySmall
        font.bold: true
        opacity: .7
      }

      ReadingRow {
        width: parent.width
        label: "Total cover"
        value: ForecastModel.value(root.hour?.cloud_cover, "%")
      }

      ReadingRow {
        width: parent.width
        label: "Low"
        value: ForecastModel.value(root.hour?.cloud_cover_low, "%")
      }

      ReadingRow {
        width: parent.width
        label: "Middle"
        value: ForecastModel.value(root.hour?.cloud_cover_mid, "%")
      }

      ReadingRow {
        width: parent.width
        label: "High"
        value: ForecastModel.value(root.hour?.cloud_cover_high, "%")
      }
    }
  }

  Rectangle {
    width: parent.width
    height: 1
    color: root.ink
    opacity: .10
  }

  Row {
    id: moonRow

    width: parent.width
    spacing: Style.space(16)

    ReadingColumn {
      label: "Moon illuminated"
      value: ForecastModel.value(root.hour ? root.hour.sky.fraction * 100 : null, "%")
    }

    ReadingColumn {
      label: "Moon altitude"
      value: ForecastModel.value(root.hour?.sky.moon, "°")
    }

    ReadingColumn {
      label: "Moon phase"
      value: root.hour ? root.hour.sky.phase : ""
    }

    ReadingColumn {
      label: "Daylight"
      value: root.hour ? ForecastModel.daylightLabel(root.hour.sky.sun) : ""
    }
  }

  component Copy: Text {
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.body
    textFormat: Text.PlainText
  }
  component ReadingColumn: Column {
    id: column

    required property string label
    required property string value

    objectName: "reading:" + label
    width: (moonRow.width - moonRow.spacing * 3) / 4
    spacing: Style.space(5)

    Copy {
      text: column.label
      opacity: .6
      font.pixelSize: root.fonts.bodySmall
    }

    Copy {
      width: parent.width
      text: column.value
      wrapMode: Text.WordWrap
    }
  }

  // Explicit, persistent controls: changing the hour never rebuilds delegates.
  component ReadingRow: RowLayout {
    id: row

    required property string label
    required property string value

    objectName: "reading:" + label

    Copy {
      text: row.label
      opacity: .65
      Layout.fillWidth: true
    }

    Copy {
      text: row.value
      font.bold: true
    }
  }
}
