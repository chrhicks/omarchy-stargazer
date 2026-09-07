import QtQuick

Item {
  property string moduleName
  property bool manageIpc
  property var bar: null
  property var settings: ({})
  property color barForeground: '#cacccc'
  property alias controller: controller
  readonly property bool opened: controller.open

  function setting(name, fallback) {
    return settings[name] === undefined ? fallback : settings[name]
  }

  QtObject {
    id: controller

    property bool open: true

    function show() {
      open = true
    }

    function hide() {
      open = false
    }
  }
}
