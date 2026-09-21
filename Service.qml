import QtQuick
import Quickshell
import Quickshell.Io
import "Registry.js" as Reg

// Singleton host for placed desktop widgets. The shell loads this once
// (whimsy is listed in shell.json plugins[]); every bar instance reaches
// it through Registry.js or bar.shell.serviceFor("whimsy"). It owns the
// widgets.json state file and materializes one full-screen bottom-layer
// surface per monitor (all cards of that screen live inside it).
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/whimsy/widgets.json"

  // Persisted shape: [{ id, style, screen, x, y, scale? }]
  property var widgets: []
  // Per-screen bottom-layer surfaces: { screenName: DesktopWidget }
  property var _layers: ({})
  // Never write state before the file has been read at least once: a shell
  // that loads late would otherwise wipe persisted widgets with its empty
  // in-memory list.
  property bool _initialized: false

  readonly property int widgetCount: widgets.length

  Component.onCompleted: {
    Reg.set(root)
    console.log("[whimsy] service online; state=",
      "component=", root._layerComponent.status,
      root._layerComponent.errorString())
  }

  IpcHandler {
    target: "whimsy.service"

    function status(): string {
      var layers = []
      for (var name in root._layers) {
        var l = root._layers[name]
        var ids = []
        for (var id in l.cards) {
          var c = l.cards[id]
          ids.push({
            id: id,
            x: Math.round(c.x),
            y: Math.round(c.y),
            w: Math.round(c.width),
            h: Math.round(c.height),
            scale: c.textScale,
            locked: !!c.locked
          })
        }
        layers.push({ screen: name, cards: ids })
      }
      return JSON.stringify({
        compStatus: root._layerComponent.status,
        compError: root._layerComponent.errorString(),
        widgets: root.widgets,
        layers: layers
      })
    }

    function place(style: string): string {
      root.placeWidget(style, root.primaryScreenName())
      return "ok"
    }

    function remove(id: string): string {
      root.removeWidget(id)
      return "ok"
    }
  }

  function screenByName(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === name) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  function primaryScreenName() {
    var screens = Quickshell.screens
    return screens.length > 0 && screens[0] ? screens[0].name : ""
  }

  function generateId() {
    return "w" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36)
  }

  // Place a widget at the center of the screen. The exact centered position
  // is computed by the card once its real size is known, then reported back
  // via cardMoved() so the persisted x/y match the visible card.
  function placeWidget(styleId, screenName) {
    var entry = {
      id: generateId(),
      style: String(styleId || "big-day"),
      screen: String(screenName || root.primaryScreenName()),
      x: 0,
      y: 0,
      scale: 1,
      locked: false,
      rotation: 0,
      center: true
    }
    var list = root.widgets.slice()
    list.push(entry)
    root.widgets = list
    materializeEntry(entry)
    save()
  }

  // Called by a card after it finished moving (drag drop or centering):
  // persist its position.
  function cardMoved(id, nx, ny) {
    var list = root.widgets.slice()
    var changed = false
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i].x = Math.round(nx)
        list[i].y = Math.round(ny)
        delete list[i].center
        changed = true
      }
    }
    if (!changed) return
    root.widgets = list
    save()
  }

  function cardResized(id, scale) {
    scale = Math.max(0.4, Math.min(3, Number(scale) || 1))
    var list = root.widgets.slice()
    var changed = false
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id && Number(list[i].scale || 1) !== scale) {
        list[i].scale = scale
        changed = true
      }
    }
    if (!changed) return
    root.widgets = list
    save()
  }

  function cardRotated(id, angle) {
    angle = Number(angle) || 0
    var list = root.widgets.slice()
    var changed = false
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i].rotation = angle
        changed = true
      }
    }
    if (!changed) return
    root.widgets = list
    save()
  }

  function cardLocked(id, locked) {
    var list = root.widgets.slice()
    var changed = false
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id && !!list[i].locked !== !!locked) {
        list[i].locked = !!locked
        changed = true
      }
    }
    if (!changed) return
    root.widgets = list
    save()
  }

  function removeWidget(id) {
    var list = []
    for (var i = 0; i < root.widgets.length; i++) {
      if (root.widgets[i].id !== id) list.push(root.widgets[i])
    }
    if (list.length === root.widgets.length) return
    root.widgets = list
    for (var name in root._layers) root._layers[name].removeCard(id)
    save()
  }

  // ---- layer lifecycle -----------------------------------------------------

  property Component _layerComponent: Qt.createComponent(
    Qt.resolvedUrl("DesktopWidget.qml"), Component.PreferSynchronous)

  function ensureLayer(screenName) {
    var name = String(screenName || root.primaryScreenName())
    var existing = root._layers[name]
    if (existing) return existing
    if (root._layerComponent.status !== Component.Ready) {
      console.warn("whimsy: DesktopWidget component not ready:",
        root._layerComponent.errorString())
      return null
    }
    var layer = root._layerComponent.createObject(null, {
      service: root,
      screenName: name
    })
    if (!layer) {
      console.warn("whimsy: DesktopWidget createObject failed")
      return null
    }
    root._layers[name] = layer
    return layer
  }

  function materializeEntry(entry) {
    if (!entry) return
    var layer = root.ensureLayer(entry.screen)
    if (!layer) return
    if (layer.cards[entry.id]) layer.updateWidget(entry)
    else layer.addWidget(entry)
  }

  function dropLayer(name) {
    var layer = root._layers[name]
    if (layer) layer.destroy()
    delete root._layers[name]
  }

  // ---- persistence ----------------------------------------------------------

  function canonical() {
    return JSON.stringify(root.widgets)
  }

  function loadFromText(text) {
    var raw = String(text || "").trim()
    // An empty/partial read is the classic startup race (FileView vs the
    // shell's own first write). Never replace in-memory widgets with nothing
    // based on a blank read — otherwise lives clobber persisted state.
    if (raw === "") {
      if (root._initialized) return
      root._initialized = true
      root.widgets = []
      return
    }

    var parsed = []
    try {
      parsed = JSON.parse(raw)
    } catch (e) {
      parsed = []
    }
    if (!Array.isArray(parsed)) parsed = []

    var list = []
    for (var i = 0; i < parsed.length; i++) {
      var e = parsed[i]
      if (!e || !e.id || !e.style) continue
      if (!isFinite(Number(e.x)) || !isFinite(Number(e.y))) continue
      list.push({
        id: String(e.id),
        style: String(e.style),
        screen: String(e.screen || ""),
        x: Number(e.x),
        y: Number(e.y),
        scale: Math.max(0.4, Math.min(3, Number(e.scale || 1))),
        locked: e.locked === true,
        rotation: Number(e.rotation) || 0
      })
      if (e.center === true) list[list.length - 1].center = true
    }

    // Skip redundant reloads triggered by our own writes.
    if (root.canonical() === JSON.stringify(list)) {
      root._initialized = true
      return
    }

    root._initialized = true

    // Reconcile: drop widgets that vanished from the file.
    for (var name in root._layers) {
      var layer = root._layers[name]
      for (var id in layer.cards) {
        var still = false
        for (var k = 0; k < list.length; k++) {
          if (list[k].id === id && list[k].screen === name) {
            still = true
            break
          }
        }
        if (!still) layer.removeCard(id)
      }
    }

    root.widgets = list
    list.forEach(function(entry) {
      Qt.callLater(function() { root.materializeEntry(entry) })
    })
  }

  function save() {
    if (!root._initialized) return
    if (saveTimer.running) return
    saveTimer.restart()
  }

  function flushSave() {
    if (saveProc.running) {
      saveTimer.restart()
      return
    }
    // The payload is passed as an argument ("$2"), never interpolated into
    // the script, so arbitrary JSON is safe through the shell.
    saveProc.command = ["sh", "-c",
      'd=$(dirname -- "$1"); mkdir -p -- "$d"; printf "%s" "$2" > "$1"',
      "whimsy-save", root.statePath, root.canonical()]
    saveProc.running = true
  }

  Timer {
    id: saveTimer
    interval: 200
    onTriggered: root.flushSave()
  }

  Process {
    id: saveProc
    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("whimsy: state save failed via:", root.statePath)
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadFromText(text())
    onLoadFailed: {
      // First run (or file temporarily unreadable): start with an empty list
      // but mark initialized so user placements still persist.
      root._initialized = true
      root.widgets = []
    }
  }

  // First read can race shell startup; one delayed reload self-corrects.
  Timer {
    interval: 1200
    running: true
    onTriggered: stateFile.reload()
  }
}