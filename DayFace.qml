import QtQuick
import Quickshell
import qs.Commons
import "Model.js" as Model

// Renders one day style: a primary line (the headline) and an optional
// secondary caption. Used at natural scale on the desktop and at a fitted
// scale inside the popup's preview cards. The SystemClock updates every
// second so digital clocks and time formats stay accurate in real-time.
Item {
  id: face

  required property string styleId
  property string defaultFamily: Style.font.family
  property real textScale: 1
  // Alias for compatibility
  property alias scale: face.textScale

  property color foreground: Color.foreground
  property color accent: Color.accent
  property color muted: Util.alpha(Color.foreground, 0.62)
  property date today: clock.date
  property real gap: Style.space(6) * face.textScale

  readonly property var rawStyle: Model.styleFor(styleId)
  // Widget-kind styles (analog, music, volume) have no text fields; fall back
  // to the first text style so bindings below never see undefined.
  readonly property var style: (rawStyle && typeof rawStyle.primarySize === "number")
    ? rawStyle : Model.styleFor("big-day")
  readonly property string primaryText: Model.formatDate(today, style.primaryFormat)
  readonly property string secondaryText: style.secondaryFormat
    ? Model.formatDate(today, style.secondaryFormat) : ""
  readonly property bool hasSecondary: secondaryText !== ""

  function textColor(kind) {
    if (kind === "accent") return face.accent
    if (kind === "muted") return face.muted
    return face.foreground
  }

  function weightNumber(weightName) {
    if (weightName === "Bold") return Font.Bold
    if (weightName === "Light") return Font.Light
    return Font.Normal
  }

  function familyFor(style) {
    return style.family ? style.family : face.defaultFamily
  }

  // SystemClock with Seconds precision ensures HH:mm, HH:mm:ss, and minutes
  // update continuously and never stay frozen at 00.
  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  width: implicitWidth
  height: implicitHeight

  implicitWidth: Math.max(primary.implicitWidth,
    secondary.visible ? secondary.implicitWidth : 0)
  implicitHeight: primary.implicitHeight
    + (secondary.visible ? face.gap + secondary.implicitHeight : 0)

  Text {
    id: primary
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    text: face.primaryText
    font.family: face.familyFor(face.style)
    font.pixelSize: Math.max(1, Math.round(face.style.primarySize * face.textScale))
    font.weight: face.weightNumber(face.style.weight)
    font.italic: face.style.italic
    font.letterSpacing: face.style.primarySpacing * face.textScale
    color: face.textColor(face.style.primaryColor)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignTop
    renderType: Text.QtRendering
    antialiasing: true
  }

  Text {
    id: secondary
    anchors.top: primary.bottom
    anchors.topMargin: face.gap
    anchors.horizontalCenter: parent.horizontalCenter
    visible: face.hasSecondary
    text: face.style.secondaryCase === "upper"
      ? face.secondaryText.toUpperCase() : face.secondaryText
    font.family: face.familyFor(face.style)
    font.pixelSize: Math.max(1, Math.round(face.style.secondarySize * face.textScale))
    font.weight: Font.Normal
    font.italic: false
    font.letterSpacing: face.style.secondarySpacing * face.textScale
    color: face.textColor(face.style.secondaryColor)
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.QtRendering
    antialiasing: true
  }
}