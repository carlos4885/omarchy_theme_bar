// nfs-fuel — battery as a fuel gauge. Below 15 % the needle falls into the red and the whole
// module flashes red / blue like a police light bar. Charging swaps the pump for a bolt.
// Hidden on machines without a battery.
// Click toggles the Omarchy power panel (`omarchy-shell shell toggle omarchy.power`).
// Settings (all optional): low (percent, default 15), showPercent (true | false), accent,
//   clickCommand (shell command run on click, default "omarchy-shell shell toggle omarchy.power").
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-fuel"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property string family: bar ? bar.fontFamily : "monospace"
  readonly property real barH: bar ? bar.barSize : 26
  readonly property color red: "#ff2b4d"
  readonly property color blue: "#2f6bff"
  readonly property real lowAt: settings && settings.low ? Number(settings.low) : 15
  readonly property bool showPercent: !!(settings && settings.showPercent === true)
  readonly property string clickCommand: settings && settings.clickCommand ? String(settings.clickCommand) : "omarchy-shell shell toggle omarchy.power"

  property bool present: false
  property real level: 100
  property string status: "Unknown"
  readonly property bool charging: status === "Charging"
  readonly property bool low: present && level < lowAt && !charging
  readonly property string tipText: (low ? "LOW FUEL  ·  " : "Fuel  ·  ") + Math.round(level) + " %  ·  " + status.toLowerCase()

  property real needle: level
  Behavior on needle { SmoothedAnimation { velocity: 45 } }

  // Police lights: flips every 280 ms, only while the battery is low
  property bool phase: false
  Timer {
    interval: 280
    running: root.low && root.visible
    repeat: true
    onTriggered: root.phase = !root.phase
  }

  visible: present
  implicitWidth: present ? body.width : 0
  implicitHeight: barH

  // ---- battery sampling ------------------------------------------------------
  function sample(line) {
    line = line.trim()
    if (line === "none") { root.present = false; return }
    var i = line.indexOf(" ")
    var n = Number(i < 0 ? line : line.slice(0, i))
    if (isNaN(n)) return
    root.present = true
    root.level = Math.max(0, Math.min(100, n))
    root.status = i < 0 ? "Unknown" : line.slice(i + 1)
  }

  Process {
    running: true   // keeps polling while hidden, so the gauge appears if a battery shows up
    command: ["sh", "-c", `
      while :; do
        b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
        if [ -z "$b" ]; then echo none; else echo "$(cat "$b/capacity") $(cat "$b/status")"; fi
        sleep 5
      done`]
    stdout: SplitParser {
      onRead: line => root.sample(line)
    }
  }

  // ---- housing -------------------------------------------------------------
  Rectangle {
    id: body
    anchors.verticalCenter: parent.verticalCenter
    height: root.barH - 4
    width: row.implicitWidth + 12
    radius: 6
    color: "#07040d"
    border.width: 1
    border.color: root.low ? (root.phase ? root.red : root.blue) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 4

      Rectangle {   // left beacon (red)
        anchors.verticalCenter: parent.verticalCenter
        width: 5; height: 5; radius: 2.5
        color: root.low ? (root.phase ? "#ff2b4d" : "#4a1020") : "#1a1424"
      }

      // ---- gauge ----
      Item {
        id: gauge
        width: 36
        height: body.height - 2
        readonly property real cx: width / 2
        readonly property real cy: height - 2
        readonly property real r: 15
        readonly property real span: 110 * Math.PI / 180   // needle sweeps -55° .. +55°

        Canvas {
          id: dial
          anchors.fill: parent
          Component.onCompleted: requestPaint()
          Connections {
            target: root
            function onFgChanged() { dial.requestPaint() }
            function onLowAtChanged() { dial.requestPaint() }
          }
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = gauge.cx, cy = gauge.cy, r = gauge.r
            var f = root.fg, d = root.red
            function ang(p) { return -Math.PI / 2 + (p / 100 - 0.5) * gauge.span }

            ctx.lineWidth = 2.4
            ctx.strokeStyle = Qt.rgba(d.r, d.g, d.b, 0.95)
            ctx.beginPath(); ctx.arc(cx, cy, r - 1.4, ang(0), ang(root.lowAt)); ctx.stroke()
            ctx.strokeStyle = Qt.rgba(f.r, f.g, f.b, 0.45)
            ctx.beginPath(); ctx.arc(cx, cy, r - 1.4, ang(root.lowAt), ang(100)); ctx.stroke()

            ctx.lineWidth = 1
            var marks = [0, 25, 50, 75, 100]
            for (var k = 0; k < marks.length; k++) {
              var a = ang(marks[k]), c = Math.cos(a), s = Math.sin(a)
              var end = (marks[k] === 0 || marks[k] === 100) ? 5.2 : 4.2
              ctx.strokeStyle = marks[k] < root.lowAt ? Qt.rgba(d.r, d.g, d.b, 0.9) : Qt.rgba(f.r, f.g, f.b, 0.7)
              ctx.beginPath()
              ctx.moveTo(cx + c * (r - 3.6), cy + s * (r - 3.6))
              ctx.lineTo(cx + c * (r - 3.6 - end * 0.5), cy + s * (r - 3.6 - end * 0.5))
              ctx.stroke()
            }
          }
        }

        Text {
          x: 0; y: 8
          text: "E"
          color: root.red
          font.family: root.family
          font.pixelSize: 7
          font.bold: true
        }
        Text {
          x: gauge.width - width; y: 8
          text: "F"
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.9)
          font.family: root.family
          font.pixelSize: 7
          font.bold: true
        }

        Item {   // needle, pivoting at the bottom centre
          x: gauge.cx
          y: gauge.cy
          rotation: (Math.max(0, Math.min(100, root.needle)) / 100 - 0.5) * 110
          Rectangle {
            x: -0.7
            y: -(gauge.r - 4)
            width: 1.4
            height: gauge.r - 4 + 1.5
            radius: 0.7
            color: root.low ? root.red : "#f4e9ff"
          }
        }
        Rectangle {
          x: gauge.cx - 2; y: gauge.cy - 2
          width: 4; height: 4; radius: 2
          color: "#15111d"
          border.width: 1
          border.color: root.low ? root.red : "#aab0bd"
        }
      }

      // ---- pump / bolt telltale ----
      Canvas {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        width: 10; height: 12
        readonly property color tone: root.charging ? root.accent
          : root.low ? (root.phase ? root.red : "#5a1626")
          : root.level <= 25 ? "#ffb020"
          : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
        readonly property bool bolt: root.charging
        onToneChanged: requestPaint()
        onBoltChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.fillStyle = tone
          ctx.strokeStyle = tone
          if (bolt) {
            ctx.beginPath()
            ctx.moveTo(6, 0.5); ctx.lineTo(1.5, 7); ctx.lineTo(4.6, 7)
            ctx.lineTo(3.6, 11.5); ctx.lineTo(8.8, 4.6); ctx.lineTo(5.4, 4.6)
            ctx.closePath()
            ctx.fill()
          } else {
            ctx.fillRect(1, 1.5, 5.5, 9)           // body
            ctx.fillRect(0, 10.5, 7.5, 1.5)        // base
            ctx.clearRect(2.2, 2.7, 3.1, 2.6)      // display window
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(7.5, 3); ctx.lineTo(9, 4.5); ctx.lineTo(9, 8.5)
            ctx.stroke()
          }
        }
      }

      Text {
        visible: root.showPercent
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(root.level)
        color: root.low ? root.red : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.95)
        font.family: root.family
        font.pixelSize: 10
        font.bold: true
      }

      Rectangle {   // right beacon (blue)
        anchors.verticalCenter: parent.verticalCenter
        width: 5; height: 5; radius: 2.5
        color: root.low ? (root.phase ? "#14264d" : "#2f6bff") : "#1a1424"
      }
    }
  }

  MouseArea {
    anchors.fill: body
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["sh", "-c", root.clickCommand])
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, root.tipText)
      else root.bar.hideTooltip(root)
    }
  }
  onTipTextChanged: if (hover.hovered && root.bar) root.bar.showTooltip(root, root.tipText)
}
