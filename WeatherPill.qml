import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Glassmorphic Weather Widgets:
// 1) "pill"      - Weather Capsule with outdoor temp, glyph, location and wind speed
// 2) "editorial" - Big clean bold typographic weather headline ("27° / Ludhiana /  Clear / Wind ↙11km/h")
// 3) "minimal"   - Ultra clean horizontal text banner without enclosing pill, pure typography
Item {
  id: root

  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property bool active: true
  property string variant: "pill" // "pill", "editorial", "minimal"

  property string location: "Weather"
  property string tempStr: "--°"
  property string windStr: ""
  property string iconGlyph: "🌤"

  width: {
    if (variant === "editorial") return Style.space(260) * widgetScale
    if (variant === "minimal") return Style.space(210) * widgetScale
    return Style.space(220) * widgetScale
  }

  height: {
    if (variant === "editorial") return Style.space(88) * widgetScale
    if (variant === "minimal") return Style.space(42) * widgetScale
    return Style.space(52) * widgetScale
  }

  // Refresh weather status every 10 minutes
  Timer {
    interval: 600000
    running: root.visible && root.active
    repeat: true
    onTriggered: fetchWeather()
  }

  Component.onCompleted: Qt.callLater(fetchWeather)
  onVisibleChanged: if (visible) fetchWeather()

  function fetchWeather() {
    if (!statusProc.running) statusProc.running = true
    if (!iconProc.running) iconProc.running = true
  }

  Process {
    id: statusProc
    command: ["omarchy-weather-status"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var str = String(line).trim()
        if (!str || str === "Weather unavailable") return
        // Format: "Ludhiana  ·  Temp 29°C  ·  Wind ↙14km/h"
        var parts = str.split("·")
        if (parts.length >= 1) root.location = parts[0].trim()
        if (parts.length >= 2) {
          var t = parts[1].replace(/Temp\s*/i, "").trim()
          root.tempStr = t
        }
        if (parts.length >= 3) {
          root.windStr = parts[2].replace(/Wind\s*/i, "").trim()
        }
      }
    }
  }

  Process {
    id: iconProc
    command: ["omarchy-weather-icon"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var glyph = String(line).trim()
        if (glyph.length > 0) root.iconGlyph = glyph
      }
    }
  }

  // =========================================================================
  // 1. STANDARD WEATHER CAPSULE ("pill")
  // =========================================================================
  Rectangle {
    anchors.fill: parent
    visible: root.variant === "pill"
    radius: height / 2
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(8) * root.widgetScale
      anchors.leftMargin: Style.space(14) * root.widgetScale
      anchors.rightMargin: Style.space(14) * root.widgetScale
      spacing: Style.space(10) * root.widgetScale

      // Weather Icon Orb
      Rectangle {
        width: Style.space(34) * root.widgetScale
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Util.alpha(root.accentColor, 0.15)
        border.width: 1
        border.color: Util.alpha(root.accentColor, 0.3)

        Text {
          anchors.centerIn: parent
          text: root.iconGlyph
          font.pixelSize: Style.space(17) * root.widgetScale
          color: root.accentColor
        }
      }

      // Middle: Location & Wind
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(34 + 60) * root.widgetScale
        spacing: 1

        Text {
          width: parent.width
          text: root.location
          color: root.fgColor
          font.family: Style.font.family
          font.pixelSize: Style.space(10) * root.widgetScale
          font.weight: Font.Bold
          elide: Text.ElideRight
          renderType: Text.QtRendering
        }

        Text {
          width: parent.width
          text: root.windStr.length > 0 ? ("Wind " + root.windStr) : "CURRENT"
          color: Util.alpha(root.fgColor, 0.45)
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(8) * root.widgetScale
          font.weight: Font.Bold
          elide: Text.ElideRight
          renderType: Text.QtRendering
        }
      }

      // Right: Big Outdoor Temperature
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.tempStr
        color: root.accentColor
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(16) * root.widgetScale
        font.weight: Font.Bold
        renderType: Text.QtRendering
      }
    }
  }

  // =========================================================================
  // 2. EDITORIAL WEATHER CARD ("editorial")
  // Clean, modern typographical card with large serif/sans temperature and location.
  // =========================================================================
  Rectangle {
    anchors.fill: parent
    visible: root.variant === "editorial"
    radius: Style.space(16) * root.widgetScale
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    Item {
      anchors.fill: parent
      anchors.margins: Style.space(14) * root.widgetScale

      // Top row: Location & Icon
      Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Style.space(14) * root.widgetScale

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: root.location.toUpperCase()
          color: Util.alpha(root.fgColor, 0.5)
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(8.5) * root.widgetScale
          font.weight: Font.Bold
          font.letterSpacing: 1.2
          renderType: Text.QtRendering
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.iconGlyph
          font.pixelSize: Style.space(14) * root.widgetScale
          color: root.accentColor
        }
      }

      // Middle: Big Bold Temperature
      Text {
        anchors.bottom: footerRow.top
        anchors.bottomMargin: Style.space(2) * root.widgetScale
        anchors.left: parent.left
        text: root.tempStr
        color: root.fgColor
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(28) * root.widgetScale
        font.weight: Font.Bold
        renderType: Text.QtRendering
      }

      // Bottom footer: Wind details and status
      Row {
        id: footerRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(8) * root.widgetScale

        Text {
          text: root.windStr.length > 0 ? ("Wind " + root.windStr) : "CALM CONDITIONS"
          color: Util.alpha(root.fgColor, 0.5)
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(8.5) * root.widgetScale
          renderType: Text.QtRendering
        }
      }
    }
  }

  // =========================================================================
  // 3. MINIMAL TYPOGRAPHY ("minimal")
  // Transparent, borderless clean text line with icon, temp and city.
  // =========================================================================
  Item {
    anchors.fill: parent
    visible: root.variant === "minimal"

    Row {
      anchors.centerIn: parent
      spacing: Style.space(10) * root.widgetScale

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.iconGlyph
        font.pixelSize: Style.space(20) * root.widgetScale
        color: root.accentColor
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.tempStr
        color: root.fgColor
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(20) * root.widgetScale
        font.weight: Font.Bold
        renderType: Text.QtRendering
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Style.space(18) * root.widgetScale
        color: Util.alpha(root.fgColor, 0.2)
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          text: root.location
          color: root.fgColor
          font.family: Style.font.family
          font.pixelSize: Style.space(9.5) * root.widgetScale
          font.weight: Font.Bold
          renderType: Text.QtRendering
        }

        Text {
          text: root.windStr.length > 0 ? root.windStr : "Calm"
          color: Util.alpha(root.fgColor, 0.45)
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(7.5) * root.widgetScale
          renderType: Text.QtRendering
        }
      }
    }
  }
}
