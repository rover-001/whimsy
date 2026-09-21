import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Per-screen layer that hosts all whimsy desktop widgets. One full-screen
// bottom-layer surface per monitor; every widget card is a plain child placed
// at root coordinates, so many widgets share a single surface (full-screen
// surfaces would stack on the bottom layer and only the top one could be
// hovered or dragged). Renders behind all normal windows, above the wallpaper.
PanelWindow {
  id: layer

  required property var service
  required property string screenName
  property var cards: ({})
  // Which card currently shows its chrome (dotted box, resize dot, remove ✕).
  // Clicking empty desktop clears it; clicking a card selects it.
  property string selectedId: ""
  // Set true by editable widgets (e.g. StickyNote) while keyboard is needed.
  property bool keyboardActive: false
  property Component cardComponent: Qt.createComponent(
    Qt.resolvedUrl("DesktopCard.qml"), Component.PreferSynchronous)

  visible: true
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  screen: service ? service.screenByName(screenName) : null

  WlrLayershell.namespace: "whimsy-widget"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: layer.keyboardActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // First declared child — cards created later stack above it. Any press that
  // does NOT land on a card lands here and clears the selection.
  MouseArea {
    id: clearSelectArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: layer.selectedId = ""
  }

  onSelectedIdChanged: {
    for (var id in layer.cards)
      layer.cards[id].selected = (id === layer.selectedId)
  }

  function setSelected(id) {
    layer.selectedId = id
  }

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  function addWidget(entry) {
    if (!entry || layer.cards[entry.id]) return
    if (layer.cardComponent.status !== Component.Ready) {
      console.warn("whimsy: DesktopWidget component not ready:",
        layer.cardComponent.errorString())
      return
    }
    var card = layer.cardComponent.createObject(layer.contentItem, {
      service: layer.service,
      desktop: layer,
      widgetId: entry.id,
      styleId: entry.style,
      screen: layer.screen,
      startX: entry.x,
      startY: entry.y,
      textScale: Number(entry.scale || 1),
      locked: entry.locked === true,
      startRotation: Number(entry.rotation) || 0,
      centerOnStart: entry.center === true
    })
    if (!card) {
      console.warn("whimsy: DesktopWidget createObject failed")
      return
    }
    layer.cards[entry.id] = card
    // A freshly placed widget appears selected so its handles are visible.
    if (entry.center === true) layer.setSelected(entry.id)
  }

  function updateWidget(entry) {
    var card = layer.cards[entry.id]
    if (!card) return
    card.styleId = entry.style
    card.textScale = Number(entry.scale || 1)
    card.locked = entry.locked === true
    card.x = entry.x
    card.y = entry.y
  }

  function removeCard(id) {
    var card = layer.cards[id]
    if (card) {
      card.destroy()
      delete layer.cards[id]
    }
    if (layer.selectedId === id) layer.selectedId = ""
  }
}