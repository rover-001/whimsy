import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Individual Glassmorphic Minimal Ring Block widget.
// A clean standalone acrylic card featuring an animated radial progress arc,
// bold center metric percentage, and informative status tags.
Item {
  id: root

  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property string channel: "cpu" // "cpu", "ram", "gpu"

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

  width: Style.space(120) * widgetScale
  height: Style.space(136) * widgetScale

  readonly property real metricVal: {
    if (channel === "cpu") return cpuPct
    if (channel === "ram") return ramPct
    if (channel === "gpu") return gpuAvail ? gpuUtil : 0
    return 0
  }

  readonly property string metricTitle: {
    if (channel === "cpu") return "CPU"
    if (channel === "ram") return "RAM"
    if (channel === "gpu") return "GPU"
    return ""
  }

  readonly property string metricSub: {
    if (channel === "cpu") return cpuTemp > 0 ? (Math.round(cpuTemp) + "°C") : "SYSTEM"
    if (channel === "ram") return ramUsed + " / " + ramTotal + "G"
    if (channel === "gpu") return gpuAvail ? (Math.round(gpuTemp) + "°C") : "OFFLINE"
    return ""
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.space(16) * root.widgetScale
    color: Util.alpha(Color.popups.background, 0.82)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.12)

    Column {
      anchors.centerIn: parent
      spacing: Style.space(6) * root.widgetScale

      // Circular Ring Progress Meter
      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(72) * root.widgetScale
        height: width

        Canvas {
          id: ringCanvas
          anchors.fill: parent
          antialiasing: true

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var r = width * 0.42

            // Track background
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
            ctx.lineWidth = 4
            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
            ctx.stroke()

            // Active arc sweep
            var val = Math.max(0, Math.min(100, root.metricVal)) / 100.0
            if (val > 0) {
              ctx.beginPath()
              ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * val, false)
              ctx.lineWidth = 4
              ctx.strokeStyle = root.metricVal > 85 ? "#ef4444" : root.accentColor
              ctx.lineCap = "round"
              ctx.stroke()
            }
          }

          Connections {
            target: root
            function onMetricValChanged() { ringCanvas.requestPaint() }
          }
        }

        // Center Value Display
        Column {
          anchors.centerIn: parent
          spacing: 0
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.metricVal)
            color: root.metricVal > 85 ? "#ef4444" : root.fgColor
            font.family: "JetBrainsMono NF"
            font.pixelSize: Style.space(16) * root.widgetScale
            font.weight: Font.Bold
            renderType: Text.QtRendering
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "%"
            color: Util.alpha(root.fgColor, 0.45)
            font.family: "JetBrainsMono NF"
            font.pixelSize: Style.space(8) * root.widgetScale
            renderType: Text.QtRendering
          }
        }
      }

      // Title (CPU / RAM / GPU)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.metricTitle
        color: Util.alpha(root.fgColor, 0.75)
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(9.5) * root.widgetScale
        font.weight: Font.Bold
        renderType: Text.QtRendering
      }

      // Subtitle (Temp or Used Memory)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.metricSub
        color: (root.channel === "cpu" && root.cpuTemp > 75) || (root.channel === "gpu" && root.gpuTemp > 75) || (root.channel === "ram" && root.ramPct > 85)
          ? "#ef4444"
          : root.accentColor
        font.family: "JetBrainsMono NF"
        font.pixelSize: Style.space(8) * root.widgetScale
        font.weight: Font.Bold
        renderType: Text.QtRendering
      }
    }
  }
}
