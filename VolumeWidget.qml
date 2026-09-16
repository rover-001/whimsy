import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Volume bars widget — shows the default audio sink level as a set of
// vertical bars. Reads the level via wpctl every second while visible.
Item {
  id: root

  property real barWidth: 160
  property real barHeight: 40
  property color fillColor: Color.accent
  property color bgColor: Util.alpha(Color.foreground, 0.15)
  property color fgColor: Color.foreground

  property int volume: 0
  property bool muted: false

  width: barWidth
  height: barHeight

  // Poll wpctl for volume while visible
  Timer {
    id: pollTimer
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: volProc.running = true
  }

  Process {
    id: volProc
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    stdout: SplitParser {
      onRead: function(line) {
        // "Volume: 0.80" or "Volume: 0.80 [MUTED]"
        var m = line.match(/Volume:\s+([\d.]+)/)
        if (m) root.volume = Math.round(parseFloat(m[1]) * 100)
        root.muted = line.indexOf("[MUTED]") >= 0
      }
    }
  }

  // ---- bar background ---------------------------------------------------
  Rectangle {
    anchors.fill: parent
    radius: root.barHeight / 2
    color: root.bgColor
  }

  // ---- bar fill ---------------------------------------------------------
  Rectangle {
    x: 0
    y: 0
    width: Math.max(root.barHeight, root.barWidth * (root.volume / 100))
    height: root.barHeight
    radius: root.barHeight / 2
    color: root.muted ? Util.alpha(root.fgColor, 0.25) : root.fillColor

    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  // ---- volume icon (speaker) -------------------------------------------
  Text {
    x: Style.space(10)
    anchors.verticalCenter: parent.verticalCenter
    text: root.muted ? "\u{1F507}" : (root.volume > 60 ? "\u{1F50A}" : root.volume > 30 ? "\u{1F509}" : "\u{1F508}")
    font.pixelSize: root.barHeight * 0.55
    font.family: "Noto Color Emoji"
  }

  // ---- volume percentage -----------------------------------------------
  Text {
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    text: root.muted ? "MUTE" : root.volume + "%"
    color: root.muted ? Util.alpha(root.fgColor, 0.5) : "white"
    font.family: Style.font.family
    font.pixelSize: root.barHeight * 0.38
    font.weight: Font.Bold
    font.letterSpacing: 1
    renderType: Text.NativeRendering
  }
}
