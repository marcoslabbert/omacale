import QtQuick
import "../.."

// The plugin pills along the top edge, with the bar on a side (Settings ›
// Taskbar › Bar plugins › Along the top edge). No Caelestia original: its
// frame has one bar. Each section of Omarchy's bar layout sits where
// Omarchy's own top bar puts it -- left at the left end, center over the
// dashboard, right at the right end -- on the frame's top edge, which
// ScreenScope thickens to the pills' height. Left and right slide away until
// the pointer is on that edge (`revealed`); the center one stays.
Item {
  id: strip

  required property var host
  required property var scope
  // The pointer is on the top edge, from ScreenScope.
  property bool hovered: false

  // What PluginPill reads from whoever holds it.
  readonly property var cfg: Config.o.bar
  readonly property bool vertical: false
  function scrollBy(flick, dy) {
    const step = (Tk.barInner + Tk.spacing.medium / 2) * dy / 120
    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - step))
  }

  readonly property real pad: Tk.padding.large
  // Room for each pill, so they never overlap: the center one gets the
  // middle third, the others what is left beside it.
  readonly property real centreCap: Math.max(0, width / 3)
  readonly property real sideCap: Math.max(0, (width - pillC.width) / 2 - pad * 2)

  // Left and right stay out while a panel one of their widgets opened is up,
  // or their overflow is open: the pointer has left the edge for the panel.
  property bool held: false
  function anyOpen(pill) {
    for (let i = 0; i < pill.rep.count; i++) {
      const slot = pill.rep.itemAt(i)
      if (slot && slot.activeItem && slot.activeItem.opened === true) return true
    }
    return pill.expanded
  }
  // Repeater.itemAt is no binding dependency, so it is asked, not bound;
  // always, since a panel opened by its hotkey has to bring its pill out.
  Timer {
    interval: 300
    repeat: true
    running: true
    onTriggered: strip.held = strip.anyOpen(pillL) || strip.anyOpen(pillR)
  }
  readonly property bool revealed: hovered || held
  onHoveredChanged: if (hovered) held = false

  readonly property var pills: [pillL, pillC, pillR]

  component SidePill: PluginPill {
    bar: strip
    edge: "top"
    edgeInset: strip.y + strip.height
    capLen: strip.sideCap
    y: strip.revealed ? Math.round((strip.height - height) / 2) : -height - 2
    opacity: anyShown && strip.revealed ? 1 : 0
    Behavior on y { Anim { type: "fastSpatial" } }
    Behavior on opacity { Anim { type: "effects" } }
  }

  SidePill {
    id: pillL
    x: strip.pad
    pluginsList: strip.host.pluginsLeft || []
  }
  PluginPill {
    id: pillC
    bar: strip
    edge: "top"
    edgeInset: strip.y + strip.height
    capLen: strip.centreCap
    x: Math.round((strip.width - width) / 2)
    y: Math.round((strip.height - height) / 2)
    pluginsList: strip.host.pluginsCenter || []
  }
  SidePill {
    id: pillR
    x: Math.round(strip.width - width - strip.pad)
    pluginsList: strip.host.pluginsRight || []
  }
}
