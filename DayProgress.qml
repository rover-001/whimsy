import QtQuick
import Quickshell
import qs.Commons

// Visual Day Progress widget. Displays the percentage of the 24-hour day
// elapsed with a smooth gradient meter, countdown, and current date badge.
Item {
  id: root

  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent

  SystemClock {
    id: liveClock
    precision: SystemClock.Minutes
  }

  readonly property real totalMinsInDay: 1440.0
  readonly property real currentMins: liveClock.date.getHours() * 60 + liveClock.date.getMinutes()
  readonly property real progressPct: Math.min(1.0, Math.max(0.0, currentMins / totalMinsInDay))
  readonly property int pctInt: Math.round(progressPct * 100)

  readonly property int remMinsTotal: Math.max(0, 1440 - currentMins)
  readonly property int remHours: Math.floor(remMinsTotal / 60)
  readonly property int remMins: remMinsTotal % 60

  width: card.width
  height: card.height

  Rectangle {
    id: card
    width: Style.space(240) * root.widgetScale
    height: Style.space(80) * root.widgetScale
    radius: Style.space(14) * root.widgetScale
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.12)

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(12) * root.widgetScale
      spacing: Style.space(6) * root.widgetScale

      // Header row: "TODAY" & percentage
      Row {
        width: parent.width
        Text {
          text: Qt.formatDateTime(liveClock.date, "dddd, MMMM d").toUpperCase()
          color: Util.alpha(root.fgColor, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.space(10) * root.widgetScale
          font.weight: Font.Bold
          font.letterSpacing: 1
          renderType: Text.QtRendering
        }
        Item { width: parent.width - childrenRect.width - Style.space(140); height: 1 }
        Text {
          text: root.pctInt + "%"
          color: root.accentColor
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(12) * root.widgetScale
          font.weight: Font.Bold
          renderType: Text.QtRendering
        }
      }

      // Progress bar track
      Rectangle {
        width: parent.width
        height: Style.space(8) * root.widgetScale
        radius: height / 2
        color: Util.alpha(root.fgColor, 0.12)

        Rectangle {
          width: Math.max(height, parent.width * root.progressPct)
          height: parent.height
          radius: height / 2
          color: root.accentColor
          Behavior on width { NumberAnimation { duration: 400 } }
        }
      }

      // Footer: Remaining time
      Text {
        anchors.right: parent.right
        text: root.remHours + "h " + root.remMins + "m remaining"
        color: Util.alpha(root.fgColor, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.space(9) * root.widgetScale
        renderType: Text.QtRendering
      }
    }
  }
}
