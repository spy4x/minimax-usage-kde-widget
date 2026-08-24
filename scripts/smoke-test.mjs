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