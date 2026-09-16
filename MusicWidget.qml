import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons

// Music widget — live MPRIS integration with real-time metadata, album art,
// playback controls (play/pause/prev/next), and multiple modern aesthetic designs.
Item {
  id: root

  component PlayIcon: Item {
    id: playIco
    property real iconSize: Style.space(11)
    property color iconColor: Color.popups.background
    width: iconSize
    height: iconSize

    Shape {
      width: playIco.width * 0.88
      height: playIco.height
      anchors.centerIn: parent

      ShapePath {
        fillColor: playIco.iconColor
        strokeColor: "transparent"
        startX: 0
        startY: 0
        PathLine { x: width; y: height / 2 }
        PathLine { x: 0; y: height }
        PathLine { x: 0; y: 0 }
      }
    }
  }

  component PauseIcon: Item {
    id: pauseIco
    property real iconSize: Style.space(11)
    property color iconColor: Color.popups.background
    width: iconSize
    height: iconSize

    Row {
      anchors.centerIn: parent
      spacing: Math.max(2, pauseIco.width * 0.25)

      Rectangle {
        width: Math.max(2, pauseIco.width * 0.28)
        height: pauseIco.height
        radius: width / 2
        color: pauseIco.iconColor
      }
      Rectangle {
        width: Math.max(2, pauseIco.width * 0.28)
        height: pauseIco.height
        radius: width / 2
        color: pauseIco.iconColor
      }
    }
  }

  component PrevIcon: Item {
    id: prevIco
    property real iconSize: Style.space(11)
    property color iconColor: root.fgColor
    width: iconSize
    height: iconSize

    Row {
      anchors.centerIn: parent
      spacing: 1

      Rectangle {
        width: Math.max(1.5, prevIco.width * 0.18)
        height: prevIco.height * 0.95
        radius: 0.5
        color: prevIco.iconColor
      }
      Shape {
        width: prevIco.width * 0.72
        height: prevIco.height * 0.95
        ShapePath {
          fillColor: prevIco.iconColor
          strokeColor: "transparent"
          startX: width
          startY: 0
          PathLine { x: 0; y: height / 2 }
          PathLine { x: width; y: height }
          PathLine { x: width; y: 0 }
        }
      }
    }
  }

  component NextIcon: Item {
    id: nextIco
    property real iconSize: Style.space(11)
    property color iconColor: root.fgColor
    width: iconSize
    height: iconSize

    Row {
      anchors.centerIn: parent
      spacing: 1

      Shape {
        width: nextIco.width * 0.72
        height: nextIco.height * 0.95
        ShapePath {
          fillColor: nextIco.iconColor
          strokeColor: "transparent"
          startX: 0
          startY: 0
          PathLine { x: width; y: height / 2 }
          PathLine { x: 0; y: height }
          PathLine { x: 0; y: 0 }
        }
      }
      Rectangle {
        width: Math.max(1.5, nextIco.width * 0.18)
        height: nextIco.height * 0.95
        radius: 0.5
        color: nextIco.iconColor
      }
    }
  }

  property real widgetWidth: Style.space(280)
  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property color mutedColor: Util.alpha(Color.foreground, 0.6)
  property string variant: "card"
  property bool interactive: true

  // ---- MPRIS connection ---------------------------------------------------
  readonly property var playersList: Mpris.players ? Mpris.players.values : []

  // Select the active player: prefer actively playing, fallback to first with metadata
  readonly property var activePlayer: {
    if (!playersList || playersList.length === 0) return null
    for (var i = 0; i < playersList.length; i++) {
      var p = playersList[i]
      if (p && p.isPlaying) return p
    }
    for (var j = 0; j < playersList.length; j++) {
      var q = playersList[j]
      if (q && (q.trackTitle || q.trackArtist)) return q
    }
    return playersList[0] || null
  }

  readonly property bool hasTrack: activePlayer !== null && (activePlayer.trackTitle !== "" || activePlayer.trackArtist !== "")
  readonly property string title: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "Nothing Playing"
  readonly property string artist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : (hasTrack ? "Unknown Artist" : "Desktop Media")
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property bool playing: activePlayer ? !!activePlayer.isPlaying : false
  property real currentPositionSec: 0
  readonly property real positionSec: currentPositionSec
  readonly property real durationSec: {
    if (!activePlayer) return 0
    if (activePlayer.length && activePlayer.length > 0) return Number(activePlayer.length)
    if (activePlayer.metadata && activePlayer.metadata["mpris:length"]) {
      var raw = Number(activePlayer.metadata["mpris:length"])
      if (raw > 1000000) return raw / 1000000
      return raw
    }
    return 0
  }

  // Live second-by-second position tracker
  Timer {
    id: positionTicker
    interval: 500
    running: root.playing && root.visible
    repeat: true
    onTriggered: {
      var playerPos = root.activePlayer ? Number(root.activePlayer.position || 0) : 0
      if (playerPos > 0 && Math.abs(playerPos - root.currentPositionSec) > 2.0) {
        root.currentPositionSec = playerPos
      } else {
        var nextPos = root.currentPositionSec + 0.5
        if (root.durationSec > 0 && nextPos > root.durationSec) {
          nextPos = root.durationSec
        }
        root.currentPositionSec = nextPos
      }
    }
  }

  onPlayingChanged: {
    if (root.activePlayer) {
      root.currentPositionSec = Number(root.activePlayer.position || 0)
    }
  }

  onTitleChanged: {
    if (root.activePlayer) {
      root.currentPositionSec = Number(root.activePlayer.position || 0)
    } else {
      root.currentPositionSec = 0
    }
  }

  Component.onCompleted: {
    if (root.activePlayer) {
      root.currentPositionSec = Number(root.activePlayer.position || 0)
    }
  }

  Connections {
    target: root.activePlayer
    function onPositionChanged() {
      if (root.activePlayer) root.currentPositionSec = Number(root.activePlayer.position || 0)
    }
    function onIsPlayingChanged() {
      if (root.activePlayer) root.currentPositionSec = Number(root.activePlayer.position || 0)
    }
    function onTrackTitleChanged() {
      if (root.activePlayer) root.currentPositionSec = Number(root.activePlayer.position || 0)
    }
  }

  function runMprisAction(action) {
    if (action === "playPause") {
      if (root.activePlayer) {
        if (root.activePlayer.isPlaying && root.activePlayer.canPause) root.activePlayer.pause()
        else if (!root.activePlayer.isPlaying && root.activePlayer.canPlay) root.activePlayer.play()
        else if (root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
        else Quickshell.execDetached(["omarchy-shell", "media", "playPause"])
      } else {
        Quickshell.execDetached(["omarchy-shell", "media", "playPause"])
      }
    } else if (action === "next") {
      if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next()
      else Quickshell.execDetached(["omarchy-shell", "media", "next"])
    } else if (action === "previous") {
      if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
      else Quickshell.execDetached(["omarchy-shell", "media", "previous"])
    }
  }

  function formatTime(sec) {
    if (!sec || isNaN(sec) || sec <= 0) return "0:00"
    var m = Math.floor(sec / 60)
    var s = Math.floor(sec % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
  }

  function togglePlay() {
    runMprisAction("playPause")
  }

  function nextTrack() {
    runMprisAction("next")
  }

  function prevTrack() {
    runMprisAction("previous")
  }

  width: {
    if (variant === "compact") return Style.space(240) * root.widgetScale
    if (variant === "vinyl") return Style.space(310) * root.widgetScale
    if (variant === "cassette") return Style.space(210) * root.widgetScale
    return widgetWidth * root.widgetScale
  }
  height: {
    if (variant === "compact") return Style.space(48) * root.widgetScale
    if (variant === "vinyl") return Style.space(116) * root.widgetScale
    if (variant === "cassette") return Style.space(280) * root.widgetScale
    return Style.space(100) * root.widgetScale
  }

  // =========================================================================
  // 1. CARD VARIANT: Modern Glassmorphic Album Card
  // =========================================================================
  Rectangle {
    id: cardRoot
    anchors.fill: parent
    visible: root.variant === "card"
    radius: Style.space(14)
    color: Util.alpha(Color.popups.background, 0.82)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(12)

      // Album Art / Fallback
      Rectangle {
        width: Style.space(80)
        height: Style.space(80)
        radius: Style.space(10)
        color: Util.alpha(root.accentColor, 0.15)
        clip: true

        Image {
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          visible: root.artUrl !== ""
          asynchronous: true
          mipmap: true
          smooth: true
        }

        // Fallback icon when no art
        Text {
          anchors.centerIn: parent
          visible: root.artUrl === ""
          text: "\u{266B}"
          color: root.accentColor
          font.pixelSize: Style.space(32)
        }
      }

      // Track details and controls
      Column {
        width: parent.width - Style.space(92)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        // Track title
        Text {
          width: parent.width
          text: root.title
          color: root.fgColor
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.weight: Font.Bold
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        // Artist & album
        Text {
          width: parent.width
          text: root.artist + (root.album ? " \u{00B7} " + root.album : "")
          color: root.mutedColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        Item { width: 1; height: Style.space(2) }

        // Controls row
        Row {
          spacing: Style.space(12)
          anchors.horizontalCenter: parent.horizontalCenter

          // Prev
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: width / 2
            color: prevArea.containsMouse ? Util.alpha(root.fgColor, 0.15) : "transparent"
            PrevIcon {
              anchors.centerIn: parent
              iconSize: Style.space(10)
              iconColor: root.fgColor
            }
            MouseArea {
              id: prevArea
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.prevTrack()
            }
          }

          // Play / Pause
          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: width / 2
            color: playArea.containsMouse ? root.accentColor : Util.alpha(root.accentColor, 0.85)
            Behavior on color { ColorAnimation { duration: 100 } }

            PlayIcon {
              anchors.centerIn: parent
              visible: !root.playing
              iconSize: Style.space(11)
              iconColor: Color.popups.background
            }
            PauseIcon {
              anchors.centerIn: parent
              visible: root.playing
              iconSize: Style.space(11)
              iconColor: Color.popups.background
            }
            MouseArea {
              id: playArea
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlay()
            }
          }

          // Next
          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: width / 2
            color: nextArea.containsMouse ? Util.alpha(root.fgColor, 0.15) : "transparent"
            NextIcon {
              anchors.centerIn: parent
              iconSize: Style.space(10)
              iconColor: root.fgColor
            }
            MouseArea {
              id: nextArea
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.nextTrack()
            }
          }
        }

        // Progress line
        Rectangle {
          width: parent.width
          height: Style.space(3)
          radius: height / 2
          color: Util.alpha(root.fgColor, 0.15)

          Rectangle {
            width: root.durationSec > 0
              ? Math.max(height, parent.width * Math.min(1.0, root.positionSec / root.durationSec))
              : 0
            height: parent.height
            radius: height / 2
            color: root.accentColor
            Behavior on width { NumberAnimation { duration: 300 } }
          }
        }
      }
    }
  }

  // =========================================================================
  // 2. COMPACT VARIANT: Minimalist Status Pill
  // =========================================================================
  Rectangle {
    id: compactRoot
    anchors.fill: parent
    visible: root.variant === "compact"
    radius: height / 2
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(8)

      // Mini circle art
      Rectangle {
        width: parent.height
        height: parent.height
        radius: width / 2
        color: Util.alpha(root.accentColor, 0.2)
        clip: true

        Image {
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          visible: root.artUrl !== ""
          asynchronous: true
          mipmap: true
          smooth: true
        }

        Text {
          anchors.centerIn: parent
          visible: root.artUrl === ""
          text: "\u{266B}"
          color: root.accentColor
          font.pixelSize: Style.space(16)
        }
      }

      // Title & artist column
      Column {
        width: parent.width - parent.height - Style.space(42)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
          width: parent.width
          text: root.title
          color: root.fgColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.Bold
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        Text {
          width: parent.width
          text: root.artist
          color: root.mutedColor
          font.family: Style.font.family
          font.pixelSize: Style.space(9)
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }
      }

      // Compact play button
      Rectangle {
        width: parent.height - Style.space(4)
        height: width
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: compactPlayArea.containsMouse ? root.accentColor : Util.alpha(root.accentColor, 0.85)

        PlayIcon {
          anchors.centerIn: parent
          visible: !root.playing
          iconSize: Style.space(10)
          iconColor: Color.popups.background
        }
        PauseIcon {
          anchors.centerIn: parent
          visible: root.playing
          iconSize: Style.space(10)
          iconColor: Color.popups.background
        }

        MouseArea {
          id: compactPlayArea
          anchors.fill: parent
          preventStealing: true
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.togglePlay()
        }
      }
    }
  }

  // =========================================================================
  // 3. VINYL VARIANT: Aesthetic Retro Turntable
  // =========================================================================
  Rectangle {
    id: vinylRoot
    anchors.fill: parent
    visible: root.variant === "vinyl"
    radius: Style.space(16)
    color: Util.alpha(Color.popups.background, 0.85)
    border.width: 1
    border.color: Util.alpha(root.fgColor, 0.14)

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(14)

      // Turntable deck area (vinyl disc + tonearm)
      Item {
        width: Style.space(104)
        height: Style.space(96)
        anchors.verticalCenter: parent.verticalCenter

        // Spinning vinyl record disc (Picture Disc with full album art)
        Item {
          id: vinylDisc
          width: Style.space(96)
          height: Style.space(96)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          // Circular mask source
          Item {
            id: discMask
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: "#ffffff"
            }
          }

          // Main disc surface masked to perfect circle
          Item {
            id: discSurface
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
              maskEnabled: true
              maskSource: discMask
              maskThresholdMin: 0.5
              maskSpreadAtMin: 1.0
            }

            // Dark vinyl base
            Rectangle {
              anchors.fill: parent
              color: "#141416"
            }

            // Full-disc album artwork thumbnail
            Image {
              id: discArt
              anchors.fill: parent
              source: root.artUrl
              fillMode: Image.PreserveAspectCrop
              visible: root.artUrl !== ""
              asynchronous: true
              mipmap: true
              smooth: true
            }

            // Fallback music note when no art is available
            Text {
              anchors.centerIn: parent
              visible: root.artUrl === ""
              text: "\u{266A}"
              color: root.accentColor
              font.pixelSize: Style.space(26)
            }

            // Concentric vinyl micro-groove rings across entire picture disc
            Repeater {
              model: [0.94, 0.86, 0.76, 0.66, 0.54, 0.42, 0.30]
              Rectangle {
                required property real modelData
                anchors.centerIn: parent
                width: vinylDisc.width * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Util.alpha("#ffffff", 0.09)
              }
            }

            // Outer edge dark rim shading for authentic vinyl depth
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: "transparent"
              border.width: Style.space(3)
              border.color: Util.alpha("#000000", 0.45)
            }

            // Vinyl glossy specular sheen reflections (light reflections)
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Util.alpha("#ffffff", 0.0) }
                GradientStop { position: 0.28; color: Util.alpha("#ffffff", 0.13) }
                GradientStop { position: 0.36; color: Util.alpha("#ffffff", 0.0) }
                GradientStop { position: 0.64; color: Util.alpha("#ffffff", 0.0) }
                GradientStop { position: 0.72; color: Util.alpha("#ffffff", 0.11) }
                GradientStop { position: 1.0; color: Util.alpha("#ffffff", 0.0) }
              }
            }

            // Outer rim thin contour
            Rectangle {
              anchors.fill: parent
              radius: width / 2
              color: "transparent"
              border.width: 1.5
              border.color: Util.alpha("#ffffff", 0.18)
            }

            // Center spindle metallic collar & hole
            Rectangle {
              anchors.centerIn: parent
              width: Style.space(16)
              height: width
              radius: width / 2
              color: Util.alpha(Color.popups.background, 0.8)
              border.width: 1
              border.color: Util.alpha(Color.foreground, 0.35)

              // Spindle center cutout
              Rectangle {
                anchors.centerIn: parent
                width: Style.space(7)
                height: width
                radius: width / 2
                color: Color.popups.background
              }
            }
          }

          // Smooth rotation when playing
          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 3600
            loops: Animation.Infinite
            running: root.playing
          }
        }

        // Tactile tonearm resting on record when playing
        Item {
          id: tonearm
          x: Style.space(88)
          y: Style.space(6)
          width: Style.space(14)
          height: Style.space(66)
          transformOrigin: Item.Top

          // Tonearm pivot base
          Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(10)
            height: Style.space(10)
            radius: width / 2
            color: "#3f3f46"
            border.width: 1
            border.color: "#71717a"
          }

          // Metal arm stem
          Rectangle {
            anchors.top: parent.top
            anchors.topMargin: Style.space(5)
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(2)
            height: Style.space(50)
            color: "#d4d4d8"
          }

          // Cartridge / needle head
          Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(6)
            height: Style.space(10)
            radius: 1
            color: root.accentColor
          }

          rotation: root.playing ? 24 : 0
          Behavior on rotation {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
          }
        }
      }

      // Track info and controls
      Column {
        width: parent.width - Style.space(122)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        Text {
          width: parent.width
          text: root.title
          font.bold: true
          color: root.fgColor
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        Text {
          width: parent.width
          text: root.artist
          color: root.mutedColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          renderType: Text.NativeRendering
        }

        // Time indicators
        Item {
          width: parent.width
          height: Style.space(12)
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.positionSec)
            color: root.mutedColor
            font.pixelSize: Style.space(9)
          }
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.durationSec)
            color: root.mutedColor
            font.pixelSize: Style.space(9)
          }
        }

        // Progress bar
        Rectangle {
          width: parent.width
          height: Style.space(3)
          radius: height / 2
          color: Util.alpha(root.fgColor, 0.15)

          Rectangle {
            width: root.durationSec > 0
              ? Math.max(height, parent.width * Math.min(1.0, root.positionSec / root.durationSec))
              : 0
            height: parent.height
            radius: height / 2
            color: root.accentColor
            Behavior on width { NumberAnimation { duration: 300 } }
          }
        }

        Item { width: 1; height: Style.space(2) }

        // Playback buttons
        Row {
          z: 10
          spacing: Style.space(12)
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: width / 2
            color: vinylPrev.containsMouse ? Util.alpha(root.fgColor, 0.15) : "transparent"
            PrevIcon {
              anchors.centerIn: parent
              iconSize: Style.space(10)
              iconColor: root.fgColor
            }
            MouseArea {
              id: vinylPrev
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.prevTrack()
            }
          }

          Rectangle {
            width: Style.space(28)
            height: Style.space(28)
            radius: width / 2
            color: vinylPlay.containsMouse ? root.accentColor : Util.alpha(root.accentColor, 0.85)

            PlayIcon {
              anchors.centerIn: parent
              visible: !root.playing
              iconSize: Style.space(11)
              iconColor: Color.popups.background
            }
            PauseIcon {
              anchors.centerIn: parent
              visible: root.playing
              iconSize: Style.space(11)
              iconColor: Color.popups.background
            }
            MouseArea {
              id: vinylPlay
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.togglePlay()
            }
          }

          Rectangle {
            width: Style.space(26)
            height: Style.space(26)
            radius: width / 2
            color: vinylNext.containsMouse ? Util.alpha(root.fgColor, 0.15) : "transparent"
            NextIcon {
              anchors.centerIn: parent
              iconSize: Style.space(10)
              iconColor: root.fgColor
            }
            MouseArea {
              id: vinylNext
              anchors.fill: parent
              preventStealing: true
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.nextTrack()
            }
          }
        }
      }
    }
  }

  // =========================================================================
  // 4. CASSETTE VARIANT: Retro Vertical 80s Mixtape Tape Deck
  // =========================================================================
  Rectangle {
    id: cassetteRoot
    anchors.fill: parent
    visible: root.variant === "cassette"
    radius: Style.space(14) * root.widgetScale
    color: "#16171d"
    border.width: 1.5
    border.color: "#2a2c38"
    clip: true

    // Cassette corner screws
    Repeater {
      model: [
        { x: Style.space(6) * root.widgetScale, y: Style.space(6) * root.widgetScale },
        { x: cassetteRoot.width - Style.space(14) * root.widgetScale, y: Style.space(6) * root.widgetScale },
        { x: Style.space(6) * root.widgetScale, y: cassetteRoot.height - Style.space(14) * root.widgetScale },
        { x: cassetteRoot.width - Style.space(14) * root.widgetScale, y: cassetteRoot.height - Style.space(14) * root.widgetScale }
      ]
      Rectangle {
        required property var modelData
        x: modelData.x
        y: modelData.y
        width: Style.space(8) * root.widgetScale
        height: Style.space(8) * root.widgetScale
        radius: width / 2
        color: "#27272a"
        border.width: 1
        border.color: "#3f3f46"

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(5) * root.widgetScale
          height: 1
          color: "#52525b"
        }
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(10) * root.widgetScale
      spacing: Style.space(8) * root.widgetScale

      // Top Cassette Header: SIDE A | Retro Stripes | STEREO C-90
      Item {
        width: parent.width
        height: Style.space(16) * root.widgetScale

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6) * root.widgetScale

          Rectangle {
            width: Style.space(34) * root.widgetScale
            height: Style.space(14) * root.widgetScale
            radius: Style.space(3) * root.widgetScale
            color: root.accentColor

            Text {
              anchors.centerIn: parent
              text: "SIDE A"
              color: Color.popups.background
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(8) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }
          }

          // Retro decorative stripes
          Column {
            width: Style.space(32) * root.widgetScale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Rectangle { width: parent.width; height: 1.5; color: "#f97316" }
            Rectangle { width: parent.width; height: 1.5; color: "#eab308" }
            Rectangle { width: parent.width; height: 1.5; color: "#06b6d4" }
          }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "STEREO · C-90"
          color: Util.alpha(root.fgColor, 0.45)
          font.family: "JetBrainsMono NF"
          font.pixelSize: Style.space(8) * root.widgetScale
          renderType: Text.QtRendering
        }
      }

      // Middle: Center Clear Cassette Tape Window (with dual spinning spools!)
      Rectangle {
        width: parent.width
        height: Style.space(88) * root.widgetScale
        radius: Style.space(8) * root.widgetScale
        color: "#0a0b0f"
        border.width: 1
        border.color: "#252733"

        // Magnetic brown tape ribbon connecting behind spools
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width * 0.72
          height: Style.space(14) * root.widgetScale
          color: "#35150a"
        }

        Row {
          anchors.centerIn: parent
          spacing: Style.space(26) * root.widgetScale

          // Left Tape Spool (Supply)
          Item {
            id: leftSpool
            width: Style.space(34) * root.widgetScale
            height: Style.space(34) * root.widgetScale

            // Brown tape pack on left reel (diminishes as song plays)
            Rectangle {
              anchors.centerIn: parent
              readonly property real prog: root.durationSec > 0 ? Math.min(1.0, root.positionSec / root.durationSec) : 0.4
              width: Style.space(34 - 12 * prog) * root.widgetScale
              height: width
              radius: width / 2
              color: "#451a03"
            }

            // White gear wheel hub
            Rectangle {
              anchors.centerIn: parent
              width: Style.space(20) * root.widgetScale
              height: Style.space(20) * root.widgetScale
              radius: width / 2
              color: "#e4e4e7"
              border.width: 1
              border.color: "#71717a"

              Repeater {
                model: 3
                Rectangle {
                  required property int index
                  anchors.centerIn: parent
                  width: Style.space(18) * root.widgetScale
                  height: Style.space(3.5) * root.widgetScale
                  color: "#18181b"
                  rotation: index * 60
                }
              }

              Rectangle {
                anchors.centerIn: parent
                width: Style.space(7) * root.widgetScale
                height: Style.space(7) * root.widgetScale
                radius: width / 2
                color: "#09090b"
              }
            }

            RotationAnimation on rotation {
              from: 0
              to: 360
              duration: 2400
              loops: Animation.Infinite
              running: root.playing
            }
          }

          // Center tape scale ticks [ 100 · 50 · 0 ]
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3) * root.widgetScale

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.playing ? "PLAY" : "PAUSE"
              color: root.playing ? root.accentColor : Util.alpha(root.fgColor, 0.4)
              font.family: "JetBrainsMono NF"
              font.pixelSize: Style.space(8) * root.widgetScale
              font.weight: Font.Bold
              renderType: Text.QtRendering
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(3) * root.widgetScale
              Repeater {
                model: 5
                Rectangle {
                  width: 1
                  height: Style.space(5) * root.widgetScale
                  color: Util.alpha("#ffffff", 0.3)
                }
              }
            }
          }

          // Right Tape Spool (Takeup)
          Item {
            id: rightSpool
            width: Style.space(34) * root.widgetScale
            height: Style.space(34) * root.widgetScale

            // Brown tape pack on right reel (grows as song plays)
            Rectangle {
              anchors.centerIn: parent
              readonly property real prog: root.durationSec > 0 ? Math.min(1.0, root.positionSec / root.durationSec) : 0.4
              width: Style.space(22 + 12 * prog) * root.widgetScale
              height: width
              radius: width / 2
              color: "#451a03"
            }

            Rectangle {
              anchors.centerIn: parent
              width: Style.space(20) * root.widgetScale
              height: Style.space(20) * root.widgetScale
              radius: width / 2
              color: "#e4e4e7"
              border.width: 1
              border.color: "#71717a"

              Repeater {
                model: 3
                Rectangle {
                  required property int index
                  anchors.centerIn: parent
                  width: Style.space(18) * root.widgetScale
                  height: Style.space(3.5) * root.widgetScale
                  color: "#18181b"
                  rotation: index * 60
                }
              }

              Rectangle {
                anchors.centerIn: parent
                width: Style.space(7) * root.widgetScale
                height: Style.space(7) * root.widgetScale
                radius: width / 2
                color: "#09090b"
              }
            }

            RotationAnimation on rotation {
              from: 0
              to: 360
              duration: 2400
              loops: Animation.Infinite
              running: root.playing
            }
          }
        }
      }

      // Track info banner (Title, Artist, Album)
      Column {
        width: parent.width
        spacing: Style.space(2) * root.widgetScale

        Text {
          width: parent.width
          text: root.title
          color: "#f4f4f5"
          font.family: Style.font.family
          font.pixelSize: Style.space(12) * root.widgetScale
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          clip: true
          renderType: Text.QtRendering
        }

        Text {
          width: parent.width
          text: root.artist + (root.album ? " \u{00B7} " + root.album : "")
          color: Util.alpha(root.fgColor, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.space(9) * root.widgetScale
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          clip: true
          renderType: Text.QtRendering
        }
      }

      // Scrubber Track & Timestamps
      Column {
        width: parent.width
        spacing: Style.space(4) * root.widgetScale

        Rectangle {
          width: parent.width
          height: Style.space(3.5) * root.widgetScale
          radius: height / 2
          color: Util.alpha(root.fgColor, 0.15)

          Rectangle {
            width: root.durationSec > 0
              ? Math.max(height, parent.width * Math.min(1.0, root.positionSec / root.durationSec))
              : 0
            height: parent.height
            radius: height / 2
            color: root.accentColor
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }

        Item {
          width: parent.width
          height: Style.space(12) * root.widgetScale

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.positionSec)
            color: Util.alpha(root.fgColor, 0.45)
            font.family: "JetBrainsMono NF"
            font.pixelSize: Style.space(8) * root.widgetScale
            renderType: Text.QtRendering
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatTime(root.durationSec)
            color: Util.alpha(root.fgColor, 0.45)
            font.family: "JetBrainsMono NF"
            font.pixelSize: Style.space(8) * root.widgetScale
            renderType: Text.QtRendering
          }
        }
      }

      // Bottom Tape Deck Mechanical Push Buttons
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(12) * root.widgetScale

        // REW (Prev)
        Rectangle {
          width: Style.space(36) * root.widgetScale
          height: Style.space(28) * root.widgetScale
          radius: Style.space(5) * root.widgetScale
          color: cassettePrevArea.containsMouse ? Util.alpha(root.fgColor, 0.22) : "#22242c"
          border.width: 1
          border.color: "#353846"

          PrevIcon {
            anchors.centerIn: parent
            iconSize: Style.space(11) * root.widgetScale
            iconColor: root.fgColor
          }
          MouseArea {
            id: cassettePrevArea
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevTrack()
          }
        }

        // PLAY / PAUSE (Large Accent Button)
        Rectangle {
          width: Style.space(48) * root.widgetScale
          height: Style.space(28) * root.widgetScale
          radius: Style.space(5) * root.widgetScale
          color: cassettePlayArea.containsMouse ? root.accentColor : Util.alpha(root.accentColor, 0.88)

          PlayIcon {
            anchors.centerIn: parent
            visible: !root.playing
            iconSize: Style.space(12) * root.widgetScale
            iconColor: Color.popups.background
          }
          PauseIcon {
            anchors.centerIn: parent
            visible: root.playing
            iconSize: Style.space(12) * root.widgetScale
            iconColor: Color.popups.background
          }
          MouseArea {
            id: cassettePlayArea
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlay()
          }
        }

        // FWD (Next)
        Rectangle {
          width: Style.space(36) * root.widgetScale
          height: Style.space(28) * root.widgetScale
          radius: Style.space(5) * root.widgetScale
          color: cassetteNextArea.containsMouse ? Util.alpha(root.fgColor, 0.22) : "#22242c"
          border.width: 1
          border.color: "#353846"

          NextIcon {
            anchors.centerIn: parent
            iconSize: Style.space(11) * root.widgetScale
            iconColor: root.fgColor
          }
          MouseArea {
            id: cassetteNextArea
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextTrack()
          }
        }
      }
    }
  }
}