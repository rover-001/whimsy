import QtQuick
import Quickshell
import qs.Commons

// Analog clock widget — mathematically precise radial layout, smooth mechanical
// animations, and multiple distinct high-end watch face designs (Station, Minimal, Classic Roman, Cyber).
Item {
  id: root

  property real clockSize: Style.space(160)
  property color faceColor: Color.foreground
  property color accentColor: Color.accent
  property string variant: "station"

  property real hours: 0
  property real minutes: 0
  property real seconds: 0
  property int dayNumber: 1

  // Continuous forward-only second hand angle to eliminate 360 backward spin at 12 o'clock
  property real secondRotation: root.seconds * 6
  property real _prevSeconds: -1

  onSecondsChanged: {
    if (_prevSeconds < 0) {
      secondRotation = root.seconds * 6
    } else {
      var step = (root.seconds - _prevSeconds + 60) % 60
      if (step === 0) step = 60
      // If computer woke from suspend or clock jumped significantly, snap directly
      if (step > 30) {
        secondRotation = root.seconds * 6
      } else {
        secondRotation += step * 6
      }
    }
    _prevSeconds = root.seconds
  }

  width: clockSize
  height: clockSize

  readonly property real cx: clockSize / 2
  readonly property real cy: clockSize / 2

  // Background face container (only for station and cyber variants that require a solid dial)
  Rectangle {
    anchors.fill: parent
    radius: width / 2
    visible: root.variant === "station" || root.variant === "cyber"
    color: root.variant === "cyber"
      ? Util.alpha("#0d0e15", 0.88)
      : Util.alpha(Color.popups.background, 0.75)
    border.width: root.variant === "station" ? 3 : 2
    border.color: root.variant === "cyber"
      ? Util.alpha(root.accentColor, 0.6)
      : Util.alpha(root.faceColor, 0.18)
  }

  // =========================================================================
  // 0. SLICK VARIANT (Ultra-Minimalist 2-Hand Luxury: 12 clean dashes, NO second hand)
  // =========================================================================
  Item {
    id: slickFace
    anchors.fill: parent
    visible: root.variant === "slick"

    // 12 clean dash indices at all hour positions
    Repeater {
      model: 12
      Item {
        required property int index
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        rotation: index * 30

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: root.clockSize * 0.065
          width: Math.max(2, root.clockSize * 0.02)
          height: root.clockSize * 0.08
          radius: width / 2
          color: root.faceColor
        }
      }
    }

    // Hour hand (2 hands only: elegant tapered hour hand)
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.hours % 12 + root.minutes / 60) * 30

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -root.clockSize * 0.03
        width: Math.max(3, root.clockSize * 0.036)
        height: root.clockSize * 0.30
        radius: width / 2
        color: root.faceColor
      }
    }

    // Minute hand (2 hands only: longer sleek minute hand)
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.minutes + root.seconds / 60) * 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -root.clockSize * 0.03
        width: Math.max(2, root.clockSize * 0.024)
        height: root.clockSize * 0.44
        radius: width / 2
        color: root.faceColor
      }
    }

    // Flush minimalist center cap
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.045
      height: width
      radius: width / 2
      color: root.faceColor

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.4
        height: width
        radius: width / 2
        color: root.accentColor
      }
    }
  }

  // =========================================================================
  // 1. STATION VARIANT (Swiss Bauhaus Railway Clock)
  // =========================================================================
  Item {
    id: stationFace
    anchors.fill: parent
    visible: root.variant === "station" || root.variant === ""

    // 60 radial ticks (12 bold hour marks + 48 minute marks)
    Repeater {
      model: 60
      Item {
        id: stationTick
        required property int index
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        rotation: index * 6

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: root.clockSize * 0.05
          width: stationTick.index % 5 === 0
            ? Math.max(3, root.clockSize * 0.032)
            : Math.max(1, root.clockSize * 0.01)
          height: stationTick.index % 5 === 0
            ? root.clockSize * 0.11
            : root.clockSize * 0.045
          radius: width / 2
          color: stationTick.index % 5 === 0
            ? root.faceColor
            : Util.alpha(root.faceColor, 0.45)
        }
      }
    }

    // Hour hand (bold station baton)
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.hours % 12 + root.minutes / 60) * 30

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -root.clockSize * 0.04
        width: Math.max(4, root.clockSize * 0.05)
        height: root.clockSize * 0.32
        radius: width / 3
        color: root.faceColor
      }
    }

    // Minute hand (longer station baton)
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.minutes + root.seconds / 60) * 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -root.clockSize * 0.05
        width: Math.max(3, root.clockSize * 0.038)
        height: root.clockSize * 0.42
        radius: width / 3
        color: root.faceColor
      }
    }

    // Second hand (signature Swiss red/accent lollipop paddle)
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: root.secondRotation
      Behavior on rotation {
        NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
      }

      // Needle stem
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: -root.clockSize * 0.08
        width: Math.max(1.5, root.clockSize * 0.015)
        height: root.clockSize * 0.46
        radius: width / 2
        color: root.accentColor
      }

      // Circular lollipop disc at top
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.clockSize * 0.12
        width: root.clockSize * 0.08
        height: width
        radius: width / 2
        color: root.accentColor
      }
    }

    // Center pivot cap
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.055
      height: width
      radius: width / 2
      color: root.accentColor
    }
  }

  // =========================================================================
  // 2. MINIMAL VARIANT (Nordic Minimalist / Braun Aesthetic)
  // =========================================================================
  Item {
    id: minimalFace
    anchors.fill: parent
    visible: root.variant === "minimal"

    // 12 sleek hour dots / lines
    Repeater {
      model: 12
      Item {
        required property int index
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        rotation: index * 30

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: root.clockSize * 0.07
          width: Math.max(2, root.clockSize * 0.02)
          height: root.clockSize * 0.06
          radius: width / 2
          color: Util.alpha(root.faceColor, 0.75)
        }
      }
    }

    // Tapered hour hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.hours % 12 + root.minutes / 60) * 30

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: Math.max(3, root.clockSize * 0.035)
        height: root.clockSize * 0.28
        radius: width / 2
        color: root.faceColor
      }
    }

    // Tapered minute hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.minutes + root.seconds / 60) * 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: Math.max(2, root.clockSize * 0.025)
        height: root.clockSize * 0.40
        radius: width / 2
        color: Util.alpha(root.faceColor, 0.85)
      }
    }

    // Slim accent second needle with circular counterweight
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: root.secondRotation
      Behavior on rotation {
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
      }

      // Top needle
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: Math.max(1, root.clockSize * 0.012)
        height: root.clockSize * 0.42
        radius: width / 2
        color: root.accentColor
      }

      // Counterweight extension
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        width: Math.max(2, root.clockSize * 0.022)
        height: root.clockSize * 0.12
        radius: width / 2
        color: root.accentColor
      }
    }

    // Center cap
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.04
      height: width
      radius: width / 2
      color: root.accentColor
    }
  }

  // =========================================================================
  // 3. CLASSIC VARIANT (Roman Luxury Timepiece with Date Window)
  // =========================================================================
  Item {
    id: classicFace
    anchors.fill: parent
    visible: root.variant === "classic"

    // Roman Numerals at 12, 3, 6, 9
    Text {
      anchors.top: parent.top
      anchors.topMargin: root.clockSize * 0.07
      anchors.horizontalCenter: parent.horizontalCenter
      text: "XII"
      color: root.faceColor
      font.family: "Liberation Serif"
      font.pixelSize: root.clockSize * 0.11
      font.weight: Font.Bold
      renderType: Text.NativeRendering
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: root.clockSize * 0.09
      anchors.verticalCenter: parent.verticalCenter
      text: "III"
      color: root.faceColor
      font.family: "Liberation Serif"
      font.pixelSize: root.clockSize * 0.11
      font.weight: Font.Bold
      renderType: Text.NativeRendering
    }
    Text {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.clockSize * 0.07
      anchors.horizontalCenter: parent.horizontalCenter
      text: "VI"
      color: root.faceColor
      font.family: "Liberation Serif"
      font.pixelSize: root.clockSize * 0.11
      font.weight: Font.Bold
      renderType: Text.NativeRendering
    }
    Text {
      anchors.left: parent.left
      anchors.leftMargin: root.clockSize * 0.09
      anchors.verticalCenter: parent.verticalCenter
      text: "IX"
      color: root.faceColor
      font.family: "Liberation Serif"
      font.pixelSize: root.clockSize * 0.11
      font.weight: Font.Bold
      renderType: Text.NativeRendering
    }

    // Outer Railroad track
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.94
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 1
      border.color: Util.alpha(root.faceColor, 0.25)
    }

    // Minute ticks around rim
    Repeater {
      model: 60
      Item {
        required property int index
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        rotation: index * 6

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: root.clockSize * 0.03
          width: 1
          height: index % 5 === 0 ? root.clockSize * 0.035 : root.clockSize * 0.018
          color: Util.alpha(root.faceColor, index % 5 === 0 ? 0.7 : 0.3)
        }
      }
    }

    // Classic sword hour hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.hours % 12 + root.minutes / 60) * 30

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: Math.max(3, root.clockSize * 0.04)
        height: root.clockSize * 0.28
        radius: 1
        color: root.faceColor
      }
    }

    // Classic sword minute hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.minutes + root.seconds / 60) * 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: Math.max(2, root.clockSize * 0.028)
        height: root.clockSize * 0.38
        radius: 1
        color: Util.alpha(root.faceColor, 0.9)
      }
    }

    // Delicate sweeping second hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: root.secondRotation
      Behavior on rotation {
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        width: 1.5
        height: root.clockSize * 0.44
        color: root.accentColor
      }
    }

    // Center metallic cap
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.045
      height: width
      radius: width / 2
      color: root.accentColor
      border.width: 1
      border.color: root.faceColor
    }
  }

  // =========================================================================
  // 4. CYBER VARIANT (Glowing Cyberpunk Dial with Digital Readout)
  // =========================================================================
  Item {
    id: cyberFace
    anchors.fill: parent
    visible: root.variant === "cyber"

    // Concentric inner tech ring
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.65
      height: width
      radius: width / 2
      color: "transparent"
      border.width: 1
      border.color: Util.alpha(root.accentColor, 0.35)
    }

    // Concentric center core
    Rectangle {
      anchors.centerIn: parent
      width: root.clockSize * 0.38
      height: width
      radius: width / 2
      color: Util.alpha(root.accentColor, 0.1)
      border.width: 1
      border.color: Util.alpha(root.accentColor, 0.5)

      // Center digital readout
      Text {
        anchors.centerIn: parent
        text: (Math.floor(root.hours) < 10 ? "0" : "") + Math.floor(root.hours) + ":" +
              (Math.floor(root.minutes) < 10 ? "0" : "") + Math.floor(root.minutes)
        color: root.accentColor
        font.family: "JetBrainsMono NF"
        font.pixelSize: root.clockSize * 0.09
        font.weight: Font.Bold
        renderType: Text.NativeRendering
      }
    }

    // 12 Glowing radar notches
    Repeater {
      model: 12
      Item {
        required property int index
        anchors.centerIn: parent
        width: root.clockSize
        height: root.clockSize
        rotation: index * 30

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: root.clockSize * 0.04
          width: index % 3 === 0 ? 3 : 1.5
          height: index % 3 === 0 ? root.clockSize * 0.08 : root.clockSize * 0.04
          radius: 1
          color: index % 3 === 0 ? root.accentColor : Util.alpha(root.accentColor, 0.4)
        }
      }
    }

    // Angular hour hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.hours % 12 + root.minutes / 60) * 30

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: root.clockSize * 0.19
        width: Math.max(3, root.clockSize * 0.035)
        height: root.clockSize * 0.14
        radius: 2
        color: root.faceColor
      }
    }

    // Angular minute hand
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: (root.minutes + root.seconds / 60) * 6

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: root.clockSize * 0.19
        width: Math.max(2, root.clockSize * 0.025)
        height: root.clockSize * 0.22
        radius: 2
        color: root.accentColor
      }
    }

    // Outer orbiting neon second blip
    Item {
      anchors.centerIn: parent
      width: root.clockSize
      height: root.clockSize
      rotation: root.secondRotation
      Behavior on rotation {
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.clockSize * 0.025
        width: root.clockSize * 0.045
        height: width
        radius: width / 2
        color: root.accentColor
      }
    }
  }
}