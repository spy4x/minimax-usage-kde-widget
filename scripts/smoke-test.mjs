#!/usr/bin/env node
// Standalone smoke test for the API response parsing and formatting logic
// used by the QML plasmoid. Lets us validate the JS logic without KDE.
//
// Usage: node scripts/smoke-test.mjs
//
// Mirrors the JS in contents/ui/*.qml exactly so behavior matches.

const sample = {
  base_resp: { status_code: 0, status_msg: "success" },
  model_remains: [
    {
      model_name: "general",
      start_time: 1787547600000,
      end_time: 1787565600000,
      remains_time: 10771629,
      current_interval_total_count: 0,
      current_interval_usage_count: 0,
      current_interval_remaining_percent: 99,
      current_weekly_total_count: 0,
      current_weekly_usage_count: 0,
      weekly_remains_time: 579571629,
      current_weekly_remaining_percent: 99,
    },
    {
      model_name: "video",
      current_interval_remaining_percent: 100,
      current_weekly_remaining_percent: 100,
    },
  ],
};

function parseResponse(doc) {
  if (doc.base_resp && doc.base_resp.status_code !== 0) {
    return { error: "API error: " + doc.base_resp.status_msg };
  }
  const models = doc.model_remains || [];
  let general = null;
  for (const m of models) {
    if (m.model_name === "general") {
      general = m;
      break;
    }
  }
  if (!general) return { error: "No 'general' model entry in API response" };
  return {
    intervalData: {
      remainingPercent: general.current_interval_remaining_percent,
      resetMs: general.remains_time,
    },
    weeklyData: {
      remainingPercent: general.current_weekly_remaining_percent,
      resetMs: general.weekly_remains_time,
    },
  };
}

