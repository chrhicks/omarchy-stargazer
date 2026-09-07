pragma Singleton
import QtQuick

QtObject {
  property var font: ({
                        body: 14,
                        bodySmall: 12,
                        title: 22,
                        subtitle: 17,
                        family: "monospace"
                      })
  property real cornerRadius: 5
  property real scale: 1

  function space(units) {
    return units * scale
  }
}
