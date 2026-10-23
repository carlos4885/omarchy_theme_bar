// nfs-ignition — push-start button for the Omarchy bar.
// Left click : amber ring blinks while the engine cranks, turns green as it catches,
//              the Omarchy menu opens, then the button settles back to idle.
// Right click: quick green flash, opens a terminal.
// Settings (optional): sound (false = silent start).
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-ignition"
  property var settings

  readonly property color amber: "#ffb000"
  readonly property color amberDim: "#7a5200"
  readonly property color green: "#3dff8a"

  implicitWidth: 30
  implicitHeight: bar ? bar.barSize : 26

  // How long the ring blinks before the engine "catches" (ms)
  property int crankMs: 640

  // Engine sound: sounds/nfs-engine-start.wav, installed next to the modules
  readonly property bool soundOn: !(settings && settings.sound === false)
  Process {
    id: engine
    command: ["sh", "-c", `
      f="$HOME/.config/omarchy/bar/sounds/nfs-engine-start.wav"
      [ -f "$f" ] || exit 0
      pw-play "$f" 2>/dev/null || paplay "$f" 2>/dev/null || aplay -q "$f" 2>/dev/null`]
  }
  function crank() { if (root.soundOn && !engine.running) engine.running = true }

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
  }

  // 0 = idle (amber), 1 = running (green)
  property real lit: 0
  property real ringOp: 0.35
  property bool busy: false

  readonly property color tone: mix(amber, green, lit)
  readonly property color edge: mix(amberDim, green, lit)

  Item {
    id: cyl
    width: 24
    height: 24
    anchors.centerIn: parent
    scale: hover.hovered ? 1.08 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    // Soft glow behind the button
    Rectangle {
      anchors.centerIn: parent
      width: 30; height: 30; radius: 15
      color: root.tone
      opacity: 0.08 + 0.2 * root.lit + (hover.hovered ? 0.06 : 0)
    }

    // Bezel
    Rectangle {
      id: bezel
      anchors.fill: parent
      radius: width / 2
      color: "#07040d"
      border.width: 1.5
      border.color: root.edge
    }

    // Status ring (blinks while cranking)
    Rectangle {
      anchors.fill: parent
      anchors.margins: 2.4
      radius: width / 2
      color: "transparent"
      border.width: 1.4
      border.color: root.tone
      opacity: root.ringOp
    }

    // Centre disc
    Rectangle {
      id: disc
      width: 14; height: 14; radius: 7
      anchors.centerIn: parent
      border.width: 1
      border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.55)
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#2a2438" }
        GradientStop { position: 1.0; color: "#0a0710" }
      }
      scale: press.pressed ? 0.92 : 1.0
      Behavior on scale { NumberAnimation { duration: 80 } }

      // Glass highlight
      Rectangle {
        width: 8; height: 4; radius: 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: 1.5
        color: "white"
        opacity: 0.09
      }

      // Power symbol
      Canvas {
        id: icon
        width: 10; height: 10
        anchors.centerIn: parent
        property color c: root.tone
        onCChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var s = width / 24
          ctx.scale(s, s)
          ctx.strokeStyle = c
          ctx.lineWidth = 2.6
          ctx.lineCap = "round"
          ctx.beginPath()
          ctx.moveTo(12, 3); ctx.lineTo(12, 11)
          ctx.stroke()
          ctx.beginPath()
          ctx.arc(12, 12.4, 8, -135 * Math.PI / 180, -45 * Math.PI / 180, true)
          ctx.stroke()
        }
      }
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.bar) return
      if (hovered) root.bar.showTooltip(root, "Ignition")
      else root.bar.hideTooltip(root)
    }
  }

  SequentialAnimation {
    id: startAnim
    ScriptAction { script: { root.busy = true; root.crank() } }
    // Cranking: the ring blinks amber
    SequentialAnimation {
      loops: 2
      NumberAnimation { target: root; property: "ringOp"; to: 1.0; duration: root.crankMs / 4 }
      NumberAnimation { target: root; property: "ringOp"; to: 0.2; duration: root.crankMs / 4 }
    }
    // Engine catches: turns green and opens the menu
    ParallelAnimation {
      NumberAnimation { target: root; property: "lit"; to: 1; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "ringOp"; to: 1.0; duration: 200 }
    }
    ScriptAction { script: if (root.bar) root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'") }
    PauseAnimation { duration: root.soundOn ? 700 : 450 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "lit"; to: 0; duration: 320; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "ringOp"; to: 0.35; duration: 320 }
    }
    ScriptAction { script: root.busy = false }
  }

  SequentialAnimation {
    id: accAnim
    ScriptAction { script: root.busy = true }
    ParallelAnimation {
      NumberAnimation { target: root; property: "lit"; to: 1; duration: 180; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "ringOp"; to: 1.0; duration: 180 }
    }
    ScriptAction { script: if (root.bar) root.bar.run("xdg-terminal-exec") }
    PauseAnimation { duration: 350 }
    ParallelAnimation {
      NumberAnimation { target: root; property: "lit"; to: 0; duration: 260; easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "ringOp"; to: 0.35; duration: 260 }
    }
    ScriptAction { script: root.busy = false }
  }

  MouseArea {
    id: press
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (root.busy) return
      if (mouse.button === Qt.RightButton) accAnim.restart()
      else startAnim.restart()
    }
  }
}