function formatDuration(ms) {
  if (ms === null || ms === undefined || isNaN(ms) || ms < 0) return "—";
  const totalSec = Math.floor(ms / 1000);
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const minutes = Math.floor((totalSec % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours} hr ${minutes} min`;
  return `${minutes} min`;
}

function usedFromRemaining(rp) {
  if (rp === null || rp === undefined || isNaN(rp)) return 0;
  return Math.max(0, Math.min(100, 100 - rp));
}

// Mirror of HistoryStore.qml logic (Node test target).
function append(arr, p) {
  return arr.concat([{ ts: Date.now(), p }]);
}

function prune(arr, retentionDays) {
  const limit = Math.max(1, retentionDays) * 86400000;
  // Use a synthetic "now" for testability — pass via parameter.
  const now = arguments[2] !== undefined ? arguments[2] : Date.now();
  return arr.filter(e => now - e.ts <= limit);
}

function downsample(points, maxBars) {
  if (points.length === 0) return [];
  if (points.length <= maxBars) return points;
  const bucket = points.length / maxBars;
  const out = [];
  for (let i = 0; i < maxBars; i++) {
    const start = Math.floor(i * bucket);
    const end = Math.min(points.length, Math.floor((i + 1) * bucket));
    if (start >= end) continue;
    let minV = 100, maxV = 0, sumP = 0, sumTs = 0, n = 0;
    for (let j = start; j < end; j++) {
      if (points[j].p < minV) minV = points[j].p;
      if (points[j].p > maxV) maxV = points[j].p;
      sumP += points[j].p;
      sumTs += points[j].ts;
      n++;
    }
    out.push({
      ts: n > 0 ? Math.floor(sumTs / n) : 0,
      p: n > 0 ? Math.floor(sumP / n) : 0,
      minP: minV,
      maxP: maxV,
    });
  }
  return out;
}

// Mirror of HistoryChart.qml fmtAxisDate — short spans show time, long spans show date.
// Node test uses Intl.DateTimeFormat (Qt.formatDateTime equivalent for our format strings).
function fmtAxisDate(ts, spanMs) {
  if (!ts) return "";
  const d = new Date(ts);
  if (spanMs <= 172800000) {
    // "MMM dd, HH:mm" — e.g. "Aug 19, 00:00"
    const month = d.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
    const dd = String(d.getUTCDate()).padStart(2, "0");
    const hh = String(d.getUTCHours()).padStart(2, "0");
    const mm = String(d.getUTCMinutes()).padStart(2, "0");
    return `${month} ${dd}, ${hh}:${mm}`;
  }
  // "MMM dd" — e.g. "Aug 19"
  const month = d.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${month} ${dd}`;
}

// Mirror of HistoryChart.qml barCenterX — center of a bar distributed inside
// `plotInnerWidth`, accounting for its width so edge bars never overflow.
function barCenterX(index, n, plotInnerWidth, width) {
  if (n <= 0 || plotInnerWidth <= 0) return 0;
  if (n === 1) return plotInnerWidth / 2;
  const left = index * ((plotInnerWidth - width) / (n - 1));
  return left + width / 2;
}

// Mirror of the bar delegate's inline width formula. Width stays below its
// slot, preventing overlap when 200 bars render in a narrow plot.
function barWidth(n, plotInnerWidth) {
  if (!n || n <= 0 || plotInnerWidth <= 0) return 0;
  return Math.min(8, plotInnerWidth / n * 0.75);
}

function barIndexAtX(mouseX, n, plotInnerWidth, width) {
  if (n <= 0 || plotInnerWidth <= 0) return -1;
  if (n === 1) return 0;
  const usableWidth = Math.max(0, plotInnerWidth - width);
  if (usableWidth === 0) return 0;
  const ratio = Math.max(0, Math.min(1, (mouseX - width / 2) / usableWidth));
  return Math.round(ratio * (n - 1));
}

// Mirror of HistoryChart.qml barWidth — capped narrow bar so dense data
// still has 1px gutters between bars.

// Mirror of HistoryStore.qml namespace() — djb2 hash of apiKey, base36.
function namespaceOf(apiKey) {
  if (!apiKey || apiKey.length === 0) return "";
  let h = 5381;
  for (let i = 0; i < apiKey.length; i++) {
    h = ((h << 5) + h + apiKey.charCodeAt(i)) | 0;
  }
  return Math.abs(h).toString(36);
}

// Mirror of HistoryStore.qml seedFakeHistory(). Deterministic sawtooth
// per (interval, weekly) window. Returns the same shape as the QML impl:
// { ok, intervalSamples, weeklySamples }.
function seedFakeHistory(intervalDays, weeklyDays, now = Date.now()) {
  const sampleMs = 5 * 60 * 1000;
  const fiveHours = 5 * 60 * 60 * 1000;
  const sevenDays = 7 * 24 * 60 * 60 * 1000;

  const interval = [];
  const intStart = now - Math.max(1, intervalDays || 7) * 86400000;
  for (let t = intStart; t <= now; t += sampleMs) {
    const wIdx = Math.floor(t / fiveHours);
    const wStart = wIdx * fiveHours;
    const pos = (t - wStart) / fiveHours;
    const endR = 20 + ((wIdx * 7919) % 60);
    const base = 100 - pos * (100 - endR);
    const noise = (((wIdx * 31) ^ Math.floor(t / sampleMs)) % 7) - 3;
    const r = Math.max(0, Math.min(100, Math.round(base + noise)));
    interval.push({ ts: t, p: r });
  }

  const weekly = [];
  const wkStart = now - Math.max(1, weeklyDays || 90) * 86400000;
  for (let t = wkStart; t <= now; t += sampleMs) {
    const wIdx = Math.floor(t / sevenDays);
    const wStart = wIdx * sevenDays;
    const pos = (t - wStart) / sevenDays;
    const endR = 30 + ((wIdx * 6151) % 50);
    const base = 100 - pos * (100 - endR);
    const noise = (((wIdx * 47) ^ Math.floor(t / sampleMs)) % 7) - 3;
    const r = Math.max(0, Math.min(100, Math.round(base + noise)));
    weekly.push({ ts: t, p: r });
  }

  return {
    ok: true,
    intervalSamples: interval.length,
    weeklySamples: weekly.length,
    interval,
    weekly,
  };
}

// Mirror of HistoryStore.qml backup/restore semantics. We don't have real
// Settings here, so we model the backup slot as a plain string.
function backupState(mainData) {
  return mainData || "";
}
function hasBackup(backupSlot) {
  return typeof backupSlot === "string" && backupSlot.length > 0;
}
function restoreBackup(backupSlot) {
  if (!hasBackup(backupSlot)) return { ok: false, error: "No backup to restore." };
  try {
    const parsed = JSON.parse(backupSlot);
    if (!parsed || typeof parsed !== "object") return { ok: false, error: "Backup is corrupted." };
    return { ok: true, blob: backupSlot, samples: countSamples(parsed) };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}
function countSamples(obj) {
  let n = 0;
  for (const k in obj) {
    const s = obj[k];
    if (s && Array.isArray(s.interval)) n += s.interval.length;
    if (s && Array.isArray(s.weekly)) n += s.weekly.length;
  }
  return n;
}

// Mirror of HistoryStore.qml load() — legacy single-namespace shape gets
// migrated to the current namespace so users coming from the previous
// version keep their data. When no namespace is configured yet (empty
// key), leave the legacy fields in place — they'll migrate once a key
// is configured and load() runs again.
function migrateLegacyBlob(raw, ns) {
  if (raw.length === 0) return { migrated: false, slice: null };
  let obj;
  try { obj = JSON.parse(raw); } catch (e) { return { migrated: false, slice: null }; }
  if (Array.isArray(obj.interval) || Array.isArray(obj.weekly)) {
    if (!ns) {
      // No namespace yet — keep legacy fields, will migrate on next load().
      return { migrated: false, slice: null, blob: obj };
    }
    obj[ns] = {
      interval: Array.isArray(obj.interval) ? obj.interval : [],
      weekly: Array.isArray(obj.weekly) ? obj.weekly : [],
    };
    delete obj.interval;
    delete obj.weekly;
    return { migrated: true, slice: obj[ns] || null, blob: obj };
  }
  return { migrated: false, slice: obj[ns] || null, blob: obj };
}

const tests = [
  {
    name: "parses general model entry",
    fn: () => {
      const r = parseResponse(sample);
      if (r.error) throw new Error(r.error);
      if (r.intervalData.remainingPercent !== 99) throw new Error("interval percent");
      if (r.weeklyData.remainingPercent !== 99) throw new Error("weekly percent");
      if (r.intervalData.resetMs !== 10771629) throw new Error("reset ms");
    },
  },
  {
    name: "formatDuration: 3 hr 2 min",
    fn: () => {
      const got = formatDuration((3 * 3600 + 2 * 60) * 1000);
      if (got !== "3 hr 2 min") throw new Error("got " + got);
    },
  },
  {
    name: "formatDuration: 6d 17h",
    fn: () => {
      const got = formatDuration((6 * 86400 + 17 * 3600) * 1000);
      if (got !== "6d 17h") throw new Error("got " + got);
    },
  },
  {
    name: "formatDuration: 45 min",
    fn: () => {
      const got = formatDuration(45 * 60 * 1000);
      if (got !== "45 min") throw new Error("got " + got);
    },
  },
  {
    name: "formatDuration: invalid inputs",
    fn: () => {
      if (formatDuration(null) !== "—") throw new Error("null");
      if (formatDuration(undefined) !== "—") throw new Error("undef");
      if (formatDuration(-5) !== "—") throw new Error("neg");
      if (formatDuration(Number.NaN) !== "—") throw new Error("NaN");
    },
  },
  {
    name: "usedFromRemaining",
    fn: () => {
      if (usedFromRemaining(99) !== 1) throw new Error("99 -> 1");
      if (usedFromRemaining(50) !== 50) throw new Error("50 -> 50");
      if (usedFromRemaining(0) !== 100) throw new Error("0 -> 100");
      if (usedFromRemaining(null) !== 0) throw new Error("null");
      if (usedFromRemaining(undefined) !== 0) throw new Error("undef");
      if (usedFromRemaining(120) !== 0) throw new Error("120 clamps to 0");
      if (usedFromRemaining(-10) !== 100) throw new Error("-10 clamps to 100");
    },
  },
  {
    name: "rejects error response (status_code != 0)",
    fn: () => {
      const r = parseResponse({
        base_resp: { status_code: 401, status_msg: "unauth" },
        model_remains: [],
      });
      if (!r.error) throw new Error("expected error");
    },
  },
  {
    name: "rejects missing 'general' model entry",
    fn: () => {
      const r = parseResponse({
        base_resp: { status_code: 0, status_msg: "ok" },
        model_remains: [{ model_name: "video" }],
      });
      if (!r.error) throw new Error("expected error");
    },
  },
  {
    name: "handles missing model_remains array",
    fn: () => {
      const r = parseResponse({ base_resp: { status_code: 0, status_msg: "ok" } });
      if (!r.error) throw new Error("expected error");
    },
  },
  // ---- history ----
  {
    name: "history append adds sample",
    fn: () => {
      const arr = [];
      const a1 = append(arr, 80);
      if (a1.length !== 1) throw new Error("length");
      if (a1[0].p !== 80) throw new Error("value");
      if (typeof a1[0].ts !== "number") throw new Error("ts");
    },
  },
  {
    name: "history prune drops entries older than retention",
    fn: () => {
      const now = 1_700_000_000_000;
      const arr = [
        { ts: now - 1 * 86400000, p: 90 },   // 1 day ago
        { ts: now - 5 * 86400000, p: 80 },   // 5 days ago
        { ts: now - 10 * 86400000, p: 70 },  // 10 days ago
      ];
      const kept = prune(arr, 7, now);
      if (kept.length !== 2) throw new Error("expected 2 kept, got " + kept.length);
      if (kept[0].p !== 90 || kept[1].p !== 80) throw new Error("wrong values kept");
    },
  },
  {
    name: "history prune keeps everything within retention",
    fn: () => {
      const now = 1_700_000_000_000;
      const arr = [
        { ts: now - 1 * 86400000, p: 90 },
        { ts: now - 3 * 86400000, p: 80 },
        { ts: now - 6 * 86400000, p: 70 },
      ];
      const kept = prune(arr, 7, now);
      if (kept.length !== 3) throw new Error("expected 3 kept, got " + kept.length);
    },
  },
  {
    name: "history prune clamps minimum retention to 1 day",
    fn: () => {
      const now = 1_700_000_000_000;
      const arr = [
        { ts: now - 0.5 * 86400000, p: 90 },
        { ts: now - 2 * 86400000, p: 80 },
      ];
      // Pass retentionDays=0 — should clamp to 1 day, dropping the 2-day entry.
      const kept = prune(arr, 0, now);
      if (kept.length !== 1) throw new Error("expected 1 kept, got " + kept.length);
    },
  },
  {
    name: "history downsample keeps all points when count <= maxBars",
    fn: () => {
      const arr = [
        { ts: 1000, p: 80 },
        { ts: 2000, p: 70 },
        { ts: 3000, p: 60 },
      ];
      const ds = downsample(arr, 10);
      if (ds.length !== 3) throw new Error("expected 3, got " + ds.length);
      if (ds[1].p !== 70) throw new Error("value");
    },
  },
  {
    name: "history downsample collapses to maxBars buckets with avg p",
    fn: () => {
      // 1000 points → 5 buckets of 200. Values cycle i % 100, so each bucket
      // contains two full cycles (0..99, 0..99). Average per bucket =
      // (sum of 0..99 twice) / 200 = 9900/200 = 49.5 → floor 49.
      const arr = [];
      for (let i = 0; i < 1000; i++) arr.push({ ts: i * 1000, p: i % 100 });
      const ds = downsample(arr, 5);
      if (ds.length !== 5) throw new Error("expected 5 buckets, got " + ds.length);
      if (ds[0].p !== 49) throw new Error("bucket 0 avg p (expected 49, got " + ds[0].p + ")");
      if (ds[0].minP !== 0) throw new Error("bucket 0 minP");
      if (ds[0].maxP !== 99) throw new Error("bucket 0 maxP (expected 99 from i=99)");
      if (ds[4].p !== 49) throw new Error("bucket 4 avg p (expected 49)");
      if (ds[4].maxP !== 99) throw new Error("bucket 4 maxP");
    },
  },
  {
    name: "history downsample records avg/min/max envelope per bucket",
    fn: () => {
      const arr = [
        { ts: 0, p: 80 },
        { ts: 1, p: 30 },   // min in bucket
        { ts: 2, p: 95 },   // max in bucket
        { ts: 3, p: 50 },
      ];
      // avg p = (80 + 30 + 95 + 50) / 4 = 255/4 = 63.75 → floor 63
      const ds = downsample(arr, 1);
      if (ds.length !== 1) throw new Error("expected 1 bucket");
      if (ds[0].p !== 63) throw new Error("avg p not used as bar value (got " + ds[0].p + ")");
      if (ds[0].minP !== 30) throw new Error("minP");
      if (ds[0].maxP !== 95) throw new Error("maxP");
    },
  },
  {
    name: "history downsample handles empty array",
    fn: () => {
      const ds = downsample([], 10);
      if (ds.length !== 0) throw new Error("expected empty");
    },
  },
  // ---- axis date formatting ----
  {
    name: "fmtAxisDate: short span includes time",
    fn: () => {
      // Aug 19, 00:00 UTC
      const ts = Date.UTC(2026, 7, 19, 0, 0);
      const out = fmtAxisDate(ts, 3600 * 1000);
      if (out !== "Aug 19, 00:00") throw new Error("got " + out);
    },
  },
  {
    name: "fmtAxisDate: long span omits time",
    fn: () => {
      const ts = Date.UTC(2026, 7, 19, 0, 0);
      const out = fmtAxisDate(ts, 7 * 86400 * 1000);
      if (out !== "Aug 19") throw new Error("got " + out);
    },
  },
  {
    name: "fmtAxisDate: zero ts returns empty",
    fn: () => {
      if (fmtAxisDate(0, 0) !== "") throw new Error("got " + fmtAxisDate(0, 0));
    },
  },
  // ---- bar positioning ----
  {
    name: "barWidth: sparse data caps at 8px wide",
    fn: () => {
      // 3 bars across 800px chart
      const w = barWidth(3, 800);
      if (w !== 8) throw new Error("got " + w);
    },
  },
  {
    name: "barWidth: dense data stays below its slot",
    fn: () => {
      // 200 bars across 800px → slot 4 → bar 3 (75% of slot)
      const w = barWidth(200, 800);
      if (w !== 3) throw new Error("got " + w);
    },
  },
  {
    name: "barWidth: dense narrow plots do not force overlap",
    fn: () => {
      if (Math.abs(barWidth(1000, 800) - 0.6) > Number.EPSILON) {
        throw new Error("got " + barWidth(1000, 800));
      }
      if (barWidth(0, 800) !== 0) throw new Error("got " + barWidth(0, 800));
      if (barWidth(1, 800) !== 8) throw new Error("got " + barWidth(1, 800));
    },
  },
  {
    name: "bar geometry: 200 bars fit narrow plot without overlap or overflow",
    fn: () => {
      const plotWidth = 328, n = 200;
      const width = barWidth(n, plotWidth);
      let previousRight = 0;
      for (let i = 0; i < n; i++) {
        const left = barCenterX(i, n, plotWidth, width) - width / 2;
        if (left < previousRight - Number.EPSILON) {
          throw new Error(`overlap at ${i}; left=${left} previousRight=${previousRight}`);
        }
        previousRight = left + width;
      }
      if (previousRight > plotWidth + Number.EPSILON) {
        throw new Error(`overflow; right=${previousRight} plotWidth=${plotWidth}`);
      }
    },
  },
  {
    name: "barCenterX: single sample centers bar",
    fn: () => {
      const x = barCenterX(0, 1, 800, 8);
      if (x !== 400) throw new Error("got " + x);
    },
  },
  {
    name: "barCenterX: n=0 returns 0 (degenerate)",
    fn: () => {
      const x = barCenterX(0, 0, 800, 0);
      if (x !== 0) throw new Error("got " + x);
    },
  },
  {
    name: "bar hover follows visual index despite irregular timestamps",
    fn: () => {
      const points = [
        { ts: 1 },
        { ts: 2 },
        { ts: 3 },
        { ts: 1000000 },
      ];
      const plotWidth = 328;
      const width = barWidth(points.length, plotWidth);
      const mouseX = barCenterX(2, points.length, plotWidth, width);
      const hovered = barIndexAtX(mouseX, points.length, plotWidth, width);
      if (hovered !== 2) throw new Error("got " + hovered);
    },
  },
  // ---- history namespace ----
  {
    name: "namespace: empty apiKey → empty namespace",
    fn: () => {
      if (namespaceOf("") !== "") throw new Error("empty key");
      if (namespaceOf(null) !== "") throw new Error("null key");
      if (namespaceOf(undefined) !== "") throw new Error("undef key");
    },
  },
  {
    name: "namespace: deterministic and non-empty for real keys",
    fn: () => {
      const a = namespaceOf("sk-cp-test-abc");
      const b = namespaceOf("sk-cp-test-abc");
      if (a === "") throw new Error("hash empty");
      if (a !== b) throw new Error("not deterministic");
    },
  },
  {
    name: "namespace: different keys → different namespaces",
    fn: () => {
      const a = namespaceOf("sk-cp-test-abc");
      const b = namespaceOf("sk-cp-test-xyz");
      if (a === b) throw new Error("collision");
    },
  },
  {
    name: "migrateLegacyBlob: legacy shape migrated to current namespace",
    fn: () => {
      const legacy = JSON.stringify({
        interval: [{ ts: 1, p: 80 }],
        weekly: [{ ts: 1, p: 70 }],
      });
      const ns = namespaceOf("sk-cp-test");
      const out = migrateLegacyBlob(legacy, ns);
      if (!out.migrated) throw new Error("not migrated");
      if (!out.slice) throw new Error("slice missing");
      if (out.slice.interval.length !== 1) throw new Error("interval not migrated");
      if (out.blob.interval !== undefined) throw new Error("legacy fields not stripped");
    },
  },
  {
    name: "migrateLegacyBlob: no namespace → no migration",
    fn: () => {
      // When no key is set yet, don't assign legacy data anywhere; it'll
      // migrate once a key is configured.
      const legacy = JSON.stringify({ interval: [{ ts: 1, p: 80 }] });
      const out = migrateLegacyBlob(legacy, "");
      if (out.migrated) throw new Error("should not migrate without ns");
    },
  },
  {
    name: "migrateLegacyBlob: already namespaced → no migration",
    fn: () => {
      const ns = namespaceOf("sk-cp-test");
      const blob = JSON.stringify({ [ns]: { interval: [{ ts: 1, p: 80 }] } });
      const out = migrateLegacyBlob(blob, ns);
      if (out.migrated) throw new Error("already migrated, but flagged as migrated");
      if (!out.slice || out.slice.interval.length !== 1) throw new Error("slice missing");
    },
  },
  // ---- seed / backup ----
  {
    name: "seedFakeHistory: interval sample count ≈ 7d at 5min sampling",
    fn: () => {
      const res = seedFakeHistory(7, 90);
      if (!res.ok) throw new Error("ok flag");
      // 7 days = 7 * 288 = 2016 samples (allow 1-2 sample boundary slack).
      if (res.intervalSamples < 2014 || res.intervalSamples > 2018) {
        throw new Error("intervalSamples out of range: " + res.intervalSamples);
      }
      // Weekly: 90 days = 90 / 7 = 12.86 windows × 2016 = ~25920
      if (res.weeklySamples < 25900 || res.weeklySamples > 25940) {
        throw new Error("weeklySamples out of range: " + res.weeklySamples);
      }
    },
  },
  {
    name: "seedFakeHistory: produces varying remaining values (multiple buckets visible)",
    fn: () => {
      const res = seedFakeHistory(7, 90);
      // Downsample to 200 buckets per window count and check that MOST
      // buckets have a bar (avg remaining < 100 → USED > 0 → visible).
      const dsI = downsample(res.interval, 200);
      const dsW = downsample(res.weekly, 200);
      const visibleI = dsI.filter(b => 100 - b.p > 0.5).length;
      const visibleW = dsW.filter(b => 100 - b.p > 0.5).length;
      // With sawtooth varying endRemaining per window, nearly every
      // bucket should be visible. Allow ≥ 90% to absorb edge cases.
      if (visibleI < dsI.length * 0.9) {
        throw new Error(`interval visible=${visibleI}/${dsI.length}`);
      }
      if (visibleW < dsW.length * 0.9) {
        throw new Error(`weekly visible=${visibleW}/${dsW.length}`);
      }
      // avg used for both should land somewhere reasonable (20-80%).
      const avgI = dsI.reduce((s, b) => s + (100 - b.p), 0) / dsI.length;
      const avgW = dsW.reduce((s, b) => s + (100 - b.p), 0) / dsW.length;
      if (avgI < 20 || avgI > 80) throw new Error("interval avg out of range: " + avgI);
      if (avgW < 20 || avgW > 80) throw new Error("weekly avg out of range: " + avgW);
    },
  },
  {
    name: "seedFakeHistory: deterministic for same timestamp seed",
    fn: () => {
      const fixed = 1700000000000;
      const a = seedFakeHistory(7, 90, fixed);
      const b = seedFakeHistory(7, 90, fixed);
      if (a.intervalSamples !== b.intervalSamples) throw new Error("length mismatch");
      if (a.interval[0].p !== b.interval[0].p) throw new Error("first sample mismatch");
      if (a.interval[a.intervalSamples - 1].p !== b.interval[a.intervalSamples - 1].p) {
        throw new Error("last sample mismatch");
      }
    },
  },
  {
    name: "seedFakeHistory: respects custom retention days",
    fn: () => {
      const res = seedFakeHistory(1, 7);
      // 1 day interval ≈ 288 samples
      if (res.intervalSamples < 286 || res.intervalSamples > 290) {
        throw new Error("1d interval count off: " + res.intervalSamples);
      }
      // 7d weekly ≈ 2016 samples
      if (res.weeklySamples < 2014 || res.weeklySamples > 2018) {
        throw new Error("7d weekly count off: " + res.weeklySamples);
      }
    },
  },
  {
    name: "backup/restore round-trip preserves blob shape",
    fn: () => {
      const ns = namespaceOf("sk-cp-test");
      const mainBlob = JSON.stringify({
        [ns]: {
          interval: [{ ts: 1, p: 80 }, { ts: 2, p: 70 }],
          weekly: [{ ts: 1, p: 90 }],
        },
      });
      const slot = backupState(mainBlob);
      if (!hasBackup(slot)) throw new Error("hasBackup false after backup");
      const res = restoreBackup(slot);
      if (!res.ok) throw new Error("restore failed: " + (res.error || ""));
      if (res.blob !== mainBlob) throw new Error("blob not preserved exactly");
    },
  },
  {
    name: "backup: empty main returns ok:false",
    fn: () => {
      const slot = backupState("");
      if (hasBackup(slot)) throw new Error("hasBackup true for empty");
      const res = restoreBackup(slot);
      if (res.ok) throw new Error("restore on empty should fail");
    },
  },
  {
    name: "restore: corrupt backup returns ok:false with error",
    fn: () => {
      const res = restoreBackup("{not json");
      if (res.ok) throw new Error("corrupt restore should fail");
      if (!res.error) throw new Error("error missing");
    },
  },
];

let pass = 0;
let fail = 0;
for (const t of tests) {
  try {
    t.fn();
    console.log(`✓ ${t.name}`);
    pass++;
  } catch (e) {
    console.log(`✗ ${t.name}: ${e.message}`);
    fail++;
  }
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
