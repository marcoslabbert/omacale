pragma Singleton
import QtQuick
import Quickshell
import ".."

// Omarchy's picker (omarchy-menu-select), drawn as launcher rows in the menu
// mode instead of by Omarchy's menu. No Caelestia original: its launcher has
// no pick-one mode. scripts/picker/omarchy-menu-select shadows Omarchy's on
// PATH for what Omacale runs (scripts/pick, MenuService.run) and hands its
// payload here, in the same shape Omarchy's menu plugin is summoned with:
// { prompt, options, selectionFile, doneFile }. The caller waits for
// doneFile to appear and reads the pick from selectionFile, where nothing
// means cancelled, so every request has to end in finish(), or its caller
// waits forever.
Singleton {
  id: root

  property var request: null
  readonly property bool active: request !== null
  readonly property string prompt: request ? String(request.prompt || "") : ""

  function begin(payload) {
    let p = null
    try { p = JSON.parse(payload) } catch (e) { return false }
    if (!p || !Array.isArray(p.options) || !p.selectionFile || !p.doneFile) return false
    // A new pick replaces one still waiting, which is then cancelled.
    cancel()
    request = p
    return true
  }

  function choose(row) { if (row) finish(row.value) }
  function cancel() { if (request) finish("") }

  function finish(value) {
    const r = request
    request = null
    if (!r) return
    Quickshell.execDetached(["sh", "-c", 'printf %s "$1" > "$2"; : > "$3"', "sh",
                             String(value), String(r.selectionFile), String(r.doneFile)])
  }

  // omarchy-menu-select's options: "<label>", "<glyph>\t<label>" or
  // "<glyph>\t<label>\t<subtext>". The glyph is shown, never returned; a
  // subtext comes back after the label, as the caller's key for same-named
  // rows. An option written as "<keys> → <action>" (the keybindings menu)
  // shows the action with its keys under it. Rows are menu rows, so the
  // launcher draws them as it draws the Omarchy menu.
  readonly property var allRows: {
    const opts = request ? request.options : []
    const out = []
    for (let i = 0; i < opts.length; i++) {
      const parts = String(opts[i]).split("\t")
      const glyph = parts.length > 1 ? parts[0] : ""
      const label = parts.length > 1 ? parts[1] : parts[0]
      const sub = parts.length > 2 ? parts[2] : ""
      const arrow = !sub ? label.indexOf(" → ") : -1
      out.push({
        itemId: "select:" + i,
        kind: "select",
        label: arrow >= 0 ? label.slice(arrow + 3).trim() : label,
        detail: arrow >= 0 ? label.slice(0, arrow).replace(/\s+/g, " ").trim() : sub,
        icon: glyph,
        disabled: false,
        value: sub ? label + "\t" + sub : label
      })
    }
    return out
  }

  function rows(query) {
    const q = String(query || "").trim().toLowerCase()
    if (!q) return allRows
    return allRows.filter(r => r.label.toLowerCase().indexOf(q) >= 0 || r.detail.toLowerCase().indexOf(q) >= 0)
  }
}
