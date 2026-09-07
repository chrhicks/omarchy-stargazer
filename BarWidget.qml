import QtQuick
import qs.Ui
import "." as Stargazer

BarWidget {
  id: root

  readonly property Stargazer.Panel panel: loader.item as Stargazer.Panel
  readonly property bool opened: panel ? panel.opened : false
  readonly property bool popoutSwitchClosing: panel ? panel.popoutSwitchClosing : false

  function open() {
    if (panel)
      panel.open()
  }

  function close() {
    if (panel)
      panel.close()
  }

  function closeForPopoutSwitch() {
    if (panel)
      panel.closeForPopoutSwitch()
  }

  function inject() {
    if (!panel)
      return
    panel.bar = root.bar
    panel.settings = root.settings
    panel.anchorItem = button
    panel.hostWidget = root
  }

  moduleName: "chicks.stargazer"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: inject()
  onSettingsChanged: inject()

  Loader {
    id: loader

    source: Qt.resolvedUrl("Panel.qml")
    visible: false

    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: "\uf186"
    tooltipText: root.panel ? root.panel.tooltip : "Stargazer"

    onPressed: function (button) {
      if (!root.panel)
        return
      if (button === Qt.MiddleButton)
        root.panel.refresh(true)
      else
        root.panel.toggle()
    }
  }
}
