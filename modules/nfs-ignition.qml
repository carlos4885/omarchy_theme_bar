// nfs-ignition — Porsche-style ignition switch for the Omarchy bar.
// Left click : the key turns to START, the engine cranks and catches, the Omarchy menu opens,
//              the key springs back.
// Right click: key turns to ACC/ON and back, opens a terminal.
// Settings (optional): accent, sound (false = silent start).
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-ignition"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property color gold: "#d9b24c"

  implicitWidth: 30
  implicitHeight: bar ? bar.barSize : 26

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

  // 0 = OFF, 45 = ON, 90 = START
  property real turn: 0
  property bool busy: false
  readonly property real power: Math.max(0, Math.min(1, turn / 90))

  Item {
    id: cyl
    width: 24
    height: 24
    anchors.centerIn: parent
    scale: hover.hovered ? 1.08 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    // Glow that builds as the key turns
    Rectangle {
      anchors.centerIn: parent
      width: 30; height: 30; radius: 15
      color: root.accent
      opacity: 0.16 * root.power + (hover.hovered ? 0.08 : 0)
    }
    Rectangle {
      anchors.centerIn: parent
      width: 27; height: 27; radius: 13.5
      color: root.accent
      opacity: 0.26 * root.power
    }

    // Bezel
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "#07040d"
      border.width: 1.5
      border.color: Qt.tint(root.fg, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.power))
    }

    // OFF / ON / START marks
    Repeater {
      model: [0, 45, 90]
      Rectangle {
        required property int modelData
        width: 2.4; height: 2.4; radius: 1.2
        x: 12 + 8.6 * Math.sin(modelData * Math.PI / 180) - width / 2
        y: 12 - 8.6 * Math.cos(modelData * Math.PI / 180) - height / 2
        color: (modelData > 0 && root.turn >= modelData - 1) ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.45)
      }
    }

    // The key (seen head-on: a flat black head with a gold crest)
    Item {
      width: 24; height: 24
      anchors.centerIn: parent
      rotation: root.turn
      transformOrigin: Item.Center

      Rectangle {
        anchors.centerIn: parent
        width: 6; height: 15; radius: 3
        color: "#15111d"
        border.width: 1
        border.color: "#aab0bd"
      }
      Rectangle {   // crest
        width: 3; height: 4; radius: 1
        color: root.gold
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12 - 6.4
      }
      Rectangle {   // pivot
        anchors.centerIn: parent
        width: 2.4; height: 2.4; radius: 1.2
        color: "#aab0bd"
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
    NumberAnimation { target: root; property: "turn"; to: 90; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    ScriptAction { script: if (root.bar) root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'") }
    // The key stays at START while the engine cranks and lets go as it catches
    PauseAnimation { duration: root.soundOn ? 700 : 450 }
    NumberAnimation { target: root; property: "turn"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    ScriptAction { script: root.busy = false }
  }

  SequentialAnimation {
    id: accAnim
    ScriptAction { script: root.busy = true }
    NumberAnimation { target: root; property: "turn"; to: 45; duration: 200; easing.type: Easing.OutCubic }
    ScriptAction { script: if (root.bar) root.bar.run("xdg-terminal-exec") }
    PauseAnimation { duration: 350 }
    NumberAnimation { target: root; property: "turn"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    ScriptAction { script: root.busy = false }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (root.busy) return
      if (mouse.button === Qt.RightButton) accAnim.restart()
      else startAnim.restart()
    }
  }
}
