import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// System telemetry widget — individual glassmorphic pills and ring pod blocks.
// Supports CPU, RAM, GPU individual widgets, as well as combined CPU+GPU temps pill.
Item {
  id: root

  property real widgetScale: 1
  property color fgColor: Color.foreground
  property color accentColor: Color.accent
  property string variant: "pill-cpu"
  property bool active: true

  readonly property string helperPath: Qt.resolvedUrl("sys-monitor.py").toString().replace(/^file:\/\//, "")

  // Telemetry state
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
  property real gpuMemPct: 0

  readonly property bool isPill: variant.indexOf("pill-") === 0
  readonly property bool isRing: variant.indexOf("ring-") === 0
  readonly property string channel: {
    if (variant === "pill-cpu" || variant === "ring-cpu") return "cpu"
    if (variant === "pill-ram" || variant === "ring-ram") return "ram"
    if (variant === "pill-gpu" || variant === "ring-gpu") return "gpu"
    if (variant === "pill-temps") return "temps"
    return "cpu"
  }

  width: {
    if (isPill) {
      return (variant === "pill-temps" ? Style.space(220) : Style.space(195)) * widgetScale
    }
    if (isRing) {
      return Style.space(120) * widgetScale
    }
    return Style.space(195) * widgetScale
  }

  height: {
    if (isPill) {
      return Style.space(48) * widgetScale
    }
    if (isRing) {
      return Style.space(136) * widgetScale
    }
    return Style.space(48) * widgetScale
  }

  function startProcess() {
    if (root.visible && root.active && !sysProc.running) {
      sysProc.running = true
    }
  }

  Component.onCompleted: Qt.callLater(root.startProcess)
  onVisibleChanged: {
    if (visible) startProcess()
    else sysProc.running = false
  }
  onActiveChanged: {
    if (active && visible) startProcess()
    else sysProc.running = false
  }

  Process {
    id: sysProc
    command: ["python3", root.helperPath]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          if (data.cpu) {
            root.cpuPct = Number(data.cpu.pct) || 0
            root.cpuTemp = Number(data.cpu.temp) || 0
          }
          if (data.ram) {
            root.ramPct = Number(data.ram.pct) || 0
            root.ramUsed = Number(data.ram.used) || 0
            root.ramTotal = Number(data.ram.total) || 0
          }
          if (data.gpu) {
            root.gpuAvail = !!data.gpu.avail
            root.gpuUtil = Number(data.gpu.util) || 0
            root.gpuTemp = Number(data.gpu.temp) || 0
            root.gpuMemUsed = Number(data.gpu.mem_used) || 0
            root.gpuMemTotal = Number(data.gpu.mem_total) || 0
            root.gpuMemPct = Number(data.gpu.mem_pct) || 0
          }
        } catch (e) {
          // parse error
        }
      }
    }
  }

  // =========================================================================
  // 1. INDIVIDUAL TELEMETRY PILL (CPU / RAM / GPU / TEMPS)
  // =========================================================================
  SysPillWidget {
    anchors.centerIn: parent
    visible: root.isPill
    channel: root.channel
    widgetScale: root.widgetScale
    fgColor: root.fgColor
    accentColor: root.accentColor
    cpuPct: root.cpuPct
    cpuTemp: root.cpuTemp
    ramPct: root.ramPct
    ramUsed: root.ramUsed
    ramTotal: root.ramTotal
    gpuAvail: root.gpuAvail
    gpuUtil: root.gpuUtil
    gpuTemp: root.gpuTemp
    gpuMemUsed: root.gpuMemUsed
    gpuMemTotal: root.gpuMemTotal
  }

  // =========================================================================
  // 2. INDIVIDUAL RING POD BLOCK (CPU / RAM / GPU)
  // =========================================================================
  SysRingBlockWidget {
    anchors.centerIn: parent
    visible: root.isRing
    channel: root.channel
    widgetScale: root.widgetScale
    fgColor: root.fgColor
    accentColor: root.accentColor
    cpuPct: root.cpuPct
    cpuTemp: root.cpuTemp
    ramPct: root.ramPct
    ramUsed: root.ramUsed
    ramTotal: root.ramTotal
    gpuAvail: root.gpuAvail
    gpuUtil: root.gpuUtil
    gpuTemp: root.gpuTemp
    gpuMemUsed: root.gpuMemUsed
    gpuMemTotal: root.gpuMemTotal
  }
}
