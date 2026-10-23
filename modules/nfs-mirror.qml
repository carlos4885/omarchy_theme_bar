// nfs-mirror — rear-view mirror that shows the day, time and date.
// Click: the mirror shows the long date for a few seconds.
import QtQuick

Item {
  id: root
  property var bar
  property string moduleName: "nfs-mirror"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property string family: bar ? bar.fontFamily : "monospace"
  readonly property real barH: bar ? bar.barSize : 26

  property date now: new Date()
  property bool peek: false

  implicitWidth: Math.max(196, row.implicitWidth + 44)
  implicitHeight: barH

  // Wake exactly on the minute
  Timer {
    id: tick
    repeat: false
    onTriggered: { root.now = new Date(); root.schedule() }
  }
  function schedule() {
    tick.interval = 60000 - (Date.now() % 60000) + 40
    tick.restart()
  }
  Component.onCompleted: schedule()

  Timer {
    id: peekTimer
    interval: 4000
    onTriggered: root.peek = false
  }

  // Mount from the windscreen
  Rectangle {
    width: 12; height: 5; radius: 1.5
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    color: "#0a0612"
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
  }

  // Housing
  Rectangle {
    id: housing
    anchors.horizontalCenter: parent.horizontalCenter
    y: 4
    width: parent.width
    height: root.barH - 5
    radius: 9
    color: "#0a0612"
    border.width: 1.5
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.75)

    // Glass
    Rectangle {
      id: glass
      anchors.fill: parent
      anchors.margins: 2.5
      radius: 7
      clip: true
      gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: "#190c34" }
        GradientStop { position: 0.6; color: "#2b0f4d" }
        GradientStop { position: 1.0; color: "#55135f" }
      }

      // Reflected horizon
      Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1.5
        color: root.accent
        opacity: 0.55
      }

      // Glare that sweeps across now and then
      Rectangle {
        id: glare
        width: 12
        height: parent.height * 3
        y: -parent.height
        x: -40
        rotation: 24
        color: "white"
        opacity: 0.09
        SequentialAnimation on x {
          loops: Animation.Infinite
          running: root.visible
          PauseAnimation { duration: 9000 }
          NumberAnimation { from: -30; to: glass.width + 30; duration: 1500; easing.type: Easing.InOutSine }
        }
      }

      Row {
        id: row
        anchors.centerIn: parent
        spacing: 9

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !root.peek
          text: Qt.formatDateTime(root.now, "ddd").toUpperCase()
          color: root.accent
          font.family: root.family
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 1.2
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !root.peek
          text: Qt.formatDateTime(root.now, "HH:mm")
          color: "#f4e9ff"
          font.family: root.family
          font.pixelSize: 14
          font.bold: true
          font.letterSpacing: 1
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: !root.peek
          text: Qt.formatDateTime(root.now, "d MMM").toUpperCase()
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.95)
          font.family: root.family
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 1.2
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: root.peek
          text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy").toUpperCase()
          color: "#f4e9ff"
          font.family: root.family
          font.pixelSize: 11
          font.bold: true
          font.letterSpacing: 1.2
        }
      }

      // Auto-dim sensor
      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        width: 3; height: 3; radius: 1.5
        color: root.fg
        opacity: 0.9
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: { root.now = new Date(); root.peek = true; peekTimer.restart() }
  }
}
