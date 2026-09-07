import QtQuick

Item {
  property var anchorItem
  property var owner
  property var bar
  property bool open
  property var focusTarget
  property real contentWidth
  property real contentHeight

  function fittedContentWidth(n) {
    return n
  }

  function fittedContentHeight(n) {
    return n
  }

  visible: open
  width: contentWidth
  height: contentHeight
}
