import QtQuick

QtObject {
  property int startCount: 0
  property bool running: false
  property var command
  property QtObject stdout

  objectName: "forecastProcess"

  // Simulate immediate completion without starting a process or using the network.
  onRunningChanged: if (running) {
                      startCount++
                      Qt.callLater(() => {
                        running = false
                      })
                    }
}
