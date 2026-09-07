import QtQuick
import qs.Commons

Rectangle {
  id: root

  readonly property var fonts: Style.font
  property string label: ""
  property bool selected: false
  property color ink: Color.foreground
  property color accent: Color.accent
  property string face: root.fonts.family

  signal clicked

  implicitWidth: caption.implicitWidth + Style.space(20)
  implicitHeight: Style.space(32)
  activeFocusOnTab: true
  opacity: enabled ? 1 : .45
  color: Qt.rgba(accent.r, accent.g, accent.b, selected || activeFocus ? .16 : pointer.containsMouse ? .09 :
                                                                                                       0)
  border.width: 1
  border.color: Qt.rgba(ink.r, ink.g, ink.b, selected || activeFocus ? .6 : .15)
  radius: Math.min(Style.cornerRadius, Style.space(5))
  Accessible.role: Accessible.Button
  Accessible.name: label

  Keys.onReturnPressed: clicked()
  Keys.onEnterPressed: clicked()
  Keys.onSpacePressed: clicked()
  Accessible.onPressAction: clicked()

  Text {
    id: caption

    anchors.centerIn: parent
    text: root.label
    color: root.ink
    font.family: root.face
    font.pixelSize: root.fonts.bodySmall
    textFormat: Text.PlainText
  }

  MouseArea {
    id: pointer

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: root.clicked()
  }
}
