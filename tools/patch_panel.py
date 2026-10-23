#!/usr/bin/env python3
"""Night Run: replace the bar glyph of Omarchy's network / bluetooth widget with a dashboard lamp.

Usage: patch_panel.py <network|bluetooth|audio|agents> <Panel.qml in> <Panel.qml out>

The widget's own BarIconButton (id: button) keeps handling clicks, hover and sizing; it is made
transparent and the lamp is drawn over it, so the panel opens exactly as before.
Safe to run again: a previous Night Run patch is removed first.
"""
import re
import sys

BEGIN = "  // >>> nightrun lamp"
END = "  // <<< nightrun lamp"
OPACITY_TAG = "// nightrun: glyph hidden"

FRAME = """%(begin)s
  Item {
    id: nrLamp
    anchors.fill: button
    readonly property color fg: root.bar ? root.bar.foreground : "#19d3c5"
%(props)s
    Rectangle {
      anchors.centerIn: parent
      width: 24
      height: Math.min(parent.height - 4, 22)
      radius: 6
      color: "#07040d"
      border.width: 1
      border.color: Qt.rgba(nrLamp.fg.r, nrLamp.fg.g, nrLamp.fg.b, 0.5)

      Rectangle {   // lamp glow
        anchors.centerIn: parent
        width: 17; height: 17; radius: 8.5
        color: nrLamp.tone
        opacity: nrLamp.lit ? 0.16 : 0
      }
%(extra)s
      Canvas {
        id: nrIcon
        anchors.centerIn: parent
        width: 14; height: 14
        readonly property color tone: nrLamp.tone
        readonly property int level: nrLamp.level
        readonly property string mode: nrLamp.mode
        onToneChanged: requestPaint()
        onLevelChanged: requestPaint()
        onModeChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.lineCap = "round"
          ctx.lineJoin = "round"
          ctx.strokeStyle = tone
          ctx.fillStyle = tone
          ctx.lineWidth = 1.5
%(paint)s
        }
      }
    }
  }
%(end)s
"""

NETWORK = dict(
    props="""    readonly property string mode: root.kind
    readonly property real raw: Number(root.signalStrength)
    readonly property real pct: raw >= 0 && raw <= 1 ? raw * 100 : raw
    readonly property int level: pct >= 67 ? 3 : (pct >= 34 ? 2 : 1)
    readonly property bool lit: mode === "wifi" || mode === "ethernet"
    readonly property color tone: root.restricted ? "#ffb020"
      : lit ? "#3dffa0" : Qt.rgba(fg.r, fg.g, fg.b, 0.4)""",
    extra="",
    paint="""          if (mode === "ethernet") {
            ctx.lineWidth = 1.3
            ctx.strokeRect(3, 2.5, 8, 6)
            ctx.beginPath()
            ctx.moveTo(5.5, 8.5); ctx.lineTo(5.5, 11)
            ctx.moveTo(8.5, 8.5); ctx.lineTo(8.5, 11)
            ctx.moveTo(3.5, 11); ctx.lineTo(10.5, 11)
            ctx.stroke()
          } else {
            var dim = Qt.rgba(nrLamp.fg.r, nrLamp.fg.g, nrLamp.fg.b, 0.22)
            var radii = [3.6, 6.2, 8.8]
            for (var i = 0; i < 3; i++) {
              ctx.strokeStyle = (mode === "wifi" && i < level) ? tone : dim
              ctx.beginPath()
              ctx.arc(7, 11.6, radii[i], -3 * Math.PI / 4, -Math.PI / 4)
              ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(7, 11.6, 1.2, 0, 2 * Math.PI)
            ctx.fill()
          }""",
)

BLUETOOTH = dict(
    props="""    readonly property string mode: "bt"
    readonly property int level: 0
    readonly property bool on: !!(root.adapter && root.adapter.enabled)
    readonly property bool conn: on && !!root.connectedDevices && root.connectedDevices.length > 0
    readonly property bool lit: on
    readonly property color tone: on ? "#3b8cff"
      : Qt.rgba(fg.r, fg.g, fg.b, root.adapter ? 0.4 : 0.2)""",
    extra="""      Rectangle {   // ring while a device is connected
        anchors.centerIn: parent
        visible: nrLamp.conn
        width: 16; height: 16; radius: 8
        color: "transparent"
        border.width: 1
        border.color: "#3b8cff"
      }""",
    paint="""          ctx.lineWidth = 1.3
          ctx.beginPath()
          ctx.moveTo(3.5, 4.6); ctx.lineTo(10.5, 9.6); ctx.lineTo(7, 13)
          ctx.lineTo(7, 1); ctx.lineTo(10.5, 4.4); ctx.lineTo(3.5, 9.4)
          ctx.stroke()""",
)

