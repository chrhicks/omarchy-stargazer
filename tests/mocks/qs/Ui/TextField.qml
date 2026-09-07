import QtQuick
import QtQuick.Controls as Controls

Controls.TextField {
  property color foreground: "#cacccc"
  property color accent: "#cacccc"

  color: foreground
  placeholderTextColor: Qt.rgba(foreground.r, foreground.g, foreground.b, .5)
  font.family: "monospace"
  font.pixelSize: 14
  padding: 8

  background: Rectangle {
    color: "#181b1d"
    border.width: 1
    border.color: parent.activeFocus ? parent.accent : "#444848"
    radius: 4
  }
}
