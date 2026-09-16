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
  property bool centerOnStart: false
  property bool selected: false
  property bool locked: false

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

  // Ignore map-time synthetic pointer bursts until the surface settles.
  property bool inputReady: false
  Timer {
    id: settleTimer
    interval: 1200
    running: true
    onTriggered: card.inputReady = true
  }

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

  // NB: MouseArea.hovered is undefined in this Qt build — use a HoverHandler.
  readonly property bool hovered: cardHover.hovered
    || removeArea.containsMouse || resizeArea.containsMouse

  HoverHandler {
    id: cardHover
  }

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
    x: removeHandle.x - Style.space(20)
    y: removeHandle.y
    width: Style.space(16)
    height: Style.space(16)
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
        if (card.inputReady) {
          card.locked = !card.locked
          if (card.service && typeof card.service.cardLocked === "function") {
            card.service.cardLocked(card.widgetId, card.locked)
          }
        }
      }
    }
  }

  // ---- remove handle (top-right, overhangs like the resize dot) ----------
  Rectangle {
    id: removeHandle
    // Center on the card's top-right corner so half hangs out, mirroring the
    // white resize dot at the bottom-right. Shown on hover (always) and
    // fully visible whenever the card is selected.
    x: card.width - removeHandle.width / 2
    y: -removeHandle.height / 2
    width: Style.space(16)
    height: Style.space(16)
    radius: width / 2
    visible: card.hovered || card.selected
    opacity: card.hovered ? 1 : (card.selected ? 0.85 : 0)
    Behavior on opacity { NumberAnimation { duration: 120 } }
    color: Util.alpha(Color.popups.background, 0.9)
    border.width: 1
    border.color: Util.alpha(Color.urgent, 0.5)

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: "✕"
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }

    MouseArea {
      id: removeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { if (card.inputReady) card.removeRequested() }
    }
  }

// ---- resize dot (bottom-right, shown on hover or when selected) --------
  // Press and drag it outward to extend / shrink the widget (vector text,
  // so it stays crisp at any size).
  Rectangle {
    id: resizeDot
    z: 10
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

    // Hover-only (no acceptedButtons) so it does not steal the press from
    // the DragHandler that actually performs the resize.
    MouseArea {
      id: resizeArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      cursorShape: Qt.SizeFDiagCursor
    }

    DragHandler {
      id: resizer
      target: null
      acceptedButtons: Qt.LeftButton
      enabled: card.inputReady && !card.locked
      // Does NOT approve being taken over by the card's move DragHandler,
      // so a press on the corner always stays the resize grab.
      grabPermissions: PointerHandler.CanTakeOverFromItems
        | PointerHandler.CanTakeOverFromHandlersOfSameType
      property real startScale
      property point startPoint

      onActiveChanged: {
        if (resizer.active) {
          // User grabbed the resize handle — stop auto-centering so the
          // widget grows in place instead of snapping back to screen center
          // on every size change.
          card.keepCentered = false
          resizer.startScale = card.textScale
          resizer.startPoint = resizer.centroid.scenePosition
        } else if (!resizer.active && card.service && typeof card.service.cardResized === "function") {
          card.service.cardResized(card.widgetId, card.textScale)
        }
      }
      onCentroidChanged: function() {
        if (!resizer.active) return
        var p = resizer.centroid.scenePosition
        var dx = p.x - resizer.startPoint.x
        var dy = p.y - resizer.startPoint.y
        // Drag outward (right/down) to grow, inward to shrink.
        var delta = dx + dy
        card.textScale = Math.max(0.4, Math.min(3, resizer.startScale * (1 + delta / 160)))
      }
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: false
    acceptedButtons: Qt.RightButton
    onPressed: { if (card.inputReady && mouse.button === Qt.RightButton) card.removeRequested() }
  }

  // A plain click (press + release without drag) selects the card so its
  // chrome shows. Drags are left to the dragger below.
  TapHandler {
    acceptedButtons: Qt.LeftButton
    enabled: card.inputReady
    onTapped: card.grabSelect()
  }

  // ---- drag to move ------------------------------------------------------
  property point dragStartPoint
  property point dragStartPos

  DragHandler {
    id: dragger
    target: null
    acceptedButtons: Qt.LeftButton
    enabled: card.inputReady && !card.locked
    // Never compete with the corner resize handler — a press aimed at the
    // resize dot must go to the resizer, not start moving the card.
    grabPermissions: PointerHandler.CanTakeOverFromItems
    onActiveChanged: {
      if (dragger.active) {
        // User grabbed the body — stop auto-centering, this card is now
        // positioned by hand.
        card.keepCentered = false
        card.dragStartPoint = dragger.centroid.scenePosition
        card.dragStartPos = Qt.point(card.x, card.y)
      } else if (!dragger.active) {
        card.settleAround()
      }
    }
    onCentroidChanged: function() {
      if (!dragger.active) return
      var p = dragger.centroid.scenePosition
      card.x = Math.max(0, card.dragStartPos.x + (p.x - card.dragStartPoint.x))
      card.y = Math.max(0, card.dragStartPos.y + (p.y - card.dragStartPoint.y))
    }
  }

  function removeRequested() {
    if (card.service) card.service.removeWidget(card.widgetId)
  }
}