// Model.js — widget definitions, styles, and date formatting for whimsy.
//
// Categories group widgets in the popup; each entry has a kind that tells
// DesktopCard and Panel which renderer to use:
// - text (DayFace)
// - analog (AnalogClock)
// - flip (FlipClock)
// - cyber (CyberClock)
// - progress (DayProgress)
// - music (MusicWidget)
// - visualizer (VisualizerWidget)
// - volume (VolumeWidget)

var CATEGORIES = [
  { id: "time",       name: "Time" },
  { id: "date",       name: "Date" },
  { id: "media",      name: "Media" },
  { id: "visualizer", name: "Visualizer" }
]

// ---- text-based date/time styles (rendered by DayFace) -------------------

var TEXT_STYLES = [
  // ---- TIME category
  {
    id: "digital-clean",
    category: "time",
    name: "Digital Clean",
    family: "JetBrainsMono NF",
    weight: "Bold",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 44,
    primaryColor: "strong",
    primarySpacing: 2,
    secondaryFormat: "ss",
    secondarySize: 14,
    secondaryColor: "muted",
    secondarySpacing: 3,
    secondaryCase: "none"
  },
  // Legacy / pruned time styles kept for backwards-compat:
  {
    id: "digital-seconds",
    category: "time",
    name: "w/ Seconds",
    family: "JetBrainsMono NF",
    weight: "Normal",
    italic: false,
    primaryFormat: "HH:mm:ss",
    primarySize: 36,
    primaryColor: "strong",
    primarySpacing: 1,
    secondaryFormat: "AP",
    secondarySize: 12,
    secondaryColor: "accent",
    secondarySpacing: 3,
    secondaryCase: "none",
    hiddenFromPanel: true
  },
  {
    id: "digital-compact",
    category: "time",
    name: "Compact",
    family: "JetBrainsMono NF",
    weight: "Light",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 32,
    primaryColor: "accent",
    primarySpacing: 0,
    secondaryFormat: "dddd",
    secondarySize: 11,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "time-full",
    category: "time",
    name: "Full Time",
    family: "Liberation Mono",
    weight: "Normal",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 48,
    primaryColor: "strong",
    primarySpacing: 3,
    secondaryFormat: "ss 'sec'",
    secondarySize: 13,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "none",
    hiddenFromPanel: true
  },

  // ---- DATE category
  {
    id: "big-day",
    category: "date",
    name: "Editorial Day",
    family: "Liberation Serif",
    weight: "Bold",
    italic: false,
    primaryFormat: "dddd",
    primarySize: 44,
    primaryColor: "strong",
    primarySpacing: 0,
    secondaryFormat: "d MMMM",
    secondarySize: 13,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "upper"
  },
  {
    id: "day-number",
    category: "date",
    name: "Day Number",
    family: "",
    weight: "Bold",
    italic: false,
    primaryFormat: "d",
    primarySize: 52,
    primaryColor: "accent",
    primarySpacing: 0,
    secondaryFormat: "dddd",
    secondarySize: 12,
    secondaryColor: "muted",
    secondarySpacing: 3,
    secondaryCase: "upper"
  },
  {
    id: "weekday",
    category: "date",
    name: "Italic Weekday",
    family: "Liberation Serif",
    weight: "Normal",
    italic: true,
    primaryFormat: "dddd",
    primarySize: 28,
    primaryColor: "accent",
    primarySpacing: 0,
    secondaryFormat: "d MMMM yyyy",
    secondarySize: 12,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "upper"
  },
  // Legacy / pruned date styles kept for backwards-compat:
  {
    id: "full-date",
    category: "date",
    name: "Full Date",
    family: "Liberation Serif",
    weight: "Normal",
    italic: false,
    primaryFormat: "dddd MMMM d",
    primarySize: 24,
    primaryColor: "strong",
    primarySpacing: 0,
    secondaryFormat: "yyyy",
    secondarySize: 12,
    secondaryColor: "muted",
    secondarySpacing: 3,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "short",
    category: "date",
    name: "Short",
    family: "",
    weight: "Normal",
    italic: false,
    primaryFormat: "ddd d MMM",
    primarySize: 20,
    primaryColor: "strong",
    primarySpacing: 0,
    secondaryFormat: "yyyy",
    secondarySize: 11,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "month",
    category: "date",
    name: "Month",
    family: "Nimbus Roman",
    weight: "Light",
    italic: true,
    primaryFormat: "MMMM",
    primarySize: 34,
    primaryColor: "strong",
    primarySpacing: 0,
    secondaryFormat: "d",
    secondarySize: 22,
    secondaryColor: "accent",
    secondarySpacing: 0,
    secondaryCase: "none",
    hiddenFromPanel: true
  },
  {
    id: "iso-date",
    category: "date",
    name: "ISO",
    family: "JetBrainsMono NF",
    weight: "Normal",
    italic: false,
    primaryFormat: "yyyy-MM-dd",
    primarySize: 22,
    primaryColor: "strong",
    primarySpacing: 1,
    secondaryFormat: "dddd",
    secondarySize: 12,
    secondaryColor: "accent",
    secondarySpacing: 2,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "week-number",
    category: "date",
    name: "Week #",
    family: "Liberation Sans",
    weight: "Bold",
    italic: false,
    primaryFormat: "dd",
    primarySize: 40,
    primaryColor: "strong",
    primarySpacing: 0,
    secondaryFormat: "'week' ww",
    secondarySize: 12,
    secondaryColor: "accent",
    secondarySpacing: 2,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },

  // ---- MISC category (legacy compat)
  {
    id: "elegant-time",
    category: "time",
    name: "Elegant",
    family: "Nimbus Roman",
    weight: "Normal",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 42,
    primaryColor: "strong",
    primarySpacing: 4,
    secondaryFormat: "dddd, d MMMM",
    secondarySize: 12,
    secondaryColor: "muted",
    secondarySpacing: 2,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "mono-status",
    category: "time",
    name: "Status",
    family: "iA Writer Duo S",
    weight: "Normal",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 28,
    primaryColor: "accent",
    primarySpacing: 0,
    secondaryFormat: "d MMM  yyyy",
    secondarySize: 11,
    secondaryColor: "muted",
    secondarySpacing: 1,
    secondaryCase: "upper",
    hiddenFromPanel: true
  },
  {
    id: "bold-clock",
    category: "time",
    name: "Bold Clock",
    family: "Liberation Sans",
    weight: "Bold",
    italic: false,
    primaryFormat: "HH:mm",
    primarySize: 50,
    primaryColor: "accent",
    primarySpacing: -1,
    secondaryFormat: "dddd",
    secondarySize: 14,
    secondaryColor: "strong",
    secondarySpacing: 4,
    secondaryCase: "upper",
    hiddenFromPanel: true
  }
]

