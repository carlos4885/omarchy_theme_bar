// nfs-tacho — CPU load as an engine tachometer: half-circle dial, redline from 90 %.
// Hover: load and rpm. Click: open btop.
// Settings (all optional): redline (percent, default 90), maxRpm (default 8000), accent.
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-tacho"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property color red: "#ff2b4d"
  readonly property real redline: settings && settings.redline ? Number(settings.redline) : 90
  readonly property real maxRpm: settings && settings.maxRpm ? Number(settings.maxRpm) : 8000
  readonly property real barH: bar ? bar.barSize : 26

  // 0..100, straight from /proc/stat. `needle` chases it so the dial feels mechanical.
  property real load: 0
  property real needle: load
  readonly property bool hot: load >= redline
  readonly property int rpm: Math.round(load / 100 * maxRpm / 10) * 10
  readonly property string tipText: "CPU " + Math.round(load) + " %  ·  " + rpm + " rpm" + (hot ? "  ·  REDLINE" : "")

  Behavior on needle { SmoothedAnimation { velocity: 260 } }

  implicitWidth: 44
  implicitHeight: barH

  // Dial geometry: centre sits at the bottom edge, the plate is the upper half-disc
  readonly property real cx: width / 2
  readonly property real cy: height - 5
  readonly property real rad: Math.min(width / 2 - 1.5, cy - 2)

  // ---- CPU sampling ----------------------------------------------------------
  property real prevTotal: 0
  property real prevIdle: 0

  function sample(line) {
    var f = line.trim().split(/\s+/)
    if (f[0] !== "cpu" || f.length < 6) return
    var v = f.slice(1).map(Number)
    var idle = v[3] + (v[4] || 0)
    var total = 0
    for (var i = 0; i < Math.min(v.length, 8); i++) total += v[i]
    if (root.prevTotal > 0 && total > root.prevTotal) {
      var l = 100 * (1 - (idle - root.prevIdle) / (total - root.prevTotal))
      root.load = Math.max(0, Math.min(100, l))
    }
    root.prevTotal = total
    root.prevIdle = idle
  }

  Process {
    running: root.visible
    command: ["sh", "-c", "while :; do head -n1 /proc/stat; sleep 1; done"]
    stdout: SplitParser {
      onRead: line => root.sample(line)
    }
  }

  // ---- dial ----------------------------------------------------------------
  Canvas {
    id: face
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
    Connections {
      target: root
      function onFgChanged() { face.requestPaint() }
      function onRedlineChanged() { face.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var P = Math.PI, cx = root.cx, cy = root.cy, r = root.rad
      var f = root.fg, d = root.red
      function ang(p) { return P + (p / 100) * P }

      // plate
      ctx.beginPath()
      ctx.arc(cx, cy, r, P, 2 * P)
      ctx.closePath()
      ctx.fillStyle = "#07040d"
      ctx.fill()
      ctx.lineWidth = 1
      ctx.strokeStyle = Qt.rgba(f.r, f.g, f.b, 0.55)
      ctx.stroke()

      // scale band, red from the redline on
      ctx.lineWidth = 2.4
      ctx.strokeStyle = Qt.rgba(f.r, f.g, f.b, 0.45)
      ctx.beginPath()
      ctx.arc(cx, cy, r - 3.4, P, ang(root.redline))
      ctx.stroke()
      ctx.strokeStyle = Qt.rgba(d.r, d.g, d.b, 0.95)
      ctx.beginPath()
      ctx.arc(cx, cy, r - 3.4, ang(root.redline), 2 * P)
      ctx.stroke()

      // ticks every 10 %
      ctx.lineWidth = 1
      for (var p = 0; p <= 100; p += 10) {
        var a = ang(p), c = Math.cos(a), s = Math.sin(a)
        ctx.strokeStyle = p >= root.redline ? Qt.rgba(d.r, d.g, d.b, 0.9) : Qt.rgba(f.r, f.g, f.b, 0.7)
        ctx.beginPath()
        ctx.moveTo(cx + c * (r - 5.8), cy + s * (r - 5.8))
        ctx.lineTo(cx + c * (r - 7.8), cy + s * (r - 7.8))
        ctx.stroke()
      }
    }
  }

  // Red zone glows while the needle is in it
  Canvas {
    id: glow
    anchors.fill: parent
    visible: root.hot
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var P = Math.PI
      ctx.lineWidth = 4.2
      ctx.strokeStyle = Qt.rgba(root.red.r, root.red.g, root.red.b, 0.55)
      ctx.beginPath()
      ctx.arc(root.cx, root.cy, root.rad - 3.4, P + root.redline / 100 * P, 2 * P)
      ctx.stroke()
    }
    SequentialAnimation on opacity {
      running: root.hot && root.visible
      loops: Animation.Infinite
      NumberAnimation { from: 0.25; to: 1; duration: 220 }
      NumberAnimation { from: 1; to: 0.25; duration: 220 }
    }
  }

  // Needle: a zero-size item at the pivot, so rotation happens around the hub
  Item {
    x: root.cx
    y: root.cy
    rotation: -90 + Math.max(0, Math.min(100, root.needle)) * 1.8
    Rectangle {
      readonly property real len: root.rad - 4.5
      x: -0.8
      y: -len
      width: 1.6
      height: len + 2
      radius: 0.8
      color: root.hot ? root.red : "#f4e9ff"
    }
  }
  Rectangle {   // hub
    x: root.cx - 2.6
    y: root.cy - 2.6
    width: 5.2; height: 5.2; radius: 2.6
    color: "#15111d"
    border.width: 1
    border.color: root.hot ? root.red : "#aab0bd"
  }

  // ---- input ---------------------------------------------------------------
  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, root.tipText)
      else root.bar.hideTooltip(root)
    }
  }
  onTipTextChanged: if (hover.hovered && root.bar) root.bar.showTooltip(root, root.tipText)

  MouseArea {
    anchors.fill: parent
    onClicked: if (root.bar) root.bar.run("xdg-terminal-exec btop")
  }
}
