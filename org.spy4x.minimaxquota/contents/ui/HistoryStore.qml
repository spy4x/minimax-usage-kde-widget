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

  // Separate slot for the manually-triggered snapshot. Lives in its own
  // category so it never collides with the live data and survives a
  // "Clear history now" action.
  Settings {
    id: backupSettings
    category: "HistoryBackup"
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

  // ---- User-facing actions exposed to ConfigGeneral ----

  // Snapshot the entire blob (all namespaces) to the backup slot. Returns
  // an object with `{ ok, samples }` for the UI to display. No-op when
  // no data has ever been written.
  function backup() {
    if (!settings.data || settings.data.length === 0) {
      return { ok: false, error: "Nothing to backup yet (no history on disk)." }
    }
    try {
      backupSettings.data = settings.data
      const obj = readBlob()
      let samples = 0
      for (const k in obj) {
        const slice = obj[k]
        if (slice && Array.isArray(slice.interval)) samples += slice.interval.length
        if (slice && Array.isArray(slice.weekly)) samples += slice.weekly.length
      }
      return { ok: true, samples: samples }
    } catch (e) {
      return { ok: false, error: String(e) }
    }
  }

  // True iff a non-empty backup is stored.
  readonly property bool hasBackup: backupSettings.data && backupSettings.data.length > 0

  // Restore the backup over the live data. Returns `{ ok, samples }` or
  // `{ ok: false, error }`. Clears the backup slot on success so a
  // second click can't silently re-overwrite newer data.
  function restoreBackup() {
    const raw = backupSettings.data || ""
    if (raw.length === 0) return { ok: false, error: "No backup to restore." }
    try {
      const parsed = JSON.parse(raw)
      if (!parsed || typeof parsed !== "object") {
        return { ok: false, error: "Backup is corrupted." }
      }
      settings.data = raw
      backupSettings.data = ""
      load()
      // Reload from the main slot and repopulate the current namespace.
      let samples = 0
      if (interval && Array.isArray(interval)) samples += interval.length
      if (weekly && Array.isArray(weekly)) samples += weekly.length
      return { ok: true, samples: samples }
    } catch (e) {
      return { ok: false, error: String(e) }
    }
  }

  // Fill the current namespace with synthetic sawtooth data spanning the
  // retention window. Each quota window (5h for interval, 7d for weekly)
  // gets a deterministic but varying endRemaining so multiple bars are
  // visible after downsampling. Existing data for this namespace is
  // overwritten — the caller is expected to have called backup() first.
  function seedFakeHistory(intervalDays, weeklyDays) {
    const now = Date.now()
    const sampleMs = 5 * 60 * 1000
    const fiveHours = 5 * 60 * 60 * 1000
    const sevenDays = 7 * 24 * 60 * 60 * 1000

    interval = []
    const intStart = now - Math.max(1, intervalDays || 7) * 86400000
    for (let t = intStart; t <= now; t += sampleMs) {
      const wIdx = Math.floor(t / fiveHours)
      const wStart = wIdx * fiveHours
      const pos = (t - wStart) / fiveHours  // 0..1
      // endRemaining: 20..79 — different per window so bars vary.
      const endR = 20 + ((wIdx * 7919) % 60)
      const base = 100 - pos * (100 - endR)
      // Small per-sample noise so buckets don't all align to the same height.
      const noise = (((wIdx * 31) ^ Math.floor(t / sampleMs)) % 7) - 3
      const r = Math.max(0, Math.min(100, Math.round(base + noise)))
      interval.push({ ts: t, p: r })
    }

    weekly = []
    const wkStart = now - Math.max(1, weeklyDays || 90) * 86400000
    for (let t = wkStart; t <= now; t += sampleMs) {
      const wIdx = Math.floor(t / sevenDays)
      const wStart = wIdx * sevenDays
      const pos = (t - wStart) / sevenDays
      const endR = 30 + ((wIdx * 6151) % 50)
      const base = 100 - pos * (100 - endR)
      const noise = (((wIdx * 47) ^ Math.floor(t / sampleMs)) % 7) - 3
      const r = Math.max(0, Math.min(100, Math.round(base + noise)))
      weekly.push({ ts: t, p: r })
    }

    dirtyCount++
    // Persist immediately so the new data is on disk before the next
    // widget load (otherwise a restart would lose it).
    flush(intervalDays, weeklyDays)
    return {
      ok: true,
      intervalSamples: interval.length,
      weeklySamples: weekly.length,
    }
  }
}
