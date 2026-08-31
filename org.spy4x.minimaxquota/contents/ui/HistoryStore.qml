import QtCore
import QtQuick

// Persistence layer for quota usage history, namespaced per subscription
// key. Storing everything in a single JSON blob (category "History", key
// `data`) lets multiple widgets coexist without mixing data, and lets
// widget removal + re-add keep the history intact as long as the API key
// is the same.
//
// Shape:
//   data = "{
//     \"<hash>\": { \"interval\": [...], \"weekly\": [...] },
//     ...
//   }"
//
// On load, legacy flat shapes (`{ interval, weekly }` at the top level)
// are migrated to the current namespace so users coming from the previous
// version don't lose their data.
//
// Implementation note: root type is `Item` (not `QtObject`) so that the
// inner Settings child can be assigned via the default `data` property.
// visible:false + zero size keeps this instance off the layout/screen.
Item {
  id: store
  visible: false
  width: 0
  height: 0

  // Subscription key, bound by the parent. Empty when no key is configured.
  property string apiKey: ""

  // djb2 hash of apiKey, base36-encoded. Used as the namespace inside the
  // data blob. Empty string when no key is set — store stays empty in that
  // case, samples are dropped while no key is configured.
  readonly property string namespace: {
    if (!apiKey || apiKey.length === 0) return ""
    let h = 5381
    for (let i = 0; i < apiKey.length; i++) {
      h = ((h << 5) + h + apiKey.charCodeAt(i)) | 0
    }
    return Math.abs(h).toString(36)
  }

  onNamespaceChanged: load()

  Settings {
    id: settings
    category: "History"
    property string data: ""
  }

  // In-memory mirror of the current namespace's samples.
  property var interval: []
  property var weekly: []
  // Number of unsaved appends since last flush.
  property int dirtyCount: 0

  function load() {
    interval = []
    weekly = []
    const raw = settings.data || ""
    if (raw.length === 0) return
    let obj
    try {
      obj = JSON.parse(raw)
    } catch (e) {
      return  // corrupt JSON — start fresh
    }
    // Legacy single-namespace shape: top-level { interval, weekly }.
    // Migrate to the current namespace so old data isn't lost. When no
    // namespace is configured yet (empty apiKey), leave the legacy fields
    // in place — they'll migrate on the next load() once a key is set.
    if (Array.isArray(obj.interval) || Array.isArray(obj.weekly)) {
      if (!store.namespace) return
      obj[store.namespace] = {
        interval: Array.isArray(obj.interval) ? obj.interval : [],
        weekly: Array.isArray(obj.weekly) ? obj.weekly : []
      }
      delete obj.interval
      delete obj.weekly
      try {
        settings.data = JSON.stringify(obj)
      } catch (e) { /* ignore */ }
    }
    const slice = obj[store.namespace]
    if (slice && typeof slice === "object") {
      interval = Array.isArray(slice.interval) ? slice.interval : []
      weekly = Array.isArray(slice.weekly) ? slice.weekly : []
    }
  }

  // Append one sample per window. Pass null/undefined to skip a window for
  // this tick. No-op when no namespace is configured (no key set).
  function append(intervalP, weeklyP) {
    if (!store.namespace) return
    const now = Date.now()
    if (intervalP !== null && intervalP !== undefined && !isNaN(intervalP)) {
      interval = interval.concat([{ ts: now, p: intervalP }])
      dirtyCount++
    }
    if (weeklyP !== null && weeklyP !== undefined && !isNaN(weeklyP)) {
      weekly = weekly.concat([{ ts: now, p: weeklyP }])
      dirtyCount++
    }
  }

  // Drop entries older than the retention window (in days).
  function prune(intervalDays, weeklyDays) {
    const now = Date.now()
    const intLimit = Math.max(1, intervalDays || 7) * 86400000
    const wkLimit = Math.max(1, weeklyDays || 90) * 86400000
    interval = interval.filter(e => now - e.ts <= intLimit)
    weekly = weekly.filter(e => now - e.ts <= wkLimit)
  }

  // Persist to disk if dirty. Reads the current full blob, updates this
  // namespace's slice, writes it back. Other namespaces are preserved.
  function flush(intervalDays, weeklyDays) {
    if (dirtyCount === 0) return
    if (!store.namespace) { dirtyCount = 0; return }
    prune(intervalDays, weeklyDays)
    try {
      const obj = readBlob()
      obj[store.namespace] = { interval: store.interval, weekly: store.weekly }
      settings.data = JSON.stringify(obj)
      dirtyCount = 0
    } catch (e) {
      // keep dirty for next try
    }
  }

  // Clear stored history for the CURRENT namespace only. Old namespaces
  // (different API keys) are left untouched in the blob.
  function clearAll(intervalDays, weeklyDays) {
    interval = []
    weekly = []
    dirtyCount = 0
    try {
      const obj = readBlob()
      delete obj[store.namespace]
      settings.data = JSON.stringify(obj)
    } catch (e) { /* ignore */ }
    prune(intervalDays, weeklyDays)
  }

  function readBlob() {
    const raw = settings.data || ""
    if (raw.length === 0) return {}
    try {
      const parsed = JSON.parse(raw)
      return (parsed && typeof parsed === "object") ? parsed : {}
    } catch (e) {
      return {}
    }
  }
}
