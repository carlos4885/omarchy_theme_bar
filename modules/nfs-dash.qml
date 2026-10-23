// nfs-dash — dashboard warning lights for WiFi, Bluetooth and the microphone.
//   WiFi       green with signal bars when connected, dark when off
//   Bluetooth  blue when on, brighter ring when a device is connected
//   Mic        dark when idle, red and blinking while an app is recording, amber when muted
// Setting: lights (default ["wifi", "bt", "mic"]).
// Click WiFi / Bluetooth: open their panel. Click the mic: mute / unmute.
import QtQuick
import Quickshell.Io

Item {
  id: root
  property var bar
  property string moduleName: "nfs-dash"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property real barH: bar ? bar.barSize : 26
  readonly property color green: "#3dffa0"
  readonly property color blue: "#3b8cff"
  readonly property color red: "#ff2b4d"
  readonly property color amber: "#ffb020"

  // Which lights to show. The installer sets ["mic"] when Omarchy's own WiFi / Bluetooth
  // widgets are already drawn as lamps (settings: lights: ["wifi", "bt", "mic"]).
  readonly property var lights: settings && settings.lights ? settings.lights : ["wifi", "bt", "mic"]

  property string wifi: "none"   // up | off | none
  property int wifiLevel: 3      // 1..3 bars
  property string bt: "none"     // conn | on | off | none
  property string mic: "none"    // live | muted | idle | none

  implicitWidth: row.implicitWidth + 12
  implicitHeight: barH

  function stateOf(kind) { return kind === "wifi" ? wifi : (kind === "bt" ? bt : mic) }
  function isLit(kind) {
    var s = stateOf(kind)
    if (kind === "wifi") return s === "up"
    if (kind === "bt") return s === "on" || s === "conn"
    return s === "live" || s === "muted"
  }
  function toneOf(kind) {
    var s = stateOf(kind)
    if (kind === "wifi") return s === "up" ? green : Qt.rgba(fg.r, fg.g, fg.b, s === "off" ? 0.4 : 0.2)
    if (kind === "bt") return (s === "on" || s === "conn") ? blue : Qt.rgba(fg.r, fg.g, fg.b, s === "off" ? 0.4 : 0.2)
    if (s === "live") return red
    if (s === "muted") return amber
    return Qt.rgba(fg.r, fg.g, fg.b, s === "idle" ? 0.5 : 0.2)
  }
  function tipOf(kind) {
    var s = stateOf(kind)
    if (kind === "wifi") return s === "up" ? "WiFi connected" : (s === "off" ? "WiFi off or disconnected" : "No WiFi adapter")
    if (kind === "bt") return s === "conn" ? "Bluetooth: device connected" : (s === "on" ? "Bluetooth on" : (s === "off" ? "Bluetooth off" : "Bluetooth unavailable"))
    return s === "live" ? "Microphone in use  (click to mute)" : (s === "muted" ? "Microphone muted  (click to unmute)" : (s === "idle" ? "Microphone idle  (click to mute)" : "No microphone"))
  }
  function activate(kind) {
    if (!root.bar) return
    if (kind === "wifi") root.bar.run("omarchy-launch-wifi")
    else if (kind === "bt") root.bar.run("omarchy-launch-bluetooth")
    else if (root.mic !== "none") {
      root.bar.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
      root.mic = root.mic === "muted" ? "idle" : "muted"   // optimistic, the next poll confirms
    }
  }

  // "wifi level bt mic", for example: "up 3 conn live"
  function sample(line) {
    var f = line.trim().split(/\s+/)
    if (f.length < 4) return
    root.wifi = f[0]
    root.wifiLevel = Math.max(1, Math.min(3, Number(f[1]) || 3))
    root.bt = f[2]
    root.mic = f[3]
  }

  Process {
    running: root.visible
    command: ["sh", "-c", `
      while :; do
        w=none; q=3
        for d in /sys/class/net/*/wireless; do
          [ -d "$d" ] || continue
          i=$(basename "$(dirname "$d")")
          if [ "$(cat "/sys/class/net/$i/operstate" 2>/dev/null)" = up ]; then w=up; else w=off; fi
          l=$(awk -v i="$i:" '$1==i {print int($3)}' /proc/net/wireless 2>/dev/null)
          if [ -n "$l" ]; then
            if [ "$l" -ge 47 ]; then q=3; elif [ "$l" -ge 23 ]; then q=2; else q=1; fi
          fi
          break
        done
        for r in /sys/class/rfkill/rfkill*; do
          [ "$(cat "$r/type" 2>/dev/null)" = wlan ] || continue
          [ "$(cat "$r/soft" 2>/dev/null)$(cat "$r/hard" 2>/dev/null)" = 00 ] || w=off
        done

        b=none
        if command -v bluetoothctl >/dev/null 2>&1; then
          s=$(timeout 2 bluetoothctl show 2>/dev/null)
          case "$s" in
            *"Powered: yes"*)
              if [ -n "$(timeout 2 bluetoothctl devices Connected 2>/dev/null)" ]; then b=conn; else b=on; fi ;;
            *Controller*) b=off ;;
          esac
        fi

        m=none
        if command -v wpctl >/dev/null 2>&1; then
          v=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
          case "$v" in
            *MUTED*) m=muted ;;
            Volume*) if [ -n "$(pactl list short source-outputs 2>/dev/null)" ]; then m=live; else m=idle; fi ;;
          esac
        fi

        echo "$w $q $b $m"
        sleep 3
      done`]
    stdout: SplitParser {
      onRead: line => root.sample(line)
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.barH - 6
    radius: 6
    color: "#07040d"
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 2

      Repeater {
        model: root.lights
        Item {
          id: light
          required property string modelData
          readonly property string kind: modelData
          readonly property string st: root.stateOf(kind)
          readonly property bool lit: root.isLit(kind)
          readonly property color tone: root.toneOf(kind)
          readonly property bool blinking: kind === "mic" && st === "live"
          property real blink: 1

          width: 18
          height: root.barH - 8
          anchors.verticalCenter: parent.verticalCenter
          opacity: blinking ? blink : 1

          SequentialAnimation on blink {
            running: light.blinking && root.visible
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.25; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.25; to: 1; duration: 480; easing.type: Easing.InOutSine }
          }

          // Lamp glow
          Rectangle {
            anchors.centerIn: parent
            width: 17; height: 17; radius: 8.5
            color: light.tone
            opacity: light.lit ? 0.16 : 0
          }
          // Ring for a connected Bluetooth device
          Rectangle {
            anchors.centerIn: parent
            visible: light.kind === "bt" && light.st === "conn"
            width: 16; height: 16; radius: 8
            color: "transparent"
            border.width: 1
            border.color: root.blue
          }

          Canvas {
            id: icon
            anchors.centerIn: parent
            width: 14; height: 14
            readonly property string kind: light.kind
            readonly property string st: light.st
            readonly property color tone: light.tone
            readonly property int level: root.wifiLevel
            onStChanged: requestPaint()
            onToneChanged: requestPaint()
            onLevelChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              ctx.lineCap = "round"
              ctx.lineJoin = "round"
              ctx.strokeStyle = tone
              ctx.fillStyle = tone
              ctx.lineWidth = 1.5

              if (kind === "wifi") {
                var dim = Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.22)
                var radii = [3.6, 6.2, 8.8]
                for (var i = 0; i < 3; i++) {
                  ctx.strokeStyle = (st === "up" && i < level) ? tone : dim
                  ctx.beginPath()
                  ctx.arc(7, 11.6, radii[i], -3 * Math.PI / 4, -Math.PI / 4)
                  ctx.stroke()
                }
                ctx.beginPath()
                ctx.arc(7, 11.6, 1.2, 0, 2 * Math.PI)
                ctx.fill()
              } else if (kind === "bt") {
                ctx.lineWidth = 1.3
                ctx.beginPath()
                ctx.moveTo(3.5, 4.6); ctx.lineTo(10.5, 9.6); ctx.lineTo(7, 13)
                ctx.lineTo(7, 1); ctx.lineTo(10.5, 4.4); ctx.lineTo(3.5, 9.4)
                ctx.stroke()
              } else {
                // capsule
                ctx.beginPath()
                ctx.moveTo(5, 3.6)
                ctx.arc(7, 3.6, 2, Math.PI, 0)
                ctx.lineTo(9, 6.6)
                ctx.arc(7, 6.6, 2, 0, Math.PI)
                ctx.closePath()
                ctx.fill()
                // cradle + stand
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.arc(7, 6.8, 4, 0, Math.PI)
                ctx.moveTo(7, 10.8); ctx.lineTo(7, 12.8)
                ctx.moveTo(5, 12.8); ctx.lineTo(9, 12.8)
                ctx.stroke()
                if (st === "muted") {
                  ctx.strokeStyle = "#07040d"
                  ctx.lineWidth = 3.4
                  ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(12, 12.4); ctx.stroke()
                  ctx.strokeStyle = tone
                  ctx.lineWidth = 1.4
                  ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(12, 12.4); ctx.stroke()
                }
              }
            }
          }

          HoverHandler {
            onHoveredChanged: {
              if (!root.bar) return
              if (hovered) root.bar.showTooltip(light, root.tipOf(light.kind))
              else root.bar.hideTooltip(light)
            }
          }
          MouseArea {
            anchors.fill: parent
            onClicked: root.activate(light.kind)
          }
        }
      }
    }
  }
}
