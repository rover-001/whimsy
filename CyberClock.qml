import QtQuick
import Quickshell
import qs.Commons

// Cyberpunk HUD digital clock widget with tech bracket framing,
// luminous monospace digits, and live 60-second micro progress ticker.
Item {
  id: root

  property real clockScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent

  SystemClock {
    id: liveClock
    precision: SystemClock.Seconds
  }

  readonly property string hoursStr: {
    var h = liveClock.date.getHours()
    return (h < 10 ? "0" : "") + h
  }
  readonly property string minsStr: {
    var m = liveClock.date.getMinutes()
    return (m < 10 ? "0" : "") + m
  }
  readonly property int secsVal: liveClock.date.getSeconds()
  readonly property string dateStr: Qt.formatDateTime(liveClock.date, "ddd  \u{00B7}  d MMM")

  width: cyberCard.width
  height: cyberCard.height

  Rectangle {
    id: cyberCard
    width: Style.space(220) * root.clockScale
    height: Style.space(84) * root.clockScale
    radius: Style.space(12) * root.clockScale
    color: Util.alpha("#0a0c14", 0.88)
    border.width: 1
    border.color: Util.alpha(root.accentColor, 0.45)

    // Corner tech bracket accents
    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      width: Style.space(10) * root.clockScale
      height: Style.space(2) * root.clockScale
      color: root.accentColor
    }
    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      width: Style.space(2) * root.clockScale
      height: Style.space(10) * root.clockScale
      color: root.accentColor
    }
    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Style.space(10) * root.clockScale
      height: Style.space(2) * root.clockScale
      color: root.accentColor
    }
    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: Style.space(2) * root.clockScale
      height: Style.space(10) * root.clockScale
      color: root.accentColor
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(4) * root.clockScale

      // Digital time row: [ 21 : 15 ]
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(4) * root.clockScale

        Text {
          text: root.hoursStr + ":" + root.minsStr
          color: root.accentColor
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(38) * root.clockScale
          font.weight: Font.Bold
          renderType: Text.QtRendering
        }
      }

      // 60-Second mini ticker line
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.85
        height: Style.space(2) * root.clockScale
        color: Util.alpha(root.accentColor, 0.15)

        Rectangle {
          width: Math.max(2, parent.width * (root.secsVal / 60))
          height: parent.height
          color: root.accentColor
          Behavior on width { NumberAnimation { duration: 150 } }
        }
      }

      // Date subtitle
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.dateStr.toUpperCase()
        color: Util.alpha(root.fgColor, 0.6)
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(10) * root.clockScale
        font.letterSpacing: 2
        renderType: Text.QtRendering
      }
    }
  }
}
