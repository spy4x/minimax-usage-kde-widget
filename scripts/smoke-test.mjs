#!/usr/bin/env node
// Standalone smoke test for the API response parsing and formatting logic
// used by the QML plasmoid. Lets us validate the JS logic without KDE.
//
// Usage: node scripts/smoke-test.mjs
//
// Mirrors the JS in contents/ui/main.qml exactly so behavior matches.

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
      totalCount: general.current_interval_total_count,
      usedCount: general.current_interval_usage_count,
    },
    weeklyData: {
      remainingPercent: general.current_weekly_remaining_percent,
      resetMs: general.weekly_remains_time,
      totalCount: general.current_weekly_total_count,
      usedCount: general.current_weekly_usage_count,
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
    let minV = 100, maxV = 0, sumTs = 0, n = 0;
    for (let j = start; j < end; j++) {
      if (points[j].p < minV) minV = points[j].p;
      if (points[j].p > maxV) maxV = points[j].p;
      sumTs += points[j].ts;
      n++;
    }
    out.push({ ts: n > 0 ? Math.floor(sumTs / n) : 0, p: minV, minP: minV, maxP: maxV });
  }
  return out;
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
    name: "history downsample collapses to maxBars buckets with min",
    fn: () => {
      // 1000 points → 5 buckets of 200
      const arr = [];
      for (let i = 0; i < 1000; i++) arr.push({ ts: i * 1000, p: i % 100 });
      const ds = downsample(arr, 5);
      if (ds.length !== 5) throw new Error("expected 5 buckets, got " + ds.length);
      // Each bucket holds the min of its slice. Values cycle i % 100, so
      // every bucket's min is 0.
      if (ds[0].p !== 0) throw new Error("bucket 0 min");
      if (ds[0].maxP !== 99) throw new Error("bucket 0 max (expected 99 from i=99)");
      if (ds[4].p !== 0) throw new Error("bucket 4 min (expected 0)");
      if (ds[4].maxP !== 99) throw new Error("bucket 4 max");
    },
  },
  {
    name: "history downsample records min/max envelope per bucket",
    fn: () => {
      const arr = [
        { ts: 0, p: 80 },
        { ts: 1, p: 30 },   // min in bucket
        { ts: 2, p: 95 },   // max in bucket
        { ts: 3, p: 50 },
      ];
      const ds = downsample(arr, 1);
      if (ds.length !== 1) throw new Error("expected 1 bucket");
      if (ds[0].p !== 30) throw new Error("min not used as bar value");
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