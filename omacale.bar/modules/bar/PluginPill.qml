import QtQuick
import "../.."

// A Caelestia pill for 3rd-party bar widgets (installed in
// ~/.config/omarchy/plugins/), laid out like the status pill: same padding,
// same spacing, one status-icon cell per widget (BarWidgetSlot scales each
// widget's mark to the status icons' size). BarContent draws three, one per
// section of Omarchy's bar layout (left, center, right), each on a
// placeholder in the bar's column (`place`).
//
// Pinned widgets (Settings › Taskbar › Plugins) always show; the others
// wait behind a chevron that hovering expands, like the compact tray.
Rectangle {
  id: pill

  required property Item bar       // BarContent
  required property Item place     // its placeholder in the column
  required property var pluginsList
  // Its length along the bar, from the shared space budget (BarContent.pillCaps).
  property real capLen: listLen

  readonly property bool vertical: bar.vertical
  readonly property var unpinned: bar.cfg.plugins.unpinned
  readonly property alias rep: pluginRep
  readonly property alias flick: pluginFlick
  // The padding at each end of the list, along the bar.
  readonly property real endPad: Tk.padding.medium
  readonly property real listLen: vertical ? pluginCol.implicitHeight : pluginCol.implicitWidth
  readonly property bool anyShown: listLen - endPad * 2 > 0.5
  readonly property bool live: visible && anyShown
  property bool expanded: false
  onOverflowCountChanged: if (overflowCount === 0) expanded = false

  function collapseSoon() { if (expanded && !collapseTimer.running) collapseTimer.start() }
  function holdOpen() { collapseTimer.stop(); if (overflowCount > 0) expanded = true }
  function collapseLater() { if (expanded) collapseTimer.restart() }

  // Counted by hand: Repeater.itemAt is not a binding dependency, so every
  // slot asks for a recount when its size, content or pin changes.
  property int overflowCount: 0
  property real pinnedLen: 0
  function recount() { countTimer.restart() }
  Timer {
    id: countTimer
    interval: 0
    onTriggered: {
      let n = 0, h = 0
      for (let i = 0; i < pluginRep.count; i++) {
        const slot = pluginRep.itemAt(i)
        if (!slot || !slot.shown) continue
        if (slot.pinned) h += Math.round(slot.visualLen) + pluginCol.gapPx
        else n++
      }
      pill.overflowCount = n
      pill.pinnedLen = h
    }
  }
  // The pill's size along the bar with the overflow closed: what the budget plans for.
  readonly property real collapsedLen: overflowCount === 0 && pinnedLen === 0 ? 0
    : endPad * 2 + pinnedLen
      + (overflowCount > 0 ? (vertical ? overflowIcon.implicitHeight : overflowIcon.implicitWidth) : -pluginCol.gapPx)

  visible: bar.cfg.plugins.enabled !== false && pluginsList.length > 0
  opacity: anyShown ? 1 : 0
  x: bar.colItem.x + place.x
  y: bar.colItem.y + place.y
  // Scrolled down to a single cell, pinned widgets included, when even they
  // don't fit: the pill gives way before the clock and status icons do.
  readonly property real minLen: endPad * 2 + (vertical ? cellRef.implicitHeight : cellRef.implicitWidth)
  readonly property real sizeLen: anyShown ? Math.min(Math.max(minLen, capLen), listLen) : 0
  implicitWidth: vertical ? Tk.barInner : sizeLen
  implicitHeight: vertical ? sizeLen : Tk.barInner
  width: implicitWidth
  height: implicitHeight
  radius: (vertical ? width : height) / 2
  color: Colours.m3surfaceContainer
  clip: true

  Behavior on implicitHeight { enabled: pill.vertical; Anim {} }
  Behavior on implicitWidth { enabled: !pill.vertical; Anim {} }

  Timer {
    id: collapseTimer
    interval: 400
    onTriggered: pill.expanded = false
  }

  // A status icon's height, so a plugin cell matches the status pill's.
  MIcon { id: cellRef; visible: false; text: "extension" }

  // More widgets than fit scroll rather than being cut off.
  MFlickable {
    id: pluginFlick
    anchors.fill: parent
    contentWidth: pill.vertical ? width : pluginCol.implicitWidth
    contentHeight: pill.vertical ? pluginCol.implicitHeight : height
    interactive: pill.vertical ? contentHeight > height + 0.5 : contentWidth > width + 0.5

    Grid {
      id: pluginCol
      readonly property real gapPx: Tk.spacing.medium / 2
      width: pill.vertical ? parent.width : implicitWidth
      height: pill.vertical ? implicitHeight : parent.height
      columns: pill.vertical ? 1 : 1000
      topPadding: pill.vertical ? pill.endPad : 0
      bottomPadding: pill.vertical ? pill.endPad : 0
      leftPadding: pill.vertical ? 0 : pill.endPad
      rightPadding: pill.vertical ? 0 : pill.endPad
      spacing: gapPx

      Repeater {
        id: pluginRep
        model: pill.pluginsList

        BarWidgetSlot {
          required property var modelData
          pinned: pill.unpinned.indexOf(moduleName) < 0
          entry: modelData
          host: pill.bar.host
          vertical: pill.vertical
          cellLen: pill.vertical ? cellRef.implicitHeight : cellRef.implicitWidth
          collapsed: !pinned && !pill.expanded
          onShownChanged: pill.recount()
          onPinnedChanged: pill.recount()
          onVisualLenChanged: pill.recount()
          Component.onCompleted: pill.recount()
          Component.onDestruction: pill.recount()
        }
      }

      // Caelestia's tray chevron, for the widgets that aren't pinned.
      Item {
        width: pill.vertical ? parent.width : (pill.overflowCount > 0 ? overflowIcon.implicitWidth : 0)
        height: pill.vertical ? (pill.overflowCount > 0 ? overflowIcon.implicitHeight : 0) : parent.height
        MIcon {
          id: overflowIcon
          anchors.centerIn: parent
          visible: pill.overflowCount > 0
          text: pill.vertical ? "expand_less" : "chevron_left"
          size: Tk.iconSize.medium
          color: Colours.m3onSurfaceVariant
          rotation: pill.expanded ? 180 : 0
          Behavior on rotation { Anim {} }
        }
        MouseArea {
          anchors.fill: parent
          enabled: pill.overflowCount > 0
          cursorShape: Qt.PointingHandCursor
          onClicked: { collapseTimer.stop(); pill.expanded = !pill.expanded }
        }
      }
    }
  }

  // Omarchy's WidgetButton takes every wheel, so hosted widgets would eat
  // the scroll of an overfull pill. Wheel only: clicks and hover go through,
  // and while the pill fits the wheel is left to the widget.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: e => {
      if (!pluginFlick.interactive) { e.accepted = false; return }
      pill.bar.scrollBy(pluginFlick, e.angleDelta.y)
    }
  }
}
