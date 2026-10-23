// nfs-odometer — uptime as a mechanical odometer. One minute of uptime is one kilometre
// (the last wheel, the tenths, turns every six seconds). Hover for the real uptime.
// Settings (all optional): kmPerMinute (default 1), accent.
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-odometer"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property string family: bar ? bar.fontFamily : "monospace"
  readonly property real barH: bar ? bar.barSize : 26
  readonly property real kmPerMinute: settings && settings.kmPerMinute ? Number(settings.kmPerMinute) : 1

  property real seconds: 0
  readonly property real tenths: Math.floor(seconds / 60 * kmPerMinute * 10)
  readonly property real wheelH: 14
  readonly property real wheelW: 9

  // Wheels follow instantly for the first reading, then roll
  property bool armed: false
  Timer { id: arm; interval: 80; onTriggered: root.armed = true }

  readonly property string tipText: {
    var s = Math.floor(seconds)
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return "Odometer  ·  up " + (d > 0 ? d + "d " : "") + h + "h " + m + "m"
  }

  implicitWidth: row.implicitWidth + 14
  implicitHeight: barH

  Process {
    running: root.visible
    command: ["sh", "-c", "while :; do cut -d' ' -f1 /proc/uptime; sleep 5; done"]
    stdout: SplitParser {
      onRead: line => {
        var v = Number(line.trim())
        if (isNaN(v)) return
        root.seconds = v
        if (!root.armed && !arm.running) arm.start()
      }
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.barH - 6
    radius: 5
    color: "#07040d"
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 1

      // Five whole-km wheels and one tenths wheel
      Repeater {
        model: 6
        Item {
          id: wheel
          required property int index
          readonly property bool tenthsWheel: index === 5
          // Ever-growing integer for this wheel's place; the column only shows it modulo 10
          readonly property real target: Math.floor(root.tenths / Math.pow(10, 5 - index))
          property real shown: target
          Behavior on shown { enabled: root.armed; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

          width: root.wheelW
          height: root.wheelH
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            anchors.fill: parent
            radius: 2
            color: wheel.tenthsWheel ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28) : "#120a1f"
            border.width: 1
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, wheel.tenthsWheel ? 0.0 : 0.22)
            clip: true

            Column {
              y: -((wheel.shown % 10)) * root.wheelH
              Repeater {
                model: 11   // 0..9 and a second 0, so 9 → 0 rolls forward
                Text {
                  required property int index
                  width: root.wheelW - 2
                  height: root.wheelH
                  x: 1
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: index % 10
                  color: wheel.tenthsWheel ? "#ffe8fa" : "#f4e9ff"
                  font.family: root.family
                  font.pixelSize: 12
                  font.bold: true
                }
              }
            }

            // Cylinder shading
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.7) }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.7; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
              }
            }
          }
        }
      }

      Item { width: 3; height: 1 }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "KM"
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.85)
        font.family: root.family
        font.pixelSize: 8
        font.bold: true
        font.letterSpacing: 1
      }
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, root.tipText)
      else root.bar.hideTooltip(root)
    }
  }
}
