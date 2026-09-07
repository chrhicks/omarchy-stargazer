// Isolated Qt rendering fixture; does not connect to or restart the desktop shell.
import QtQuick
import QtQuick.Window
import "../CloudField.js" as Clouds

Window {
  id: root

  property int index: 0
  property var covers: [0, .15, .5, 1]
  property var lights: [0, .3, 1]
  property color foreground: "#cacccc"
  property color background: "#101315"
  property real elapsed: 0

  width: 750
  height: 190
  visible: true

  Canvas {
    id: canvas

    smooth: true
    anchors.fill: parent

    onPaint: {
      var c = getContext('2d'), cover = root.covers[root.index % 4], daylight = root.lights[Math.floor(
                                                                                              root.index / 4)]
      c.clearRect(0, 0, width, height)
      c.fillStyle = root.background
      c.fillRect(0, 0, width, height)
      if (daylight < .65)
        for (var i = 0; i < 130; i++) {
          c.fillStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .35 * (1 - daylight))
          c.fillRect(Clouds.hash(i, 14) * width, Clouds.hash(i, 35) * height, 1, 1)
        }
      var start = Date.now()
      Clouds.paint(c, width, height, cover, daylight, root.foreground, root.background)
      root.elapsed = Date.now() - start
    }
    onPainted: saver.restart()
  }

  Timer {
    id: saver

    interval: 30

    onTriggered: {
      var path = '/tmp/stargazer-cloud-check/state-' + root.index + '-ms' + root.elapsed + '.png'
      if (!canvas.save(path)) {
        console.error('SAVE FAILED ' + path)
        Qt.exit(1)
        return
      }
      console.log('CLOUD_QA ' + JSON.stringify({
                                                 index: root.index,
                                                 cover: root.covers[root.index % 4],
                                                 daylight: root.lights[Math.floor(root.index / 4)],
                                                 ms: root.elapsed
                                               }))
      root.index++
      if (root.index === 12)
        Qt.quit()
      else
        canvas.requestPaint()
    }
  }
}
