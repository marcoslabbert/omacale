import QtQuick
import Quickshell
import "../.."

// Dragging a plugin widget between the three plugin pills (PluginPill), in
// the bar or along the top edge (PluginStrip). No Caelestia original: its
// bar has no user-arranged widgets. The drop is Omarchy's own layout edit,
// `omarchy bar move <id> --before/--after <neighbour>` (or `--section` into
// an empty section), so shell.json stays Omarchy's to write and the widget
// comes back in its new place from the layout like any other change.
//
// A slot's DragHandler (PluginPill) calls begin/move/end with points in this
// layer's coordinates; a press that never passes the drag threshold is left
// to the widget as a click.
Item {
  id: layer

  // The pills a widget can be dropped on, each with its `section`.
  property var pills: []

  property bool active: false
  property Item slot: null
  property Item fromPill: null
  property point pos: Qt.point(0, 0)
  // The pill under the pointer, and where in it the widget would land.
  property Item overPill: null
  property int overIndex: -1
  // Where the widget was picked up from, among the other slots of its pill.
  property int fromIndex: -1

  // The shown slots of a pill in bar order, the dragged one left out.
  function slotsOf(pill) {
    const out = []
    for (let i = 0; i < pill.rep.count; i++) {
      const s = pill.rep.itemAt(i)
      if (s && s.shown && s !== layer.slot) out.push(s)
    }
    return out
  }
  // The pill under the point, or else the nearest one along the bar within
  // a few cells: a drop in the gap beside a pill is meant for it.
  function pillAt(p) {
    let best = null, bestD = Tk.barInner * 3
    for (const pill of pills) {
      if (!pill || !pill.visible || pill.opacity <= 0) continue
      const q = layer.mapToItem(pill, p.x, p.y)
      const along = pill.vertical ? q.y : q.x
      const across = pill.vertical ? q.x : q.y
      const len = pill.vertical ? pill.height : pill.width
      const breadth = pill.vertical ? pill.width : pill.height
      if (across < -Tk.barInner || across > breadth + Tk.barInner) continue
      const d = along < 0 ? -along : along > len ? along - len : 0
      if (d < bestD) { best = pill; bestD = d }
    }
    return best
  }
  // How many of the pill's other slots sit before the point, along the pill.
  function indexIn(pill, p) {
    const list = slotsOf(pill)
    let n = 0
    for (const s of list) {
      const c = s.mapToItem(layer, s.width / 2, s.height / 2)
      if (pill.vertical ? c.y < p.y : c.x < p.x) n++
    }
    return n
  }

  function begin(slot, pill, p) {
    // The tooltip it was showing would stay behind, pointing at nothing.
    if (slot.host && typeof slot.host.clearTooltip === "function") slot.host.clearTooltip()
    layer.slot = slot
    fromPill = pill
    fromIndex = indexIn(pill, slot.mapToItem(layer, slot.width / 2, slot.height / 2))
    pos = p
    active = true
    move(p)
  }
  function move(p) {
    if (!active) return
    pos = p
    overPill = pillAt(p)
    overIndex = overPill ? indexIn(overPill, p) : -1
  }
  function end() {
    if (!active) return
    const s = slot, target = overPill, at = overIndex
    if (s && s.host && typeof s.host.clearTooltip === "function") s.host.clearTooltip()
    active = false
    slot = null
    overPill = null
    overIndex = -1
    if (!s || !target) return
    // Dropped back where it was: nothing to write.
    const same = target === fromPill && at === fromIndex
    fromPill = null
    if (same) return
    const others = slotsOf(target).filter(o => o !== s)
    const cmd = ["omarchy", "bar", "move", s.moduleName]
    if (at < others.length) cmd.push("--before", others[at].moduleName)
    else if (others.length > 0) cmd.push("--after", others[others.length - 1].moduleName)
    else cmd.push("--section", target.section)
    Quickshell.execDetached(cmd)
  }

  // The widget in hand: its name on a chip that follows the pointer.
  Rectangle {
    visible: layer.active && !!layer.slot
    z: 20
    x: Math.round(layer.pos.x - width / 2)
    y: Math.round(layer.pos.y - height / 2)
    implicitWidth: chipRow.implicitWidth + Tk.padding.medium * 2
    implicitHeight: Tk.barInner - Tk.padding.small
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: Colours.m3primaryContainer
    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Tk.spacing.small
      MIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "drag_indicator"
        color: Colours.m3onPrimaryContainer
      }
      MText {
        anchors.verticalCenter: parent.verticalCenter
        text: layer.slot ? layer.slot.displayName : ""
        color: Colours.m3onPrimaryContainer
        font.pointSize: Tk.label.large
        weight: Font.Medium
      }
    }
  }
}
