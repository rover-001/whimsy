import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.Commons
import "Model.js" as Model

// One interactive day widget placed on a DesktopWidget (per-screen layer)
// surface. Lives as a child of the full-screen layer at absolute screen
// coordinates, so many cards share one surface — no overlapping surfaces to
// block each other's input.
//
// Left-drag the card to move it, the bottom-right corner handle scales it
// (vector re-layout, stays crisp), the ✕ and resize grip show only on hover,
// right-click removes.
Item {
  id: card

  required property var service
  required property var desktop
  required property string widgetId
  required property string styleId
  required property var screen
  required property real startX
  required property real startY
  property real textScale: 1
  property real startRotation: 0
  property bool centerOnStart: false
  property bool selected: false
  property bool locked: false

  // Apply rotation around the card's own centre
  rotation: startRotation
  transformOrigin: Item.Center

  readonly property var widgetStyle: Model.styleFor(styleId)
  readonly property string widgetKind: widgetStyle.kind || "text"
  readonly property string widgetVariant: widgetStyle.variant || ""

  function grabSelect() {
    if (card.desktop && !card.selected)
      card.desktop.setSelected(card.widgetId)
  }

  readonly property real pad: Style.space(10)

  width: {
    if (card.widgetKind === "analog") return analogFace.width + pad * 2
    if (card.widgetKind === "music") return musicFace.width + pad * 2
    if (card.widgetKind === "visualizer") return visualizerFace.width + pad * 2
    if (card.widgetKind === "volume") return volumeFace.width + pad * 2
    if (card.widgetKind === "flip") return flipFace.width + pad * 2
    if (card.widgetKind === "cyber") return cyberFace.width + pad * 2
    if (card.widgetKind === "progress") return progressFace.width + pad * 2
    if (card.widgetKind === "system") return systemFace.width + pad * 2
    if (card.widgetKind === "weather") {
      return weatherFace.width + pad * 2
    }
    return Math.max(face.implicitWidth + pad * 2, Style.space(56))
  }
  height: {
    if (card.widgetKind === "analog") return analogFace.height + pad * 2
    if (card.widgetKind === "music") return musicFace.height + pad * 2
    if (card.widgetKind === "visualizer") return visualizerFace.height + pad * 2
    if (card.widgetKind === "volume") return volumeFace.height + pad * 2
    if (card.widgetKind === "flip") return flipFace.height + pad * 2
    if (card.widgetKind === "cyber") return cyberFace.height + pad * 2
    if (card.widgetKind === "progress") return progressFace.height + pad * 2
    if (card.widgetKind === "system") return systemFace.height + pad * 2
    if (card.widgetKind === "weather") {
      return weatherFace.height + pad * 2
    }
    return Math.max(face.implicitHeight + pad * 2, Style.space(56))
  }

  x: startX
  y: startY

  // While a freshly placed card, re-center whenever its size changes (the
  // true size is only known after a text layout pass — and after resizing).
  // Dropped as soon as the user drags it.
  property bool keepCentered: centerOnStart

  onWidthChanged: card.centerRefresh()
  onHeightChanged: card.centerRefresh()

  function centerRefresh() {
    if (!card.keepCentered) return
    if (width <= Style.space(56) && height <= Style.space(56)) return
    x = Math.max(0, Math.round((screen.width - width) / 2))
    y = Math.max(0, Math.round((screen.height - height) / 2))
    centerReportTimer.restart()
  }

  Timer {
    id: centerReportTimer
    interval: 150
    onTriggered: {
      if (card.keepCentered && card.service && typeof card.service.cardMoved === "function")
        card.service.cardMoved(card.widgetId, card.x, card.y)
    }
  }

  function clampIntoScreen() {
    if (!card.screen) return
    x = Math.max(0, Math.min(x, screen.width - width))
    y = Math.max(0, Math.min(y, screen.height - height))
  }

  function settleAround() {
    card.clampIntoScreen()
    if (card.service && typeof card.service.cardMoved === "function")
      card.service.cardMoved(card.widgetId, x, y)
  }

  // Responsive input readiness
  property bool inputReady: true

    // ---- text-based widget (DayFace) ------------------------------------
  DayFace {
    id: face
    anchors.centerIn: parent
    visible: card.widgetKind === "text" || card.widgetKind === ""
    styleId: card.styleId
    textScale: card.textScale
    foreground: Color.foreground
    accent: Color.accent
  }

  // ---- analog clock widget ---------------------------------------------
  AnalogClock {
    id: analogFace
    anchors.centerIn: parent
    visible: card.widgetKind === "analog"
    variant: card.widgetVariant || "station"
    clockSize: Style.space(160) * card.textScale
    faceColor: Color.foreground
    accentColor: Color.accent

    SystemClock {
      id: analogClock
      precision: SystemClock.Seconds
    }
    hours: analogClock.hours
    minutes: analogClock.minutes
    seconds: analogClock.seconds
  }

  // ---- music widget ----------------------------------------------------
  MusicWidget {
    id: musicFace
    z: 2
    anchors.centerIn: parent
    visible: card.widgetKind === "music"
    variant: card.widgetVariant || "card"
    interactive: true
    widgetScale: card.textScale
    widgetWidth: Style.space(280) * card.textScale
    fgColor: Color.foreground
    accentColor: Color.accent
  }

  // ---- visualizer widget -----------------------------------------------
  VisualizerWidget {
    id: visualizerFace
    anchors.centerIn: parent
    visible: card.widgetKind === "visualizer"
    variant: card.widgetVariant || "dots"
    active: visible
    visScale: card.textScale
    widgetWidth: Style.space(260) * card.textScale
    widgetHeight: Style.space(70) * card.textScale
    fgColor: Color.foreground
    accentColor: Color.accent
  }

  // ---- volume widget ---------------------------------------------------
  VolumeWidget {
    id: volumeFace
    anchors.centerIn: parent
    visible: card.widgetKind === "volume"
    barWidth: Style.space(200) * card.textScale
    barHeight: Style.space(40) * card.textScale
    fillColor: Color.accent
    fgColor: Color.foreground
  }

  // ---- flip clock widget ------------------------------------------------
  FlipClock {
    id: flipFace
    z: 2
    anchors.centerIn: parent
    visible: card.widgetKind === "flip"
    clockScale: card.textScale
    accentColor: Color.accent
    fgColor: Color.foreground
  }

  // ---- cyberpunk hud clock widget ---------------------------------------
  CyberClock {
    id: cyberFace
    anchors.centerIn: parent
    visible: card.widgetKind === "cyber"
    clockScale: card.textScale
    accentColor: Color.accent
    fgColor: Color.foreground
  }

  // ---- day progress widget ----------------------------------------------
  DayProgress {
    id: progressFace
    anchors.centerIn: parent
    visible: card.widgetKind === "progress"
    widgetScale: card.textScale
    accentColor: Color.accent
    fgColor: Color.foreground
  }

  // ---- system telemetry widget ------------------------------------------
  SystemWidget {
    id: systemFace
    anchors.centerIn: parent
    visible: card.widgetKind === "system"
    variant: card.widgetVariant || "pill-cpu"
    active: visible
    widgetScale: card.textScale
    accentColor: Color.accent
    fgColor: Color.foreground
  }

  // ---- weather widgets -------------------------------------------------
  WeatherPill {
    id: weatherFace
    anchors.centerIn: parent
    visible: card.widgetKind === "weather"
    variant: card.widgetVariant || "pill"
    active: visible
    widgetScale: card.textScale
    accentColor: Color.accent
    fgColor: Color.foreground
  }


  HoverHandler {
    id: cardHover
  }

  readonly property bool hovered: cardHover.hovered
    || (typeof cardDragArea !== "undefined" && cardDragArea.containsMouse)
    || (typeof removeArea !== "undefined" && removeArea.containsMouse)
    || (typeof resizeArea !== "undefined" && resizeArea.containsMouse)
    || (typeof lockArea !== "undefined" && lockArea.containsMouse)
    || (typeof rotateArea !== "undefined" && rotateArea.containsMouse)

  // ---- dotted box (shown on hover or when selected) -----------------------
  Shape {
    id: dashedBox
    anchors.fill: parent
    visible: card.hovered || card.selected
    opacity: (card.hovered || card.selected) ? 0.3 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    ShapePath {
      strokeColor: Color.foreground
      strokeWidth: 1
      strokeStyle: ShapePath.DashLine
      dashPattern: [3, 4]
      fillColor: "transparent"
      startX: 0.5
      startY: 0.5

      PathLine { x: dashedBox.width - 0.5; y: 0.5 }
      PathLine { x: dashedBox.width - 0.5; y: dashedBox.height - 0.5 }
      PathLine { x: 0.5; y: dashedBox.height - 0.5 }
      PathLine { x: 0.5; y: 0.5 }
    }
  }

  // ---- lock handle (left of the remove handle) -------------------------
  Rectangle {
    id: lockHandle
    z: 30
    x: removeHandle.x - Style.space(20)
    y: removeHandle.y
    width: Style.space(18)
    height: Style.space(18)
    radius: width / 2
    visible: card.hovered || card.selected
    opacity: (card.hovered || card.selected) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    color: card.locked
      ? Util.alpha(Color.accent, 0.3)
      : Util.alpha(Color.popups.background, 0.9)
    border.width: 1
    border.color: card.locked
      ? Color.accent
      : Util.alpha(Color.foreground, 0.3)

    // Vector padlock
    Item {
      anchors.centerIn: parent
      width: Style.space(8)
      height: Style.space(9)

      // Padlock shackle
      Rectangle {
        id: lockShackle
        width: Style.space(5.5)
        height: Style.space(5)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: card.locked ? 0 : 1.2
        y: card.locked ? 0 : -Style.space(1.2)
        radius: width / 2
        color: "transparent"
        border.width: 1.2
        border.color: card.locked ? Color.accent : Color.foreground
      }

      // Padlock body
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(7.5)
        height: Style.space(5)
        radius: 1
        color: card.locked ? Color.accent : Color.foreground
      }
    }

    MouseArea {
      id: lockArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        card.locked = !card.locked
        if (card.service && typeof card.service.cardLocked === "function") {
          card.service.cardLocked(card.widgetId, card.locked)
        }
      }
    }
  }

  // ---- remove handle (top-right, overhangs like the resize dot) ----------
  Rectangle {
    id: removeHandle
    z: 30
    // Center on the card's top-right corner so half hangs out, mirroring the
    // white resize dot at the bottom-right. Shown on hover (always) and
    // fully visible whenever the card is selected.
    x: card.width - removeHandle.width / 2
    y: -removeHandle.height / 2
    width: Style.space(20)
    height: Style.space(20)
    radius: width / 2
    visible: card.hovered || card.selected
    opacity: card.hovered ? 1 : (card.selected ? 0.95 : 0)
    Behavior on opacity { NumberAnimation { duration: 120 } }
    color: Util.alpha(Color.popups.background, 0.95)
    border.width: 1.5
    border.color: Color.urgent

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: "✕"
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      renderType: Text.NativeRendering
    }

    MouseArea {
      id: removeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.removeRequested()
    }
  }

  // ---- resize dot (bottom-right, shown on hover or when selected) --------
  // Press and drag it outward to extend / shrink the widget (vector text,
  // so it stays crisp at any size).
  Rectangle {
    id: resizeDot
    z: 30
    // Center the dot on the card's bottom-right corner so half sits inside
    // and half hangs out — the natural "grab here to resize" affordance.
    x: card.width - resizeDot.width / 2
    y: card.height - resizeDot.height / 2
    visible: (card.hovered || card.selected) && !card.locked
    opacity: (card.hovered || card.selected) && !card.locked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    width: Style.space(16)
    height: Style.space(16)
    radius: width / 2
    color: "white"
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.35)

    // Inner dot for depth over bright wallpapers.
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.4
      height: parent.height * 0.4
      radius: width / 2
      color: Color.popups.background
    }

    MouseArea {
      id: resizeArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.SizeFDiagCursor
      property real startScale: 1
      property real startSceneX: 0
      property real startSceneY: 0
      property bool active: false

      onPressed: function(mouse) {
        if (card.locked) return
        active = true
        card.keepCentered = false
        startScale = card.textScale
        var pt = mapToItem(null, mouse.x, mouse.y)
        startSceneX = pt.x
        startSceneY = pt.y
      }
      onPositionChanged: function(mouse) {
        if (!active || card.locked) return
        var pt = mapToItem(null, mouse.x, mouse.y)
        var dx = pt.x - startSceneX
        var dy = pt.y - startSceneY
        var delta = dx + dy
        card.textScale = Math.max(0.4, Math.min(3.0, startScale * (1 + delta / 160)))
      }
      onReleased: function() {
        if (active) {
          active = false
          if (card.service && typeof card.service.cardResized === "function") {
            card.service.cardResized(card.widgetId, card.textScale)
          }
        }
      }
    }
  }

  // ---- card body drag & click area ---------------------------------------
  MouseArea {
    id: cardDragArea
    z: 1
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: card.locked ? Qt.ArrowCursor : (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

    drag.target: card.locked ? null : card
    drag.axis: Drag.XAndYAxis
    drag.smoothed: false

    onPressed: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        card.removeRequested()
        return
      }
      if (mouse.button === Qt.LeftButton) {
        card.grabSelect()
        card.keepCentered = false
      }
    }

    onReleased: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        card.settleAround()
      }
    }
  }

  function removeRequested() {
    if (card.service) card.service.removeWidget(card.widgetId)
  }

  // ---- rotate handle (bottom-left, shown on hover or when selected) ------
  Rectangle {
    id: rotateDot
    z: 30
    x: -rotateDot.width / 2
    y: card.height - rotateDot.height / 2
    visible: (card.hovered || card.selected) && !card.locked
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    width: Style.space(16)
    height: Style.space(16)
    radius: width / 2
    color: Util.alpha(Color.popups.background, 0.9)
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.35)

    // Circular arrow icon
    Text {
      anchors.centerIn: parent
      text: "↻"
      color: Color.foreground
      font.pixelSize: Style.space(9)
      renderType: Text.NativeRendering
    }

    MouseArea {
      id: rotateArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.CrossCursor
      property real startAngle: 0
      property bool active: false

      onPressed: function(mouse) {
        if (card.locked) return
        active = true
        var sceneP = mapToItem(null, mouse.x, mouse.y)
        var centerScene = card.mapToItem(null, card.width / 2, card.height / 2)
        startAngle = Math.atan2(sceneP.y - centerScene.y, sceneP.x - centerScene.x) * 180 / Math.PI - card.rotation
      }
      onPositionChanged: function(mouse) {
        if (!active || card.locked) return
        var sceneP = mapToItem(null, mouse.x, mouse.y)
        var centerScene = card.mapToItem(null, card.width / 2, card.height / 2)
        var angle = Math.atan2(sceneP.y - centerScene.y, sceneP.x - centerScene.x) * 180 / Math.PI - startAngle
        card.rotation = ((angle % 360) + 360) % 360
      }
      onReleased: function() {
        if (active) {
          active = false
          if (card.service && typeof card.service.cardRotated === "function") {
            card.service.cardRotated(card.widgetId, card.rotation)
          }
        }
      }
    }
  }
}