// ---- specialized components (analog, flip, cyber, progress, music, visualizer, volume) ----

var WIDGET_STYLES = [
  // Clocks (Category: time)
  {
    id: "analog-slick",
    category: "time",
    name: "Slick Minimal",
    kind: "analog",
    variant: "slick"
  },
  {
    id: "clock-flip",
    category: "time",
    name: "Flip Clock",
    kind: "flip"
  },
  {
    id: "clock-cyber",
    category: "time",
    name: "Cyber HUD",
    kind: "cyber"
  },
  {
    id: "analog-station",
    category: "time",
    name: "Station Clock",
    kind: "analog",
    variant: "station"
  },
  // Legacy analog styles:
  {
    id: "analog-minimal",
    category: "time",
    name: "Nordic Minimal",
    kind: "analog",
    variant: "minimal",
    hiddenFromPanel: true
  },
  {
    id: "analog-classic",
    category: "time",
    name: "Classic Roman",
    kind: "analog",
    variant: "classic",
    hiddenFromPanel: true
  },
  {
    id: "analog-cyber",
    category: "time",
    name: "Cyber Dial",
    kind: "analog",
    variant: "cyber",
    hiddenFromPanel: true
  },
  {
    id: "analog-clock",
    category: "time",
    name: "Station Clock",
    kind: "analog",
    variant: "station",
    hiddenFromPanel: true
  },

  // Date (Category: date)
  {
    id: "date-progress",
    category: "date",
    name: "Day Progress",
    kind: "progress"
  },

  // Media (Category: media)
  {
    id: "music-cassette",
    category: "media",
    name: "Retro Cassette",
    kind: "music",
    variant: "cassette"
  },
  {
    id: "music-vinyl",
    category: "media",
    name: "Vinyl Turntable",
    kind: "music",
    variant: "vinyl"
  },
  // Boring/normal media styles hidden from panel (retained for backward compatibility):
  {
    id: "music-card",
    category: "media",
    name: "Glassmorphic Card",
    kind: "music",
    variant: "card",
    hiddenFromPanel: true
  },
  {
    id: "music-compact",
    category: "media",
    name: "Floating Island",
    kind: "music",
    variant: "compact",
    hiddenFromPanel: true
  },
  {
    id: "volume",
    category: "media",
    name: "Volume Level",
    kind: "volume",
    hiddenFromPanel: true
  },
  // Legacy media aliases:
  {
    id: "music",
    category: "media",
    name: "Glassmorphic Card",
    kind: "music",
    variant: "card",
    hiddenFromPanel: true
  },

  // Audio Visualizers (Category: visualizer)
  {
    id: "visualizer-bars",
    category: "visualizer",
    name: "Bottom Spectrum Bars",
    desc: "16-band rising spectrum bars with floating peak dots",
    kind: "visualizer",
    variant: "bars"
  },
  {
    id: "visualizer-dots",
    category: "visualizer",
    name: "LED Rack Equalizer",
    desc: "16x8 responsive dot matrix frequency grid",
    kind: "visualizer",
    variant: "dots"
  },
  {
    id: "visualizer-radial",
    category: "visualizer",
    name: "Cyber Pulse Ring",
    desc: "360° circular audio pulse with rotating frequency rays",
    kind: "visualizer",
    variant: "radial"
  },
  {
    id: "visualizer-wave",
    category: "visualizer",
    name: "Oscilloscope Wave",
    desc: "Continuous organic oscilloscope waveform",
    kind: "visualizer",
    variant: "wave"
  },
  // Boring/vintage visualizer styles hidden from panel (retained for backward compatibility):
  {
    id: "visualizer-vumeter",
    category: "visualizer",
    name: "Vintage VU Meter",
    kind: "visualizer",
    variant: "vumeter",
    hiddenFromPanel: true
  },
  {
    id: "visualizer-mirror",
    category: "visualizer",
    name: "Symmetric Spectrum",
    kind: "visualizer",
    variant: "mirror",
    hiddenFromPanel: true
  }
]

