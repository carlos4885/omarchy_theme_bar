// nfs-heat — wanted level. Styled as a car engine temperature gauge (C ... H) matching the dashboard look.
// Settings (all optional):
//   source     "auto" (default: temperature, falls back to load) | "temp" | "load"
//   thresholds five numbers; °C for temp (default 55,65,75,85,92), percent of load for load
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
  readonly property color pink: "#ff2bd6"

  // Readings
  property real temp: 0        // °C, 0 = no sensor found
  property real loadPct: 0     // 1-min load average as % of the cores

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

  // Alert colour (flashes red/blue when hot)
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
    width: 108
    height: root.barH - 6
    radius: height / 2.6
    color: "#07040d"
    border.width: 1
    border.color: root.chase ? root.alertColor : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    // Tornillos / remaches laterales
    Rectangle {
      width: 4; height: 4; radius: 2
      x: 6
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.3)
    }
    Rectangle {
      width: 4; height: 4; radius: 2
      x: parent.width - 10
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.3)
    }

    // "C" (Cold) en el extremo izquierdo
    Text {
      x: 15
      anchors.verticalCenter: parent.verticalCenter
      text: "C"
      color: root.fg
      font.pixelSize: 9
      font.bold: true
    }

    // Arco del medidor
    Canvas {
      id: gaugeCanvas
      x: 26
      width: 40
      height: parent.height
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var cx = width / 2
        var cy = height - 2
        var radius = Math.min(18, height - 5)
        var a0 = -Math.PI * 0.85
        var a1 = -Math.PI * 0.15
        var span = a1 - a0

        ctx.lineCap = "butt"

        // 1. Arco base
        ctx.beginPath()
        ctx.arc(cx, cy, radius, a0, a1, false)
        ctx.strokeStyle = Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.85)
        ctx.lineWidth = 2
        ctx.stroke()

        // 2. Zona roja (caliente), extremo derecho
        ctx.beginPath()
        ctx.arc(cx, cy, radius, a0 + span * 0.78, a1, false)
        ctx.strokeStyle = root.red
        ctx.lineWidth = 2
        ctx.stroke()

        // 3. Marcas de graduación
        for (var i = 0; i <= 5; i++) {
          var ang = a0 + (i / 5) * span
          ctx.beginPath()
          ctx.moveTo(cx + (radius - 5) * Math.cos(ang), cy + (radius - 5) * Math.sin(ang))
          ctx.lineTo(cx + (radius - 2) * Math.cos(ang), cy + (radius - 2) * Math.sin(ang))
          ctx.strokeStyle = Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
          ctx.lineWidth = 1
          ctx.stroke()
        }

        // 4. Aguja según nivel (0..5)
        var lv = Math.max(0, Math.min(5, root.level))
        var na = a0 + (lv / 5) * span
        var needleColor = root.chase ? root.alertColor : "#ffffff"

        ctx.strokeStyle = needleColor
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.lineTo(cx + (radius - 3) * Math.cos(na), cy + (radius - 3) * Math.sin(na))
        ctx.stroke()

        // 5. Pivote
        ctx.fillStyle = "#1a1a24"
        ctx.beginPath()
        ctx.arc(cx, cy, 2.6, 0, Math.PI * 2)
        ctx.fill()
        ctx.strokeStyle = needleColor
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.arc(cx, cy, 2.6, 0, Math.PI * 2)
        ctx.stroke()
        ctx.fillStyle = needleColor
        ctx.beginPath()
        ctx.arc(cx, cy, 0.9, 0, Math.PI * 2)
        ctx.fill()
      }

      Component.onCompleted: requestPaint()
      onHeightChanged: requestPaint()

      Connections {
        target: root
        function onLevelChanged() { gaugeCanvas.requestPaint() }
        function onPhaseChanged() { gaugeCanvas.requestPaint() }
        function onFgChanged() { gaugeCanvas.requestPaint() }
      }
    }

    // "H" (Hot) en rojo, a la derecha del arco
    Text {
      x: 67
      anchors.verticalCenter: parent.verticalCenter
      text: "H"
      color: root.red
      font.pixelSize: 9
      font.bold: true
    }

    // Icono de temperatura de motor (termómetro sobre líneas de agua)
    Canvas {
      id: tempSymbol
      x: 80
      width: 14
      height: parent.height
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var col = root.chase ? root.alertColor : root.pink
        var cy = height / 2

        ctx.fillStyle = col
        ctx.strokeStyle = col

        // Termómetro: tallo + bulbo
        ctx.beginPath()
        ctx.rect(5.5, cy - 6, 2, 8)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(6.5, cy + 3.5, 2.6, 0, Math.PI * 2)
        ctx.fill()

        // Marcas del tallo
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(8.5, cy - 4); ctx.lineTo(10.5, cy - 4)
        ctx.moveTo(8.5, cy - 1.5); ctx.lineTo(10.5, cy - 1.5)
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
