import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Registry.js" as Reg

// Popup shown by the bar pill. Categories at the top, large preview in the
// middle, left/right arrows to cycle, click to place.
Panel {
  id: root
  moduleName: "whimsy"
  ipcTarget: "whimsy"
  manageIpc: true

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property date today: liveClock.date
  readonly property string fullDate: Model.formatDate(today, "dddd, MMMM d")

  // Category + preview index
  property int catIndex: 0
  property int widgetIndex: 0
  readonly property var currentCat: Model.categories()[catIndex]
  readonly property var allWidgets: Model.allFor(currentCat.id)
  readonly property var currentWidget: allWidgets.length > 0 ? allWidgets[widgetIndex] : null

  onCatIndexChanged: widgetIndex = 0
  onCurrentCatChanged: widgetIndex = 0

  SystemClock {
    id: liveClock
    precision: SystemClock.Seconds
  }

  readonly property var dayService: Reg.get()
    || (root.bar && root.bar.shell ? root.bar.shell.serviceFor("whimsy") : null)

  function open() { root.controller.show() }
  function openFromHotkey() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.openFromHotkey() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function panelScreen() {
    if (root.panel && root.panel.screen) return root.panel.screen
    if (root.hostWidget && root.hostWidget.screen) return root.hostWidget.screen
    return null
  }

  function placeWidget(styleId) {
    var svc = root.dayService
    if (!svc) return
    var screenObj = root.panelScreen()
    svc.placeWidget(styleId, screenObj ? screenObj.name : "")
    root.close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onReturnRequested: {
        if (root.currentWidget) root.placeWidget(root.currentWidget.id)
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx < 0) panel.navLeft()
        else if (dx > 0) panel.navRight()
        else if (dy < 0) {
          // Up: previous category
          if (root.catIndex > 0) root.catIndex--
          else root.catIndex = Model.categories().length - 1
        } else if (dy > 0) {
          // Down: next category
          if (root.catIndex < Model.categories().length - 1) root.catIndex++
          else root.catIndex = 0
        }
      }
    }

    function navLeft() {
      if (root.widgetIndex > 0) root.widgetIndex--
      else root.widgetIndex = root.allWidgets.length - 1
    }
    function navRight() {
      if (root.widgetIndex < root.allWidgets.length - 1) root.widgetIndex++
      else root.widgetIndex = 0
    }

    Column {
      id: contentColumn
      width: parent.width
      spacing: Style.space(14)

      // ---- category tabs -------------------------------------------------
      Row {
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: Model.categories()

          Rectangle {
            required property var modelData
            required property int index
            width: tabText.implicitWidth + Style.space(16)
            height: Style.space(28)
            radius: Style.space(8)
            color: root.catIndex === index
              ? Util.alpha(root.barForeground, 0.18)
              : (tabArea.containsMouse ? Util.alpha(root.barForeground, 0.08) : "transparent")

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              id: tabText
              anchors.centerIn: parent
              text: modelData.name.toUpperCase()
              color: root.catIndex === index
                ? root.barForeground
                : Util.alpha(root.barForeground, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: root.catIndex === index ? Font.Bold : Font.Normal
              font.letterSpacing: 1
              renderType: Text.NativeRendering
            }

            MouseArea {
              id: tabArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.catIndex = index
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.barForeground
        opacity: 0.12
      }

      // ---- preview area --------------------------------------------------
      Item {
        width: parent.width
        height: Style.space(190)

        // Center preview container
        Rectangle {
          id: previewContainer
          anchors.fill: parent
          radius: Style.space(14)
          color: previewAreaMouse.containsMouse
            ? Util.alpha(root.barForeground, 0.07)
            : Util.alpha(root.barForeground, 0.025)
          border.width: 1
          border.color: previewAreaMouse.containsMouse
            ? Util.alpha(Color.accent, 0.55)
            : Util.alpha(root.barForeground, 0.1)

          Behavior on color { ColorAnimation { duration: 120 } }
          Behavior on border.color { ColorAnimation { duration: 120 } }

          // Main widget render area
          Item {
            id: previewArea
            anchors.fill: parent
            anchors.margins: Style.space(12)

            // Text-based widgets (DayFace)
            DayFace {
              id: previewFace
              anchors.centerIn: parent
              visible: !root.currentWidget || !root.currentWidget.kind || root.currentWidget.kind === "text"
              styleId: root.currentWidget ? root.currentWidget.id : ""
              textScale: root.currentWidget ? Model.previewScale(root.currentWidget) : 1
              foreground: root.barForeground
              accent: Color.accent
              muted: Util.alpha(root.barForeground, 0.62)
            }

            // Analog clock
            AnalogClock {
              id: previewAnalog
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "analog"
              variant: root.currentWidget ? (root.currentWidget.variant || "station") : "station"
              clockSize: Style.space(140)
              faceColor: root.barForeground
              accentColor: Color.accent

              SystemClock {
                id: analogClock
                precision: SystemClock.Seconds
              }
              hours: analogClock.hours
              minutes: analogClock.minutes
              seconds: analogClock.seconds
            }

            // Flip mechanical clock
            FlipClock {
              id: previewFlip
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "flip"
              clockScale: 0.95
              accentColor: Color.accent
              fgColor: root.barForeground
            }

            // Cyberpunk HUD clock
            CyberClock {
              id: previewCyber
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "cyber"
              clockScale: 0.9
              accentColor: Color.accent
              fgColor: root.barForeground
            }

            // Day progress meter
            DayProgress {
              id: previewProgress
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "progress"
              widgetScale: 0.92
              accentColor: Color.accent
              fgColor: root.barForeground
            }

            // Music widget
            MusicWidget {
              id: previewMusic
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "music"
              variant: root.currentWidget ? (root.currentWidget.variant || "card") : "card"
              interactive: false
              widgetScale: root.currentWidget && root.currentWidget.variant === "cassette" ? 0.62 : 0.85
              widgetWidth: Style.space(260)
              fgColor: root.barForeground
              accentColor: Color.accent
            }

            // Visualizer widget
            VisualizerWidget {
              id: previewVisualizer
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "visualizer"
              variant: root.currentWidget ? (root.currentWidget.variant || "dots") : "dots"
              active: root.opened
              visScale: root.currentWidget && root.currentWidget.variant === "vumeter" ? 0.78 : 0.88
              widgetWidth: Style.space(260)
              widgetHeight: Style.space(70)
              fgColor: root.barForeground
              accentColor: Color.accent
            }

            // Volume widget
            VolumeWidget {
              id: previewVolume
              anchors.centerIn: parent
              visible: root.currentWidget && root.currentWidget.kind === "volume"
              barWidth: Style.space(280)
              barHeight: Style.space(40)
              fillColor: Color.accent
              fgColor: root.barForeground
            }
          }

          // Direct click to place widget on desktop
          MouseArea {
            id: previewAreaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.currentWidget) root.placeWidget(root.currentWidget.id)
            }
          }

          // Floating Left Chevron
          Rectangle {
            id: leftArrow
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30)
            height: Style.space(30)
            radius: width / 2
            color: leftArea.containsMouse
              ? Util.alpha(root.barForeground, 0.22)
              : Util.alpha(root.barForeground, 0.08)
            opacity: leftArea.containsMouse ? 1.0 : 0.6
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on opacity { NumberAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              text: "\u{2039}"
              color: root.barForeground
              font.pixelSize: Style.space(20)
              font.weight: Font.Bold
            }

            MouseArea {
              id: leftArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.navLeft()
            }
          }

          // Floating Right Chevron
          Rectangle {
            id: rightArrow
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30)
            height: Style.space(30)
            radius: width / 2
            color: rightArea.containsMouse
              ? Util.alpha(root.barForeground, 0.22)
              : Util.alpha(root.barForeground, 0.08)
            opacity: rightArea.containsMouse ? 1.0 : 0.6
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on opacity { NumberAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              text: "\u{203A}"
              color: root.barForeground
              font.pixelSize: Style.space(20)
              font.weight: Font.Bold
            }

            MouseArea {
              id: rightArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.navRight()
            }
          }
        }
      }

      // ---- widget title & dot pagination ---------------------------------
      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.currentWidget ? root.currentWidget.name : ""
          color: root.barForeground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
          font.letterSpacing: 0.5
          renderType: Text.NativeRendering
        }

        // Sleek animated pill indicators
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)
          visible: root.allWidgets.length > 1

          Repeater {
            model: root.allWidgets.length

            Rectangle {
              required property int index
              width: root.widgetIndex === index ? Style.space(18) : Style.space(6)
              height: Style.space(6)
              radius: Style.space(3)
              color: root.widgetIndex === index
                ? Color.accent
                : Util.alpha(root.barForeground, 0.22)

              Behavior on width { NumberAnimation { duration: 150 } }
              Behavior on color { ColorAnimation { duration: 150 } }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.widgetIndex = index
              }
            }
          }
        }
      }
    }
  }
}