AUDIO = dict(
    props="""    readonly property string mode: "audio"
    readonly property bool muted: !!root.outputMuted
    readonly property real vol: Number(root.outputVolume)
    readonly property int level: !root.hasOutput || muted || vol <= 0.001 ? 0 : (vol < 0.34 ? 1 : (vol < 0.67 ? 2 : 3))
    readonly property bool lit: !!root.hasOutput
    readonly property color tone: !lit ? Qt.rgba(fg.r, fg.g, fg.b, 0.2)
      : muted ? "#ffb020" : "#ff2fd0"
    """,
    extra="",
    paint="""          // speaker body
          ctx.beginPath()
          ctx.moveTo(1.5, 5); ctx.lineTo(4.3, 5); ctx.lineTo(7.5, 2.2)
          ctx.lineTo(7.5, 11.8); ctx.lineTo(4.3, 9); ctx.lineTo(1.5, 9)
          ctx.closePath()
          ctx.fill()
          if (nrLamp.muted) {
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(9.5, 4.8); ctx.lineTo(13, 9.2)
            ctx.moveTo(13, 4.8); ctx.lineTo(9.5, 9.2)
            ctx.stroke()
          } else {
            var dim = Qt.rgba(nrLamp.fg.r, nrLamp.fg.g, nrLamp.fg.b, 0.22)
            var radii = [2.6, 4.6, 6.6]
            for (var i = 0; i < 3; i++) {
              ctx.strokeStyle = i < level ? tone : dim
              ctx.beginPath()
              ctx.arc(7.5, 7, radii[i], -Math.PI / 3.2, Math.PI / 3.2)
              ctx.stroke()
            }
          }""",
)

# The agents widget could not be read when this was written: it only relies on what every bar
# button has. The widget hides itself when there is nothing to show, so the lamp is lit while it
# is visible, and amber when the button reports its "active" (attention) state.
AGENTS = dict(
    props="""    readonly property string mode: "agents"
    readonly property int level: 0
    readonly property bool alert: !!button.active
    readonly property bool lit: true
    readonly property color tone: alert ? "#ffb020" : "#3dffa0"
    """,
    extra="",
    paint="""          ctx.lineWidth = 1.3
          ctx.strokeRect(2.5, 5, 9, 6.5)          // head
          ctx.beginPath()
          ctx.moveTo(7, 5); ctx.lineTo(7, 2.6)    // antenna
          ctx.stroke()
          ctx.beginPath(); ctx.arc(7, 2, 1, 0, 2 * Math.PI); ctx.fill()
          ctx.beginPath(); ctx.arc(5, 8, 0.9, 0, 2 * Math.PI); ctx.fill()   // eyes
          ctx.beginPath(); ctx.arc(9, 8, 0.9, 0, 2 * Math.PI); ctx.fill()
          ctx.beginPath()
          ctx.moveTo(1, 7); ctx.lineTo(1, 9.5)    // ears
          ctx.moveTo(13, 7); ctx.lineTo(13, 9.5)
          ctx.stroke()""",
)

KINDS = {"network": NETWORK, "bluetooth": BLUETOOTH, "audio": AUDIO, "agents": AGENTS}


def block_end(src, open_idx):
    """Index just after the brace that closes the one at open_idx (skips strings and comments)."""
    depth, i, n = 0, open_idx, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            i = src.find("\n", i)
            if i < 0:
                return -1
            continue
        if src.startswith("/*", i):
            i = src.find("*/", i)
            if i < 0:
                return -1
            i += 2
            continue
        if c in "\"'`":
            q = c
            i += 1
            while i < n and src[i] != q:
                i += 2 if src[i] == "\\" else 1
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def strip_previous(src):
    a = src.find(BEGIN)
    if a >= 0:
        b = src.find(END, a)
        if b >= 0:
            src = src[:a] + src[b + len(END):].lstrip("\n")
    return re.sub(r"[ \t]*opacity: 0 " + re.escape(OPACITY_TAG) + r"\n", "", src)


def patch(kind, src):
    src = strip_previous(src)
    for m in re.finditer(r"BarIconButton\s*\{", src):
        open_idx = m.end() - 1
        end = block_end(src, open_idx)
        if end < 0:
            continue
        body = src[open_idx:end]
        idm = re.search(r"^([ \t]*)id:\s*button\b[^\n]*\n", body, re.M)
        if not idm:
            continue
        indent = idm.group(1)
        ins = open_idx + idm.end()
        lamp = FRAME % dict(begin=BEGIN, end=END, **KINDS[kind])
        return (src[:ins] + indent + "opacity: 0 " + OPACITY_TAG + "\n" + src[ins:end]
                + "\n\n" + lamp + src[end:])
    raise SystemExit("BarIconButton { id: button } not found: this Omarchy version is different from the one this patch was written for")


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in KINDS:
        raise SystemExit(__doc__)
    kind, src_path, out_path = sys.argv[1:]
    with open(src_path, encoding="utf-8") as f:
        src = f.read()
    out = patch(kind, src)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(out)


if __name__ == "__main__":
    main()
