import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Individual Glassmorphic Telemetry Pill widget.
// Compact pill with rounded silhouette, live progress bar, clean typography, and status tags.
Item {
  id: root

  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property string channel: "cpu" // "cpu", "ram", "gpu", "temps"

  property real cpuPct: 0
  property real cpuTemp: 0
  property real ramPct: 0
  property real ramUsed: 0
  property real ramTotal: 0
  property bool gpuAvail: false
  property real gpuUtil: 0
  property real gpuTemp: 0
  property real gpuMemUsed: 0
  property real gpuMemTotal: 0

  readonly property bool isTemps: channel === "temps"

  width: (isTemps ? Style.space(220) : Style.space(195)) * widgetScale
  height: Style.space(48) * widgetScale

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    // =======================================================================
    // 1. STANDARD METRIC PILL (CPU / RAM / GPU)
    // =======================================================================
    Item {
      id: metricBox
      anchors.fill: parent
      anchors.margins: Style.space(8) * root.widgetScale
      anchors.leftMargin: Style.space(16) * root.widgetScale
      anchors.rightMargin: Style.space(16) * root.widgetScale
      visible: !root.isTemps

      readonly property real metricVal: {
        if (root.channel === "cpu") return root.cpuPct
        if (root.channel === "ram") return root.ramPct
        if (root.channel === "gpu") return root.gpuAvail ? root.gpuUtil : 0
        return 0
      }

      readonly property string metricTitle: {
        if (root.channel === "cpu") return "CPU"
        if (root.channel === "ram") return "RAM"
        if (root.channel === "gpu") return "GPU"
        return ""
      }

      readonly property string metricSub: {
        if (root.channel === "cpu") return root.cpuTemp > 0 ? (Math.round(root.cpuTemp) + "°C") : ""
        if (root.channel === "ram") return root.ramUsed + "G"
        if (root.channel === "gpu") return root.gpuAvail ? (Math.round(root.gpuTemp) + "°C") : "OFF"
        return ""
      }

      Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Style.space(3) * root.widgetScale

        // Header Line: LABEL on left, VALUE + SUB on right
        Item {
          width: parent.width
          height: Style.space(14) * root.widgetScale

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: metricBox.metricTitle
            color: Util.alpha(root.fgColor, 0.55)
            font.family: "JetBrainsMono NF"
            font.pixelSize: Style.space(9.5) * root.widgetScale
            font.weight: Font.Bold
            renderType: Text.QtRendering
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6) * root.widgetScale

            Text {
              text: Math.round(metricBox.metricVal) + "%"
              color: metricBox.metricVal > 85 ? "#ef4444" : root.fgColor
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(10) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Text {
              text: metricBox.metricSub
              visible: metricBox.metricSub.length > 0
              color: root.accentColor
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(9) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }
          }
        }

        // Horizontal Progress Track
        Rectangle {
          width: parent.width
          height: Style.space(3.5) * root.widgetScale
          radius: height / 2
          color: Util.alpha(root.fgColor, 0.1)

          Rectangle {
            width: Math.max(height, parent.width * (Math.min(100, Math.max(0, metricBox.metricVal)) / 100.0))
            height: parent.height
            radius: height / 2
            color: metricBox.metricVal > 85 ? "#ef4444" : root.accentColor
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
      }
    }

    // =======================================================================
    // 2. COMBINED THERMAL PILL (CPU & GPU TEMPS TOGETHER)
    // =======================================================================
    Item {
      anchors.fill: parent
      anchors.margins: Style.space(8) * root.widgetScale
      anchors.leftMargin: Style.space(14) * root.widgetScale
      anchors.rightMargin: Style.space(14) * root.widgetScale
      visible: root.isTemps

      Row {
        anchors.centerIn: parent
        width: parent.width
        spacing: Style.space(8) * root.widgetScale

        // Left Side: CPU Temp
        Item {
          width: (parent.width - Style.space(12) * root.widgetScale) / 2
          height: parent.height

          Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "CPU TEMP"
              color: Util.alpha(root.fgColor, 0.5)
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(7.5) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.cpuTemp > 0 ? (Math.round(root.cpuTemp) + "°C") : "--"
              color: root.cpuTemp > 75 ? "#ef4444" : root.accentColor
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(14) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }
          }
        }

        // Center Divider
        Rectangle {
          width: 1
          height: Style.space(22) * root.widgetScale
          anchors.verticalCenter: parent.verticalCenter
          color: Util.alpha(root.fgColor, 0.12)
        }

        // Right Side: GPU Temp
        Item {
          width: (parent.width - Style.space(12) * root.widgetScale) / 2
          height: parent.height

          Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "GPU TEMP"
              color: Util.alpha(root.fgColor, 0.5)
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(7.5) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.gpuAvail ? (Math.round(root.gpuTemp) + "°C") : "OFF"
              color: (root.gpuAvail && root.gpuTemp > 75) ? "#ef4444" : root.accentColor
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(14) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }
          }
        }
      }
    }
  }
}
