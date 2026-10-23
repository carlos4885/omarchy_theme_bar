// nfs-handbrake — parking-brake telltale (P in a circle). Click to apply the handbrake: while it is
// on, the red lamp is lit and the computer will not go idle or suspend. Click again to release it.
// The inhibitor is a `systemd-inhibit` held by this module, so it is released if the bar restarts.
// Settings (all optional):
//   hideWhenOff   true | false  (default false: the lamp stays visible, dark, when released)
//   blink         true | false  (default false: pulse softly while applied)
//   inhibit       what to block (default "idle:sleep")
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-handbrake"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property string family: bar ? bar.fontFamily : "monospace"
  readonly property real barH: bar ? bar.barSize : 26
  readonly property color red: "#ff2b4d"
  readonly property bool hideWhenOff: !!(settings && settings.hideWhenOff === true)
  readonly property bool blinkOn: !!(settings && settings.blink === true)
  readonly property string what: settings && settings.inhibit ? String(settings.inhibit) : "idle:sleep"

  property bool on: false
  readonly property string tipText: on ? "Handbrake ON  ·  the computer will not sleep  (click to release)"
                                       : "Handbrake off  ·  click to keep the computer awake"

  visible: on || !hideWhenOff
  implicitWidth: visible ? 30 : 0
  implicitHeight: barH

  // The inhibitor lives exactly as long as this process does
  Process {
    running: root.on
    command: ["systemd-inhibit", "--what=" + root.what, "--who=Night Run",
              "--why=Handbrake is on", "--mode=block", "sleep", "infinity"]
  }

  property real pulse: 1
  SequentialAnimation on pulse {
    running: root.on && root.blinkOn && root.visible
    loops: Animation.Infinite
    NumberAnimation { from: 1; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.45; to: 1; duration: 900; easing.type: Easing.InOutSine }
  }

  Rectangle {
    id: body
    anchors.centerIn: parent
    width: 26
    height: root.barH - 6
    radius: 6
    color: "#07040d"
    border.width: 1
    border.color: root.on ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.8)
                          : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    Rectangle {   // lamp glow
      anchors.centerIn: parent
      width: 20; height: 20; radius: 10
      color: root.red
      opacity: root.on ? 0.18 * root.pulse : 0
    }

    Canvas {
      id: icon
      anchors.centerIn: parent
      width: 20; height: 20
      readonly property color tone: root.on ? root.red : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
      onToneChanged: requestPaint()
      Component.onCompleted: requestPaint()
      opacity: root.on ? root.pulse : 1
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineCap = "round"
        ctx.strokeStyle = tone
        ctx.lineWidth = 1.5
        // circle
        ctx.beginPath(); ctx.arc(10, 10, 5.6, 0, 2 * Math.PI); ctx.stroke()
        // the two brackets around it
        ctx.beginPath(); ctx.arc(10, 10, 8.6, 2.35, 3.93); ctx.stroke()
        ctx.beginPath(); ctx.arc(10, 10, 8.6, -0.79, 0.79); ctx.stroke()
      }
    }

    Text {
      anchors.centerIn: parent
      text: "P"
      color: root.on ? root.red : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
      opacity: root.on ? root.pulse : 1
      font.family: root.family
      font.pixelSize: 9
      font.bold: true
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.on = !root.on
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
