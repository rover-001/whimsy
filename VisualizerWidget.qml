import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Audio visualizer widget — captures live audio frequencies via
// visualizer-stream.py and renders real-time responsive animated graphics.
Item {
  id: root

  property real widgetWidth: Style.space(240)
  property real widgetHeight: Style.space(64)
  property real visScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property string variant: "dots"
  property bool active: true

  readonly property string helperPath: Qt.resolvedUrl("visualizer-stream.py").toString().replace(/^file:\/\//, "")
  property var bandValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var peakValues: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  width: {
    if (variant === "vumeter") return Style.space(264) * visScale
    if (variant === "radial") return Style.space(160) * visScale
    return widgetWidth
  }
  height: {
    if (variant === "vumeter") return Style.space(112) * visScale
    if (variant === "radial") return Style.space(160) * visScale
    return widgetHeight
  }

  function startProcess() {
    if (root.visible && root.active && !visProc.running) {
      visProc.running = true
    }
  }

  Component.onCompleted: Qt.callLater(root.startProcess)
  onVisibleChanged: {
    if (visible) startProcess()
    else visProc.running = false
  }
  onActiveChanged: {
    if (active && visible) startProcess()
    else visProc.running = false
  }

  // Live audio processing process
  Process {
    id: visProc
    command: ["python3", root.helperPath]
    running: false
    onExited: function(exitCode) {
      console.log("[whimsy] visProc exited with code:", exitCode)
    }
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).trim().split(" ")
        if (parts.length < 16) return
        var nextBands = []
        var nextPeaks = root.peakValues.slice()
        for (var i = 0; i < 16; i++) {
          var val = Math.max(0.04, Math.min(1.0, Number(parts[i]) || 0))
          nextBands.push(val)
          if (val >= (nextPeaks[i] || 0)) {
            nextPeaks[i] = val
          } else {
            nextPeaks[i] = Math.max(val, (nextPeaks[i] || 0) * 0.94)
          }
        }
        root.bandValues = nextBands
        root.peakValues = nextPeaks
        if (root.variant === "wave") waveCanvas.requestPaint()
      }
    }
  }

  // ---- 1. BARS VARIANT (Bottom Bars) --------------------------------------
  // Classic 16-bar spectrum analyzer with peak dots and rounded bars
  Row {
    id: barsRow
    anchors.fill: parent
    visible: root.variant === "bars"
    spacing: Math.max(2, (parent.width - 16 * Style.space(10)) / 15)

    Repeater {
      model: 16
      Item {
        id: barSlot
        required property int index
        width: Math.max(4, (barsRow.width - 15 * barsRow.spacing) / 16)
        height: barsRow.height

        readonly property real currentVal: root.bandValues[index] !== undefined ? root.bandValues[index] : 0.05
        readonly property real peakVal: root.peakValues[index] !== undefined ? root.peakValues[index] : 0.05

        // Bar body
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width
          height: Math.max(Style.space(3), parent.height * barSlot.currentVal)
          radius: Style.space(3)
          color: barSlot.index < 4
            ? root.accentColor
            : (barSlot.index < 11
                ? Util.alpha(root.accentColor, 0.85)
                : Util.alpha(root.fgColor, 0.75))

          Behavior on height {
            NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
          }
        }

        // Floating peak indicator
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: Math.max(0, parent.height * (1.0 - barSlot.peakVal) - Style.space(3))
          width: parent.width
          height: Style.space(2)
          radius: 1
          color: root.accentColor
          opacity: barSlot.peakVal > 0.08 ? 0.9 : 0.2
        }
      }
    }
  }

  // ---- 2. MIRROR VARIANT --------------------------------------------------
  // Symmetrical double-sided waveform bars centered vertically
  Row {
    id: mirrorRow
    anchors.fill: parent
    visible: root.variant === "mirror"
    spacing: Math.max(2, (parent.width - 16 * Style.space(10)) / 15)

    Repeater {
      model: 16
      Item {
        id: mirrorSlot
        required property int index
        width: Math.max(4, (mirrorRow.width - 15 * mirrorRow.spacing) / 16)
        height: mirrorRow.height

        readonly property real currentVal: root.bandValues[index] !== undefined ? root.bandValues[index] : 0.05

        // Centered mirror bar
        Rectangle {
          anchors.centerIn: parent
          width: parent.width
          height: Math.max(Style.space(4), parent.height * mirrorSlot.currentVal)
          radius: width / 2
          color: root.accentColor

          Behavior on height {
            NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
          }
        }
      }
    }
  }

  // ---- 3. WAVE VARIANT ----------------------------------------------------
  // Smooth animated fluid oscilloscope curve
  Canvas {
    id: waveCanvas
    anchors.fill: parent
    visible: root.variant === "wave"
    renderTarget: Canvas.FramebufferObject

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      var vals = root.bandValues
      if (!vals || vals.length < 16) return

      var w = width
      var h = height
      var midY = h * 0.55
      var step = w / 15

      // Draw filled translucent area under curve
      ctx.beginPath()
      ctx.moveTo(0, h)
      ctx.lineTo(0, midY - (vals[0] || 0) * (h * 0.45))

      for (var i = 1; i < 16; i++) {
        var x0 = (i - 1) * step
        var y0 = midY - (vals[i - 1] || 0) * (h * 0.45)
        var x1 = i * step
        var y1 = midY - (vals[i] || 0) * (h * 0.45)
        var cpx = (x0 + x1) / 2
        ctx.quadraticCurveTo(x0, y0, cpx, (y0 + y1) / 2)
      }
      ctx.lineTo(w, midY - (vals[15] || 0) * (h * 0.45))
      ctx.lineTo(w, h)
      ctx.closePath()

      ctx.fillStyle = Util.alpha(root.accentColor, 0.22)
      ctx.fill()

      // Draw top glowing curve stroke
      ctx.beginPath()
      ctx.moveTo(0, midY - (vals[0] || 0) * (h * 0.45))
      for (var j = 1; j < 16; j++) {
        var prevX = (j - 1) * step
        var prevY = midY - (vals[j - 1] || 0) * (h * 0.45)
        var currX = j * step
        var currY = midY - (vals[j] || 0) * (h * 0.45)
        var midX = (prevX + currX) / 2
        ctx.quadraticCurveTo(prevX, prevY, midX, (prevY + currY) / 2)
      }
      ctx.lineTo(w, midY - (vals[15] || 0) * (h * 0.45))
      ctx.lineWidth = Style.space(2.5)
      ctx.strokeStyle = root.accentColor
      ctx.stroke()
    }
  }

  // ---- 4. DOTS / LED MATRIX VARIANT ---------------------------------------
  // 16 columns of 7 glowing LED dots (vintage hi-fi rack equalizer)
  Row {
    id: dotsRow
    anchors.fill: parent
    visible: root.variant === "dots"
    spacing: Math.max(2, (parent.width - 16 * Style.space(10)) / 15)

    Repeater {
      model: 16
      Column {
        id: dotCol
        required property int index
        width: Math.max(4, (dotsRow.width - 15 * dotsRow.spacing) / 16)
        height: dotsRow.height
        spacing: Style.space(3)

        readonly property real colVal: root.bandValues[index] !== undefined ? root.bandValues[index] : 0.05

        Repeater {
          model: 7
          Rectangle {
            id: ledDot
            required property int index
            readonly property int level: 6 - index
            readonly property bool lit: dotCol.colVal >= (level + 1) / 7.0
            width: parent.width
            height: Math.max(2, (dotCol.height - 6 * Style.space(3)) / 7)
            radius: 2
            color: ledDot.lit
              ? (ledDot.level >= 5 ? "#ef4444" : (ledDot.level >= 4 ? "#eab308" : root.accentColor))
              : Util.alpha(root.fgColor, 0.08)

            Behavior on color { ColorAnimation { duration: 50 } }
          }
        }
      }
    }
  }

  // ---- 5. VUMETER VARIANT -------------------------------------------------
  // Dual Analog Vintage VU Meters (Left & Right channel ballistic needles)
  Item {
    id: vuRoot
    anchors.fill: parent
    visible: root.variant === "vumeter"

    readonly property real leftEnergy: {
      if (!root.bandValues || root.bandValues.length < 8) return 0.05
      var sum = 0
      for (var i = 0; i < 8; i++) sum += (root.bandValues[i] || 0)
      return Math.min(1.0, Math.max(0.04, sum / 6.0))
    }
    readonly property real rightEnergy: {
      if (!root.bandValues || root.bandValues.length < 16) return 0.05
      var sum = 0
      for (var j = 8; j < 16; j++) sum += (root.bandValues[j] || 0)
      return Math.min(1.0, Math.max(0.04, sum / 6.0))
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.space(12) * root.visScale
      color: "#121318"
      border.width: 1.5
      border.color: "#252733"

      Row {
        anchors.centerIn: parent
        spacing: Style.space(10) * root.visScale

        // ---- Left Meter Dial ----
        Rectangle {
          id: leftDial
          width: Style.space(118) * root.visScale
          height: Style.space(92) * root.visScale
          radius: Style.space(8) * root.visScale
          color: "#1a1c24"
          border.width: 1
          border.color: "#2e3140"
          clip: true

          Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Util.alpha("#f59e0b", 0.04)
          }

          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(6) * root.visScale
            height: Style.space(10) * root.visScale

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "CH 1 · LEFT"
              color: Util.alpha(root.fgColor, 0.45)
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(7) * root.visScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(5) * root.visScale
              height: width
              radius: width / 2
              color: vuRoot.leftEnergy > 0.82 ? "#ef4444" : "#2d1515"
              border.width: 0.5
              border.color: vuRoot.leftEnergy > 0.82 ? "#f87171" : "#451a1a"
              Behavior on color { ColorAnimation { duration: 40 } }
            }
          }

          Row {
            anchors.top: parent.top
            anchors.topMargin: Style.space(20) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8) * root.visScale

            Repeater {
              model: [
                { txt: "-20", red: false },
                { txt: "-10", red: false },
                { txt: "-3",  red: false },
                { txt: "0",   red: false },
                { txt: "+3",  red: true }
              ]
              Text {
                required property var modelData
                text: modelData.txt
                color: modelData.red ? "#ef4444" : Util.alpha(root.fgColor, 0.45)
                font.family: "JetBrainsMono NF"
                font.pixelSize: Style.space(7) * root.visScale
                font.weight: modelData.red ? Font.Bold : Font.Normal
                renderType: Text.QtRendering
              }
            }
          }

          Row {
            anchors.top: parent.top
            anchors.topMargin: Style.space(32) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5) * root.visScale

            Repeater {
              model: 9
              Rectangle {
                required property int index
                width: 1
                height: Style.space(index % 2 === 0 ? 5 : 3) * root.visScale
                color: index >= 7 ? "#ef4444" : Util.alpha(root.fgColor, 0.3)
              }
            }
          }

          Text {
            anchors.top: parent.top
            anchors.topMargin: Style.space(42) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            text: "VU"
            color: Util.alpha(root.fgColor, 0.22)
            font.family: Style.font.family
            font.pixelSize: Style.space(10) * root.visScale
            font.weight: Font.Bold
            renderType: Text.QtRendering
          }

          Item {
            id: leftNeedle
            x: leftDial.width / 2
            y: leftDial.height - Style.space(6) * root.visScale
            width: 2
            height: Style.space(54) * root.visScale
            transformOrigin: Item.Bottom
            rotation: -42 + vuRoot.leftEnergy * 84

            Behavior on rotation {
              NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }

            Rectangle {
              anchors.fill: parent
              color: vuRoot.leftEnergy > 0.82 ? "#ef4444" : "#f43f5e"
              radius: 1
            }
          }

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(2) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(16) * root.visScale
            height: width
            radius: width / 2
            color: "#27272a"
            border.width: 1
            border.color: "#3f3f46"
          }
        }

        // ---- Right Meter Dial ----
        Rectangle {
          id: rightDial
          width: Style.space(118) * root.visScale
          height: Style.space(92) * root.visScale
          radius: Style.space(8) * root.visScale
          color: "#1a1c24"
          border.width: 1
          border.color: "#2e3140"
          clip: true

          Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Util.alpha("#f59e0b", 0.04)
          }

          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(6) * root.visScale
            height: Style.space(10) * root.visScale

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "CH 2 · RIGHT"
              color: Util.alpha(root.fgColor, 0.45)
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(7) * root.visScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(5) * root.visScale
              height: width
              radius: width / 2
              color: vuRoot.rightEnergy > 0.82 ? "#ef4444" : "#2d1515"
              border.width: 0.5
              border.color: vuRoot.rightEnergy > 0.82 ? "#f87171" : "#451a1a"
              Behavior on color { ColorAnimation { duration: 40 } }
            }
          }

          Row {
            anchors.top: parent.top
            anchors.topMargin: Style.space(20) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8) * root.visScale

            Repeater {
              model: [
                { txt: "-20", red: false },
                { txt: "-10", red: false },
                { txt: "-3",  red: false },
                { txt: "0",   red: false },
                { txt: "+3",  red: true }
              ]
              Text {
                required property var modelData
                text: modelData.txt
                color: modelData.red ? "#ef4444" : Util.alpha(root.fgColor, 0.45)
                font.family: "JetBrainsMono NF"
                font.pixelSize: Style.space(7) * root.visScale
                font.weight: modelData.red ? Font.Bold : Font.Normal
                renderType: Text.QtRendering
              }
            }
          }

          Row {
            anchors.top: parent.top
            anchors.topMargin: Style.space(32) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5) * root.visScale

            Repeater {
              model: 9
              Rectangle {
                required property int index
                width: 1
                height: Style.space(index % 2 === 0 ? 5 : 3) * root.visScale
                color: index >= 7 ? "#ef4444" : Util.alpha(root.fgColor, 0.3)
              }
            }
          }

          Text {
            anchors.top: parent.top
            anchors.topMargin: Style.space(42) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            text: "VU"
            color: Util.alpha(root.fgColor, 0.22)
            font.family: Style.font.family
            font.pixelSize: Style.space(10) * root.visScale
            font.weight: Font.Bold
            renderType: Text.QtRendering
          }

          Item {
            id: rightNeedle
            x: rightDial.width / 2
            y: rightDial.height - Style.space(6) * root.visScale
            width: 2
            height: Style.space(54) * root.visScale
            transformOrigin: Item.Bottom
            rotation: -42 + vuRoot.rightEnergy * 84

            Behavior on rotation {
              NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }

            Rectangle {
              anchors.fill: parent
              color: vuRoot.rightEnergy > 0.82 ? "#ef4444" : "#f43f5e"
              radius: 1
            }
          }

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(2) * root.visScale
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(16) * root.visScale
            height: width
            radius: width / 2
            color: "#27272a"
            border.width: 1
            border.color: "#3f3f46"
          }
        }
      }
    }
  }

  // ---- 6. RADIAL VARIANT --------------------------------------------------
  // Cyberpunk 360-degree radial audio pulse ring
  Item {
    id: radialRoot
    anchors.fill: parent
    visible: root.variant === "radial"

    readonly property real totalEnergy: {
      if (!root.bandValues || root.bandValues.length < 16) return 0.05
      var sum = 0
      for (var i = 0; i < 16; i++) sum += (root.bandValues[i] || 0)
      return Math.min(1.0, Math.max(0.04, sum / 12.0))
    }

    Rectangle {
      anchors.centerIn: parent
      width: Style.space(136) * root.visScale
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 1
      border.color: Util.alpha(root.accentColor, 0.15)
    }

    Repeater {
      model: 24
      Item {
        required property int index
        anchors.centerIn: parent
        width: Style.space(3) * root.visScale
        height: radialRoot.height
        rotation: index * 15

        readonly property int bandIdx: index < 12 ? index : (23 - index)
        readonly property real rayVal: root.bandValues[bandIdx] || 0.05

        Rectangle {
          anchors.top: parent.top
          anchors.topMargin: Style.space(6) * root.visScale
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(2.5) * root.visScale
          height: Math.max(Style.space(3) * root.visScale, Style.space(34) * root.visScale * rayVal)
          radius: width / 2
          color: rayVal > 0.7
            ? "#ef4444"
            : (rayVal > 0.35 ? root.accentColor : Util.alpha(root.accentColor, 0.6))

          Behavior on height {
            NumberAnimation { duration: 40; easing.type: Easing.OutQuad }
          }
        }
      }
    }

    Rectangle {
      anchors.centerIn: parent
      width: Style.space(56) * root.visScale
      height: width
      radius: width / 2
      color: "#10121a"
      border.width: 1.5
      border.color: root.accentColor

      scale: 1.0 + radialRoot.totalEnergy * 0.15
      Behavior on scale { NumberAnimation { duration: 50 } }

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.55
        height: width
        radius: width / 2
        color: Util.alpha(root.accentColor, 0.25 + radialRoot.totalEnergy * 0.5)

        Text {
          anchors.centerIn: parent
          text: "\u{266A}"
          color: root.accentColor
          font.pixelSize: Style.space(13) * root.visScale
        }
      }
    }
  }
}
