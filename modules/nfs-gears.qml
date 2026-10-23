// nfs-gears — workspaces as a gearbox. The shift knob slides to the active gear.
// Click a gear to switch to that workspace; scroll to shift up / down.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

Item {
  id: root
  property var bar
  property string moduleName: "nfs-gears"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property string family: bar ? bar.fontFamily : "monospace"

  // Each monitor owns a block of ten workspaces: 1-10, 11-20, ...
  readonly property int blockSize: 10
  readonly property int minGears: 5

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""
  readonly property int activeId: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  readonly property int block: root.activeId > 0 ? Math.floor((root.activeId - 1) / root.blockSize) : 0
  readonly property int activeGear: root.activeId > 0 ? ((root.activeId - 1) % root.blockSize) + 1 : 1

  // Gears that have windows or were visited (Hyprland only keeps those alive)
  readonly property var occupied: {
    var values = Hyprland.workspaces.values
    var base = root.block * root.blockSize
    var out = {}
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > base && id <= base + root.blockSize) out[id - base] = true
    }
    return out
  }
  readonly property int gears: {
    var top = root.minGears
    for (var key in root.occupied) top = Math.max(top, Number(key))
    return Math.max(top, root.activeGear)
  }

  readonly property real slotW: 20
  readonly property real pad: 4

  implicitWidth: gears * slotW + pad * 2
  implicitHeight: bar ? bar.barSize : 26

  function focusGear(n) {
    if (!root.bar || n < 1 || n > root.blockSize) return
    var expr = "o.workspaces.focus(" + n + ", \"" + root.monitorName + "\")"
    root.bar.run("hyprctl dispatch " + Util.shellQuote(expr))
  }

  // ---- gate ---------------------------------------------------------------
  Rectangle {
    id: gate
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.height - 4
    radius: 6
    color: "#07040d"
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    // Shift knob
    Rectangle {
      id: knob
      y: 2
      height: parent.height - 4
      width: root.slotW
      x: root.pad + (root.activeGear - 1) * root.slotW
      radius: 4
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
      border.width: 1.2
      border.color: root.accent
      Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

      // Brief flash on every shift
      Rectangle {
        id: flash
        anchors.fill: parent
        radius: parent.radius
        color: root.accent
        opacity: 0
      }
    }

    Connections {
      target: root
      function onActiveGearChanged() { flashAnim.restart() }
    }
    SequentialAnimation {
      id: flashAnim
      NumberAnimation { target: flash; property: "opacity"; to: 0.6; duration: 60 }
      NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    Repeater {
      model: root.gears
      Item {
        required property int index
        readonly property int gear: index + 1
        readonly property bool active: gear === root.activeGear
        x: root.pad + index * root.slotW
        width: root.slotW
        height: gate.height

        Text {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          text: parent.gear
          color: parent.active ? "#ffe8fa" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.65)
          font.family: root.family
          font.pixelSize: 12
          font.bold: true
        }
        Rectangle {   // gear in use
          visible: !parent.active && root.occupied[parent.gear] === true
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height - 5
          width: 3; height: 3; radius: 1.5
          color: root.accent
          opacity: 0.8
        }
      }
    }
  }

  // ---- input --------------------------------------------------------------
  property real wheelAccum: 0

  MouseArea {
    anchors.fill: parent
    onClicked: function(mouse) {
      var n = Math.floor((mouse.x - root.pad) / root.slotW) + 1
      root.focusGear(Math.max(1, Math.min(root.gears, n)))
    }
    onWheel: function(wheel) {
      root.wheelAccum += wheel.angleDelta.y
      var steps = Math.trunc(root.wheelAccum / 120)
      if (steps === 0) return
      root.wheelAccum -= steps * 120
      root.focusGear(Math.max(1, Math.min(root.gears, root.activeGear - steps)))
    }
  }
}
