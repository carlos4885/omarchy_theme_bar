// nfs-heat.qml — Hybrid Sport Canvas Edition (Inclinación customizable de paralelogramos)
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-heat"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property real barH: bar ? bar.barSize : 26
  readonly property color red: "#ff2b4d"
  readonly property color blue: "#2f6bff"
  readonly property color yellow: "#ffb703"
  readonly property color pink: "#ff2bd6"

  // Ángulo de inclinación personalizable (Ej: 15 para inclinar hacia adelante)
  readonly property real slantAngle: 15

  // Readings
  property real temp: 0        // °C, 0 = no sensor found
  property real loadPct: 0     // 1-min load average as % of cores

  readonly property string source: settings && settings.source ? String(settings.source) : "auto"
  readonly property string mode: source === "load" ? "load" : (source === "temp" ? "temp" : (temp > 0 ? "temp" : "load"))
  readonly property var limits: settings && settings.thresholds && settings.thresholds.length >= 5
    ? settings.thresholds
    : (mode === "temp" ? [55, 65, 75, 85, 92] : [20, 40, 60, 80, 100])
  readonly property real value: mode === "temp" ? temp : loadPct
  readonly property int level: {
    var n = 0
    for (var i = 0; i < 5; i++) if (value >= Number(limits[i])) n++
    return n
  }
  readonly property bool chase: level >= 4
  readonly property string tipText: "TEMP " + level + "/5  ·  " + (mode === "temp" ? Math.round(temp) + " °C" : "load " + Math.round(loadPct) + " %")

  // Alert colour (flashes red/blue when hot/chase)
  readonly property color alertColor: phase ? red : blue

  property bool phase: false
  Timer {
    interval: 320
    running: root.chase && root.visible
    repeat: true
    onTriggered: root.phase = !root.phase
  }

  implicitWidth: gaugeContainer.width
  implicitHeight: barH

  function sample(line) {
    var f = line.trim().split(/\s+/)
    if (f.length < 3) return
    var t = Number(f[0]) / 1000
    var l = Number(f[1])
    var n = Math.max(1, Number(f[2]))
    if (!isNaN(t)) root.temp = t
    if (!isNaN(l)) root.loadPct = 100 * l / n
  }

  Process {
    running: root.visible
    command: ["sh", "-c", `
      while :; do
        t=$(cat /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '$1>m && $1<120000 {m=$1} END {print m+0}')
        read l _ < /proc/loadavg
        echo "$t $l $(nproc)"
        sleep 3
      done`]
    stdout: SplitParser {
      onRead: line => root.sample(line)
    }
  }

  Rectangle {
    id: gaugeContainer
    anchors.verticalCenter: parent.verticalCenter
    width: 116
    height: root.barH - 4
    radius: height / 2.4
    color: "#080612"
    border.width: 1.5
    border.color: root.chase ? root.alertColor : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)

    // Remache metálico izquierdo
    Rectangle {
      width: 4; height: 4; radius: 2
      x: 6
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
      border.width: 0.5
      border.color: "#000000"
    }

    // "C" (Cold)
    Text {
      x: 14
      anchors.verticalCenter: parent.verticalCenter
      text: "C"
      color: root.fg
      font.pixelSize: 10
      font.bold: true
      font.family: "Monospace"
    }

    // Canvas Dibujador de Bloques Inclinados (Garantiza inclinación exacta)
    Canvas {
      id: slantedCanvas
      x: 26
      width: 46
      height: parent.height
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var numBlocks = 5
        var blockWidth = 5.5
        var blockHeight = 12
        var gap = 2.5
        var startX = 4
        var startY = (height - blockHeight) / 2

        // Cálculo exacto del desplazamiento según ángulo rad
        var rad = (root.slantAngle * Math.PI) / 180
        var dx = Math.tan(rad) * blockHeight

        for (var i = 0; i < numBlocks; i++) {
          var isActive = i < root.level
          var col = isActive 
            ? (i >= 3 ? (root.chase ? root.alertColor : root.red) : (i === 2 ? root.yellow : root.fg))
            : Qt.rgba(1, 1, 1, 0.08)

          var bx = startX + i * (blockWidth + gap)

          ctx.fillStyle = col
          ctx.beginPath()
          ctx.moveTo(bx + dx, startY)
          ctx.lineTo(bx + blockWidth + dx, startY)
          ctx.lineTo(bx + blockWidth, startY + blockHeight)
          ctx.lineTo(bx, startY + blockHeight)
          ctx.closePath()
          ctx.fill()
        }
      }

      Component.onCompleted: requestPaint()
      onHeightChanged: requestPaint()

      Connections {
        target: root
        function onLevelChanged() { slantedCanvas.requestPaint() }
        function onPhaseChanged() { slantedCanvas.requestPaint() }
        function onFgChanged() { slantedCanvas.requestPaint() }
      }
    }

    // "H" (Hot)
    Text {
      x: 75
      anchors.verticalCenter: parent.verticalCenter
      text: "H"
      color: root.red
      font.pixelSize: 10
      font.bold: true
      font.family: "Monospace"
    }

    // Icono Termómetro Neón
    Canvas {
      id: tempSymbol
      x: 89
      width: 12
      height: parent.height
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var col = root.chase ? root.alertColor : root.pink
        var cy = height / 2

        ctx.fillStyle = col
        ctx.strokeStyle = col

        ctx.beginPath()
        ctx.rect(4.5, cy - 5, 2, 7)
        ctx.fill()

        ctx.beginPath()
        ctx.arc(5.5, cy + 3, 2.5, 0, Math.PI * 2)
        ctx.fill()

        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(7.5, cy - 3); ctx.lineTo(9.5, cy - 3)
        ctx.moveTo(7.5, cy - 1); ctx.lineTo(9.5, cy - 1)
        ctx.stroke()
      }

      Component.onCompleted: requestPaint()
      onHeightChanged: requestPaint()

      Connections {
        target: root
        function onChaseChanged() { tempSymbol.requestPaint() }
        function onPhaseChanged() { tempSymbol.requestPaint() }
      }
    }

    // Remache metálico derecho
    Rectangle {
      width: 4; height: 4; radius: 2
      x: parent.width - 9
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
      border.width: 0.5
      border.color: "#000000"
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
  onTipTextChanged: if (hover.hovered && root.bar) root.bar.showTooltip(root, root.tipText)
}
