import QtQuick
import qs.Commons
import "Model.js" as Model

// Full-size copy of a desktop widget, shown while the user drags a style out
// of the popup. Lives in the popup's overlay surface, so its x/y are screen
// coordinates on the anchor monitor.
Item {
  id: ghost

  required property string styleId
  readonly property real pad: Style.space(10)

  DayFace {
    id: face
    anchors.centerIn: parent
    styleId: ghost.styleId
    scale: 1
    foreground: Color.foreground
    accent: Color.accent
    muted: Util.alpha(Color.foreground, 0.62)
  }

  width: Math.max(face.implicitWidth + pad * 2, Style.space(56))
  height: Math.max(face.implicitHeight + pad * 2, Style.space(56))

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius + ghost.pad
    color: Util.alpha(Color.popups.background, 0.92)
    border.width: 1
    border.color: Util.alpha(Color.accent, 0.7)
  }
}