// ---- lookups ---------------------------------------------------------------

var ALL_STYLES = TEXT_STYLES.concat(WIDGET_STYLES)

function styleFor(id) {
  for (var i = 0; i < ALL_STYLES.length; i++) {
    if (ALL_STYLES[i].id === id) return ALL_STYLES[i]
  }
  return ALL_STYLES[0]
}

function textStylesFor(catId) {
  var out = []
  for (var i = 0; i < TEXT_STYLES.length; i++) {
    if (!catId || TEXT_STYLES[i].category === catId) out.push(TEXT_STYLES[i])
  }
  return out
}

function widgetsFor(catId) {
  var out = []
  for (var i = 0; i < WIDGET_STYLES.length; i++) {
    if (WIDGET_STYLES[i].hiddenFromPanel) continue
    if (!catId || WIDGET_STYLES[i].category === catId) out.push(WIDGET_STYLES[i])
  }
  return out
}

function allFor(catId) {
  var out = []
  for (var i = 0; i < ALL_STYLES.length; i++) {
    if (ALL_STYLES[i].hiddenFromPanel) continue
    if (!catId || ALL_STYLES[i].category === catId) out.push(ALL_STYLES[i])
  }
  return out
}

function styleIds() {
  var ids = []
  for (var i = 0; i < ALL_STYLES.length; i++) ids.push(ALL_STYLES[i].id)
  return ids
}

function categories() { return CATEGORIES }

// ---- formatting -----------------------------------------------------------

function formatDate(date, format) {
  return Qt.formatDateTime(date || new Date(), format || "")
}

function formatDateTime(date, format) {
  return Qt.formatDateTime(date || new Date(), format || "")
}

function formatTime(date, format) {
  return Qt.formatTime(date || new Date(), format || "")
}

function previewScale(style) {
  return Math.min(1, 26 / (style.primarySize || 26))
}

function barLabel(date) {
  return String(formatDate(date, "d"))
}

function barTooltip(date) {
  return formatDate(date, "dddd, d MMMM yyyy")
}
