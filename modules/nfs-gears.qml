// nfs-gears — workspaces as a gearbox. The shift knob slides to the active gear with a neon trail.
// Click a gear to switch to that workspace; scroll to shift up / down.
// One dot per window (max 3), empty gears are dimmed, a gear blinks red when a window wants attention.
// Hover a gear to list its windows.
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
  readonly property color alertColor: "#ff3b4e"
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

  // gear number -> workspace object (Hyprland only keeps workspaces with windows or visited ones alive)
  readonly property var wsMap: {
    var values = Hyprland.workspaces.values
    var base = root.block * root.blockSize
    var out = {}
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > base && id <= base + root.blockSize) out[id - base] = values[i]
    }
    return out
  }
  readonly property int gears: {
    var top = root.minGears
    for (var key in root.wsMap) top = Math.max(top, Number(key))
    return Math.max(top, root.activeGear)
  }

  readonly property real slotW: 20
  readonly property real pad: 4
  readonly property real skew: -0.25   // leans the gear shapes to the right, like a racing HUD

  implicitWidth: gears * slotW + pad * 2
  implicitHeight: bar ? bar.barSize : 26

  function windowsOf(n) {
    var ws = root.wsMap[n]
    return ws && ws.toplevels ? ws.toplevels.values : []
  }

  function tipFor(n) {
    var list = root.windowsOf(n)
    var names = []
    for (var i = 0; i < list.length && i < 5; i++) {
      var t = list[i]
      var name = t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : t.title
      if (name && name.length > 24) name = name.substring(0, 23) + "…"
      names.push(name || "?")
    }
    if (list.length > 5) names.push("+" + (list.length - 5))
    return "Gear " + n + "  ·  " + (names.length ? names.join("  ·  ") : "empty")
  }

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

    // Slanted slot backgrounds (+ red blink when a window asks for attention)
    Repeater {
      model: root.gears
      Item {
        id: slot
        required property int index
        readonly property int gear: index + 1
        readonly property bool active: gear === root.activeGear
        readonly property var ws: root.wsMap[gear] || null
        readonly property bool urgent: ws ? ws.urgent === true : false
        readonly property int winCount: ws && ws.toplevels ? ws.toplevels.values.length : 0
        z: 0
        x: root.pad + index * root.slotW
        width: root.slotW
        height: gate.height

        Rectangle {
          x: 1; y: 3
          width: parent.width - 2
          height: parent.height - 6
          radius: 3
          color: "#120a1f"
          border.width: 1
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, slot.winCount > 0 || slot.active ? 0.22 : 0.08)
          transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
        Rectangle {
          id: urgentBox
          visible: slot.urgent && !slot.active
          x: 1; y: 3
          width: parent.width - 2
          height: parent.height - 6
          radius: 3
          color: Qt.rgba(root.alertColor.r, root.alertColor.g, root.alertColor.b, 0.18)
          border.width: 1.2
          border.color: root.alertColor
          transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
          SequentialAnimation on opacity {
            running: urgentBox.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 350; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 350; easing.type: Easing.InOutSine }
          }
        }
      }
    }

    // Neon trail: follows the knob a little later
    Rectangle {
      id: trail
      z: 1
      y: 3
      height: parent.height - 6
      width: root.slotW - 2
      x: root.pad + (root.activeGear - 1) * root.slotW + 1
      radius: 3
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    }

    // Shift knob
    Rectangle {
      id: knob
      z: 2
      y: 3
      height: parent.height - 6
      width: root.slotW - 2
      x: root.pad + (root.activeGear - 1) * root.slotW + 1
      radius: 3
      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
      border.width: 1.2
      border.color: root.accent
      transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.skew, 0, -root.skew * height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
      Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

      // Soft glow behind the knob
      Rectangle {
        z: -1
        anchors.fill: parent
        anchors.margins: -2
        radius: parent.radius + 2
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
      }

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

    // Numbers and window dots (above the knob)
    Repeater {
      model: root.gears
      Item {
        id: label
        required property int index
        readonly property int gear: index + 1
        readonly property bool active: gear === root.activeGear
        readonly property var ws: root.wsMap[gear] || null
        readonly property bool urgent: ws ? ws.urgent === true : false
        readonly property int winCount: ws && ws.toplevels ? ws.toplevels.values.length : 0
        z: 3
        x: root.pad + index * root.slotW
        width: root.slotW
        height: gate.height

        Text {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -2
          text: parent.gear
          color: parent.active ? "#ffe8fa"
               : parent.urgent ? root.alertColor
               : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, parent.winCount > 0 ? 0.85 : 0.4)
          font.family: root.family
          font.pixelSize: 12
          font.bold: true
        }
        Row {   // one dot per window, max 3
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height - 6
          spacing: 2
          Repeater {
            model: Math.min(3, label.winCount)
            Rectangle {
              width: 3; height: 3; radius: 1.5
              color: label.active ? "#ffe8fa" : root.accent
              opacity: label.active ? 0.95 : 0.8
            }
          }
        }
      }
    }
  }

  // ---- input --------------------------------------------------------------
  property real wheelAccum: 0
  property int hoverGear: 0

  function gearAt(x) {
    var n = Math.floor((x - root.pad) / root.slotW) + 1
    return Math.max(1, Math.min(root.gears, n))
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: function(mouse) { root.focusGear(root.gearAt(mouse.x)) }
    onPositionChanged: function(mouse) {
      var g = root.gearAt(mouse.x)
      if (g === root.hoverGear || !root.bar) return
      root.hoverGear = g
      root.bar.showTooltip(root, root.tipFor(g))
    }
    onExited: {
      root.hoverGear = 0
      if (root.bar) root.bar.hideTooltip(root)
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
