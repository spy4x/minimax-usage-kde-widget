import QtCore
import QtQuick

// Persistence layer for quota usage history.
// Stores two arrays of { ts: ms, p: 0..100 (remaining) } — one for the 5h
// window, one for the weekly window. Persistence is throttled by the caller
// via dirtyCount and the flush() method. Stored as a single JSON string
// in QtCore.Settings under category "History" so it lands in the same
// KConfig file the widget already uses but in its own group.
QtObject {
  id: store

  Settings {
    id: settings
    category: "History"
    property string data: ""
  }

  property var interval: []
  property var weekly: []
  // Number of unsaved appends since last flush.
  property int dirtyCount: 0

  function load() {
    try {
      const raw = settings.data || ""
      if (raw.length === 0) return
      const obj = JSON.parse(raw)
      interval = Array.isArray(obj.interval) ? obj.interval : []
      weekly = Array.isArray(obj.weekly) ? obj.weekly : []
    } catch (e) {
      // corrupt JSON — start fresh
    }
  }

  // Append one sample per window if a value is available. Pass null/undefined
  // to skip a window for this tick.
  function append(intervalP, weeklyP) {
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

  // Persist to disk if dirty. Caller passes retention days.
  function flush(intervalDays, weeklyDays) {
    if (dirtyCount === 0) return
    prune(intervalDays, weeklyDays)
    try {
      settings.data = JSON.stringify({ interval: interval, weekly: weekly })
      dirtyCount = 0
    } catch (e) {
      // ignore — keep dirty for next try
    }
  }

  // Clear all stored history. Immediately persists an empty state.
  function clearAll(intervalDays, weeklyDays) {
    interval = []
    weekly = []
    dirtyCount = 0
    try {
      settings.data = JSON.stringify({ interval: [], weekly: [] })
    } catch (e) { }
    prune(intervalDays, weeklyDays)
  }
}