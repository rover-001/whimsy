import QtQuick
import Quickshell
import qs.Commons

// Retro split-flap mechanical clock widget. Features authentic split-card
// flipping animation with realistic cosine projection foreshortening,
// dynamic folding shadow gradients, tactile mechanical hinge clips, and
// live hours, minutes, and seconds flippers.
Item {
  id: root

  property real clockScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property date today: liveClock.date

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
  readonly property string secsStr: {
    var s = liveClock.date.getSeconds()
    return (s < 10 ? "0" : "") + s
  }

  width: flipRow.width
  height: flipRow.height

  // ---- Reusable Flap Card Half (Top-level component) -----------------------
  component FlapCard: Rectangle {
    id: fc
    required property real cardWidth
    required property real cardHeight
    required property real digitSize
    required property real cornerRadius
    required property string textValue
    required property bool isTop
    property real shadowOpacity: 0.0

    width: cardWidth
    height: Math.floor(cardHeight / 2)
    color: "#16171e"
    clip: true

    topLeftRadius: isTop ? cornerRadius : 0
    topRightRadius: isTop ? cornerRadius : 0
    bottomLeftRadius: isTop ? 0 : cornerRadius
    bottomRightRadius: isTop ? 0 : cornerRadius
    border.width: 1
    border.color: Util.alpha("#ffffff", 0.13)

    // Centered bold digit (offset so only half is visible in the clipped card)
    Text {
      width: fc.width
      height: fc.cardHeight
      y: fc.isTop ? 0 : -fc.height
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: fc.textValue
      color: "#f4f4f5"
      font.family: "JetBrainsMono NF"
      font.pixelSize: fc.digitSize
      font.weight: Font.Bold
      renderType: Text.QtRendering
    }

    // Static surface depth gradient
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: fc.isTop ? Util.alpha("#ffffff", 0.05) : "transparent"
        }
        GradientStop {
          position: 1.0
          color: fc.isTop ? Util.alpha("#000000", 0.38) : Util.alpha("#000000", 0.18)
        }
      }
    }

    // Dynamic folding shadow overlay
    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: fc.shadowOpacity
    }
  }

  // ---- Reusable Mechanical Split Flap Tile ---------------------------------
  component FlipTile: Item {
    id: tile
    property string value: "00"
    property real tileWidth: Style.space(78) * root.clockScale
    property real tileHeight: Style.space(90) * root.clockScale
    property real digitSize: Style.space(48) * root.clockScale
    property real tileRadius: Style.space(10) * root.clockScale

    width: tileWidth
    height: tileHeight

    property string displayVal: value
    property string oldVal: value
    property real flipProgress: 0.0

    onValueChanged: {
      if (value !== displayVal) {
        oldVal = displayVal
        displayVal = value
        flipAnim.stop()
        flipProgress = 0.0
        flipAnim.restart()
      }
    }

    NumberAnimation {
      id: flipAnim
      target: tile
      property: "flipProgress"
      from: 0.0
      to: 1.0
      duration: 340
      easing.type: Easing.InOutQuad
      onFinished: {
        oldVal = displayVal
        flipProgress = 0.0
      }
    }

    // 1. Static Upper Background: reveals the new digit as upper flap folds down
    FlapCard {
      anchors.top: parent.top
      cardWidth: tile.tileWidth
      cardHeight: tile.tileHeight
      digitSize: tile.digitSize
      cornerRadius: tile.tileRadius
      isTop: true
      textValue: tile.displayVal
    }

    // 2. Static Lower Background: holds the old digit until lower flap drops
    FlapCard {
      anchors.bottom: parent.bottom
      cardWidth: tile.tileWidth
      cardHeight: tile.tileHeight
      digitSize: tile.digitSize
      cornerRadius: tile.tileRadius
      isTop: false
      textValue: tile.oldVal
    }

    // 3. Animated Upper Flap: folds forward/downward from flat to horizontal
    FlapCard {
      id: activeTopFlap
      anchors.top: parent.top
      cardWidth: tile.tileWidth
      cardHeight: tile.tileHeight
      digitSize: tile.digitSize
      cornerRadius: tile.tileRadius
      isTop: true
      textValue: tile.oldVal
      visible: tile.flipProgress < 0.5 && flipAnim.running
      z: 5

      transform: Scale {
        origin.y: activeTopFlap.height
        yScale: Math.max(0.001, Math.cos(tile.flipProgress * Math.PI))
      }
      shadowOpacity: tile.flipProgress * 1.1
    }

    // 4. Animated Lower Flap: drops from horizontal down to flat with tactile snap
    FlapCard {
      id: activeBottomFlap
      anchors.bottom: parent.bottom
      cardWidth: tile.tileWidth
      cardHeight: tile.tileHeight
      digitSize: tile.digitSize
      cornerRadius: tile.tileRadius
      isTop: false
      textValue: tile.displayVal
      visible: tile.flipProgress >= 0.5 && flipAnim.running
      z: 5

      transform: Scale {
        origin.y: 0
        yScale: Math.max(0.001, Math.min(1.0, Math.sin((tile.flipProgress - 0.5) * Math.PI) * 1.05))
      }
      shadowOpacity: Math.max(0, (1.0 - (tile.flipProgress - 0.5) * 2) * 0.55)
    }

    // Center Split Seam Groove
    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: Math.max(1.2, Style.space(1.6) * root.clockScale)
      color: "#090a0e"
      z: 10
    }

    // Left mechanical hinge clip
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(3.5) * root.clockScale
      height: Style.space(9) * root.clockScale
      radius: 1
      color: "#0c0d12"
      border.width: 0.8
      border.color: "#353846"
      z: 11
    }

    // Right mechanical hinge clip
    Rectangle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(3.5) * root.clockScale
      height: Style.space(9) * root.clockScale
      radius: 1
      color: "#0c0d12"
      border.width: 0.8
      border.color: "#353846"
      z: 11
    }

    // Click to manually trigger a test flip
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        tile.oldVal = tile.displayVal
        tile.flipProgress = 0.0
        flipAnim.restart()
      }
    }
  }

  // ---- Main Layout: Hours : Minutes : Seconds -----------------------------
  Row {
    id: flipRow
    spacing: Style.space(9) * root.clockScale
    anchors.centerIn: parent

    // Hours Split Tile
    FlipTile {
      id: hourTile
      value: root.hoursStr
      tileWidth: Style.space(78) * root.clockScale
      tileHeight: Style.space(90) * root.clockScale
      digitSize: Style.space(48) * root.clockScale
    }

    // Center Colon Dots
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(14) * root.clockScale

      Rectangle {
        width: Style.space(5.5) * root.clockScale
        height: width
        radius: width / 2
        color: root.accentColor
      }
      Rectangle {
        width: Style.space(5.5) * root.clockScale
        height: width
        radius: width / 2
        color: root.accentColor
      }
    }

    // Minutes Split Tile
    FlipTile {
      id: minTile
      value: root.minsStr
      tileWidth: Style.space(78) * root.clockScale
      tileHeight: Style.space(90) * root.clockScale
      digitSize: Style.space(48) * root.clockScale
    }

    // Seconds Colon Dots
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(14) * root.clockScale

      Rectangle {
        width: Style.space(4.5) * root.clockScale
        height: width
        radius: width / 2
        color: Util.alpha(root.accentColor, 0.75)
      }
      Rectangle {
        width: Style.space(4.5) * root.clockScale
        height: width
        radius: width / 2
        color: Util.alpha(root.accentColor, 0.75)
      }
    }

    // Seconds Split Tile (Live Second-by-Second Flip Action!)
    FlipTile {
      id: secTile
      value: root.secsStr
      tileWidth: Style.space(56) * root.clockScale
      tileHeight: Style.space(90) * root.clockScale
      digitSize: Style.space(34) * root.clockScale
    }
  }
}
