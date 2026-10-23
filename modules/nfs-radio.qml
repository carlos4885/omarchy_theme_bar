// nfs-radio — Madrid police scanner ticker for the empty space on the bar.
// Click: skip to the next message. Hover: pause.
// Settings (all optional): width (px), speed (px/s), lang ("es" | "en"), accent.
import QtQuick

Item {
  id: root
  property var bar
  property string moduleName: "nfs-radio"
  property var settings

  readonly property color fg: bar ? bar.foreground : "#19d3c5"
  readonly property color accent: settings && settings.accent ? settings.accent : "#ff2fd0"
  readonly property string family: bar ? bar.fontFamily : "monospace"
  readonly property int span: settings && settings.width ? Number(settings.width) : 470
  readonly property real speed: settings && settings.speed ? Number(settings.speed) : 70
  readonly property string lang: settings && settings.lang ? String(settings.lang) : "es"

  implicitWidth: span
  implicitHeight: bar ? bar.barSize : 26

  // ---- content ---------------------------------------------------------
  // Spanish entries carry their own article ("la M-30", "el Paseo del Prado")
  // so templates can say "en {street}"; build() fixes "de el" -> "del", "a el" -> "al".
  readonly property var streets: {
    if (lang === "en") return [
      "M-30", "M-40", "M-50", "A-6", "A-1", "A-2", "A-3", "A-4", "A-5",
      "Paseo de la Castellana", "Gran Vía", "Calle de Alcalá", "Paseo del Prado",
      "Puerta del Sol", "Plaza de Cibeles", "Plaza de Castilla", "Nudo Norte",
      "Nudo Sur", "the Calle 30 tunnels", "Puente de Segovia", "Casa de Campo",
      "Madrid Río", "Plaza de España", "Puerta de Alcalá", "Avenida de América",
      "Glorieta de Atocha", "Plaza Elíptica", "Calle Serrano", "Paseo de la Habana",
      "Cuesta de las Perdices", "the Cuatro Torres", "Barajas airport", "IFEMA",
      "the Bernabéu", "Puente de Vallecas"
    ]
    return [
      "la M-30", "la M-40", "la M-50", "la A-6", "la A-1", "la A-2", "la A-3", "la A-4", "la A-5",
      "el Paseo de la Castellana", "Gran Vía", "la calle de Alcalá", "el Paseo del Prado",
      "la Puerta del Sol", "la plaza de Cibeles", "la plaza de Castilla", "el Nudo Norte",
      "el Nudo Sur", "los túneles de la Calle 30", "el Puente de Segovia", "la Casa de Campo",
      "Madrid Río", "la plaza de España", "la Puerta de Alcalá", "la avenida de América",
      "la glorieta de Atocha", "la plaza Elíptica", "la calle Serrano", "el Paseo de la Habana",
      "la Cuesta de las Perdices", "las Cuatro Torres", "el aeropuerto de Barajas", "IFEMA",
      "las inmediaciones del Bernabéu", "el Puente de Vallecas"
    ]
  }
  readonly property var units: {
    if (lang === "en") return ["Zeta 7", "Zeta 12", "Patrol 21", "Bike 4", "Pegasus", "Interceptor 3", "Unit 9"]
    return ["Zeta 7", "Zeta 12", "Patrulla 21", "Moto 4", "Pegasus", "Interceptor 3", "Unidad 9"]
  }
  readonly property var cars: {
    if (lang === "en") return [
      "black SEAT León Cupra", "grey Cupra Formentor VZ", "red SEAT Ibiza FR",
      "yellow SEAT 600", "white SEAT Ateca", "blue Audi RS3", "black BMW M4",
      "white VW Golf GTI", "silver Mercedes-AMG A45", "orange Renault Clio RS",
      "green Mini Cooper S", "purple coupe"
    ]
    return [
      "SEAT León Cupra negro", "Cupra Formentor VZ gris", "SEAT Ibiza FR rojo",
      "SEAT 600 amarillo", "SEAT Ateca blanco", "Audi RS3 azul", "BMW M4 negro",
      "VW Golf GTI blanco", "Mercedes-AMG A45 plateado", "Renault Clio RS naranja",
      "Mini Cooper S verde", "coupé violeta"
    ]
  }
  readonly property var templatesEs: [
    { c: "10-80", t: "Todas las unidades: carrera ilegal en curso en {street}" },
    { c: "10-80", t: "{unit}, sospechoso a la vista: {car} rumbo a {street}" },
    { c: "10-10", t: "Central a {unit}: pierden contacto visual cerca de {street}" },
    { c: "10-99", t: "Se solicita refuerzo en {street}, persecución a {speed} km/h" },
    { c: "10-33", t: "Atención: control de carretera montado en {street}" },
    { c: "10-35", t: "{unit}: helicóptero sobre {street}, el {car} acelera" },
    { c: "10-17", t: "Aviso a todas las unidades: tráfico cortado en {street}" },
    { c: "10-20", t: "{unit} en posición en {street}, esperando órdenes" },
    { c: "10-78", t: "Nivel de búsqueda al máximo: objetivo {car}" },
    { c: "10-97", t: "Corredores reunidos en {street}, acudan con precaución" },
    { c: "10-4",  t: "Recibido, {unit}. Mantengan la persecución por {street}" },
    { c: "10-80", t: "Radar en {street}: {car} cazado a {speed} km/h, no se detiene" },
    { c: "10-17", t: "Retención kilométrica en {street}, el {car} se cuela por el arcén" },
    { c: "10-97", t: "Vecinos denuncian ruido de escapes y derrapes en {street}" }
  ]
  readonly property var templatesEn: [
    { c: "10-80", t: "All units: illegal street race in progress on {street}" },
    { c: "10-80", t: "{unit}, suspect spotted: {car} heading for {street}" },
    { c: "10-10", t: "Dispatch to {unit}: lost visual near {street}" },
    { c: "10-99", t: "Backup requested on {street}, pursuit at {speed} mph" },
    { c: "10-33", t: "Be advised: roadblock set up on {street}" },
    { c: "10-35", t: "{unit}: chopper over {street}, the {car} is accelerating" },
    { c: "10-17", t: "All units: {street} is closed to traffic" },
    { c: "10-20", t: "{unit} in position on {street}, awaiting orders" },
    { c: "10-78", t: "Heat level maxed. Priority target: {car}" },
    { c: "10-97", t: "Racers gathering at {street}, proceed with caution" },
    { c: "10-4",  t: "Copy that, {unit}. Stay on the chase down {street}" },
    { c: "10-80", t: "Speed camera at {street}: {car} clocked at {speed} mph, not stopping" },
    { c: "10-17", t: "Miles of traffic at {street}, the {car} is using the hard shoulder" },
    { c: "10-97", t: "Residents report screeching tyres and loud exhausts near {street}" }
  ]

  property int lastTemplate: -1

  function pick(list) { return list[Math.floor(Math.random() * list.length)] }

  function build() {
    var list = root.lang === "en" ? root.templatesEn : root.templatesEs
    var i = Math.floor(Math.random() * list.length)
    if (i === root.lastTemplate) i = (i + 1) % list.length
    root.lastTemplate = i
    var kmh = root.lang === "en" ? 90 + Math.floor(Math.random() * 90) : 140 + Math.floor(Math.random() * 120)
    var text = list[i].t
      .replace(/\{street\}/g, root.pick(root.streets))
      .replace(/\{unit\}/g, root.pick(root.units))
      .replace(/\{car\}/g, root.pick(root.cars))
      .replace(/\{speed\}/g, String(kmh))
    if (root.lang !== "en") text = text.replace(/\bde el\b/g, "del").replace(/\ba el\b/g, "al")
    var accentHex = String(root.accent)
    return "<font color='" + accentHex + "'>[" + list[i].c + "]</font> " + text
  }

  function next() {
    msg.text = root.build()
    Qt.callLater(function() { scroll.restart() })
  }

  // ---- siren badge -------------------------------------------------------
  Rectangle {
    id: badge
    anchors.verticalCenter: parent.verticalCenter
    width: 64; height: root.height - 6; radius: 5
    color: "#07040d"
    border.width: 1
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)

    property bool phase: false
    Timer {
      interval: 380; running: root.visible; repeat: true
      onTriggered: badge.phase = !badge.phase
    }

    Row {
      anchors.centerIn: parent
      spacing: 5
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 6; height: 6; radius: 3
        color: badge.phase ? "#ff2b4d" : "#4a1020"
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "112"
        color: root.fg
        font.family: root.family
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 6; height: 6; radius: 3
        color: badge.phase ? "#14264d" : "#2f6bff"
      }
    }
  }

  // ---- ticker --------------------------------------------------------------
  Item {
    id: vp
    anchors.left: badge.right
    anchors.leftMargin: 8
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    clip: true

    Text {
      id: msg
      anchors.verticalCenter: parent.verticalCenter
      x: vp.width
      textFormat: Text.StyledText
      color: root.fg
      font.family: root.family
      font.pixelSize: 12
      wrapMode: Text.NoWrap
      text: ""
    }

    // Soft edges, only when the bar has a solid background
    Rectangle {
      visible: root.bar && root.bar.background && root.bar.background.a > 0.5
      anchors.left: parent.left
      width: 18; height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.bar ? root.bar.background : "black" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
    Rectangle {
      visible: root.bar && root.bar.background && root.bar.background.a > 0.5
      anchors.right: parent.right
      width: 18; height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: root.bar ? root.bar.background : "black" }
      }
    }
  }

  NumberAnimation {
    id: scroll
    target: msg
    property: "x"
    from: vp.width
    to: -msg.implicitWidth
    duration: Math.max(1500, (vp.width + msg.implicitWidth) / root.speed * 1000)
    onFinished: { gap.interval = 2200; gap.restart() }
  }

  Timer {
    id: gap
    interval: 2200
    onTriggered: root.next()
  }

  HoverHandler {
    onHoveredChanged: if (scroll.running) scroll.paused = hovered
  }

  MouseArea {
    anchors.fill: parent
    onClicked: { scroll.stop(); gap.stop(); root.next() }
  }

  Component.onCompleted: { gap.interval = 400; gap.start() }
}
