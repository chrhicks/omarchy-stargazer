import QtQuick
import qs.Commons
import "ForecastModel.js" as ForecastModel

MouseArea {
  id: root

  required property real selectedTime
  required property real viewStart
  required property bool active
  required property bool available
  property real pressX: 0
  property real pressTime: 0
  property real pressStart: 0
  property bool moved: false
  property bool pending: false
  property real pendingTime: 0

  signal timeSelected(real timestamp)

  function beginDrag(pointerX) {
    pressX = pointerX
    pressTime = selectedTime
    pressStart = viewStart
    moved = false
    pending = false
  }

  function updateDrag(pointerX) {
    if (!pressed || !enabled)
      return
    if (Math.abs(pointerX - pressX) > Style.space(4))
      moved = true
    if (!moved)
      return
    pendingTime = ForecastModel.draggedTime(pressTime, pointerX - pressX, width - Style.space(24))
    pending = true
  }

  function flushPendingTime() {
    if (!pending)
      return
    pending = false
    timeSelected(pendingTime)
  }

  function finishDrag(pointerX) {
    if (!enabled) {
      pending = false
      return
    }
    if (moved) {
      flushPendingTime()
      // Selection updates synchronously, so snap to the latest selected hour.
      timeSelected(selectedTime)
      return
    }
    const fraction = (pointerX - Style.space(12)) / Math.max(1, width - Style.space(24))
    timeSelected(pressStart + fraction * ForecastModel.dayMilliseconds)
  }

  anchors.fill: parent
  enabled: active && available
  preventStealing: true
  cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

  onPressed: mouse => beginDrag(mouse.x)
  onPositionChanged: mouse => updateDrag(mouse.x)
  onReleased: mouse => finishDrag(mouse.x)
  onCanceled: pending = false
  onEnabledChanged: if (!enabled)
                      pending = false

  // Keep only the latest pointer position, rather than replaying stale events.
  Timer {
    interval: 16
    repeat: true
    running: root.pressed && root.enabled

    onTriggered: root.flushPendingTime()
  }
}
