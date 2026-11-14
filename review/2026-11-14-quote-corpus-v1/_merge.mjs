#!/usr/bin/env node
// Merge the 480-quote v1 sample with the 960-quote expansion into 1440.
// Two passes: the reviewed 480 keep their slots, expansion fills each theme to 240.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const dir = path.dirname(fileURLToPath(import.meta.url));
const read = (name) => JSON.parse(fs.readFileSync(path.join(dir, name), "utf8"));
const TARGET = 240;
const THEMES = [
  ["XS", "修身自省"],
  ["CS", "处世智慧"],
  ["XJ", "心境审美"],
  ["DX", "读书学习"],
  ["LZ", "励志进取"],
  ["GJ", "家国天下"],
];

const base = read("quotes.sample.json");
const expansion = read("_expansion.json");

if (!fs.existsSync(path.join(dir, "quotes.v1-480.json"))) {
  fs.writeFileSync(path.join(dir, "quotes.v1-480.json"), JSON.stringify(base, null, 1), "utf8");
}
const source480 = read("quotes.v1-480.json");
if (source480.length !== 480) throw new Error("v1 snapshot must be 480, got " + source480.length);

const norm = (s) => s.replace(/[\s，。；：！？、“”‘’《》·,.!?;:"'()（）—-]/g, "");
const seen = new Set();
const byTheme = new Map();

for (const [prefix] of THEMES) {
  const existing = source480.filter((item) => item.id.startsWith(prefix + "-"));
  if (existing.length !== 80) throw new Error(prefix + " base expected 80, got " + existing.length);
  byTheme.set(prefix, existing.map((item) => {
    const key = norm(item.text);
    if (seen.has(key)) throw new Error("v1 duplicate: " + item.text);
    seen.add(key);
    return { text: item.text, source: item.source, locator: item.locator, tone: item.tone };
  }));
}

const rows = [];
for (const [prefix, theme] of THEMES) {
  const merged = byTheme.get(prefix);
  const pool = [...(expansion[prefix] || []), ...(expansion["reserve" + prefix] || []), ...(expansion.reserveAny || [])];
  let skipped = 0;
  for (const [text, source, locator, tone] of pool) {
    if (merged.length >= TARGET) break;
    const key = norm(text);
    if (seen.has(key)) { skipped += 1; continue; }
    for (const value of [text, source, locator, tone]) {
      if (!String(value ?? "").trim()) throw new Error(prefix + " empty field near " + text);
    }
    seen.add(key);
    merged.push({ text, source, locator, tone });
  }
  if (merged.length !== TARGET) throw new Error(prefix + " expected " + TARGET + ", got " + merged.length + " (skipped " + skipped + ")");
  merged.forEach((item, index) => {
    rows.push({
      id: prefix + "-" + String(index + 1).padStart(3, "0"),
      theme,
      text: item.text,
      source: item.source,
      locator: item.locator,
      tone: item.tone,
      status: "pending",
    });
  });
  console.log(prefix + ": " + merged.length + " quotes, skipped " + skipped + " duplicates");
}

if (rows.length !== 1440) throw new Error("expected 1440 rows, got " + rows.length);
if (new Set(rows.map((r) => r.id)).size !== rows.length) throw new Error("duplicate ids");

fs.writeFileSync(path.join(dir, "quotes.sample.json"), JSON.stringify(rows, null, 1), "utf8");
fs.writeFileSync(
  path.join(dir, "quotes.tsv"),
  rows.map((r) => [r.id, r.theme, r.text, r.source, r.locator, r.tone].join("\t")).join("\n") + "\n",
  "utf8",
);
fs.writeFileSync(
  path.join(dir, "_corpus.pipe"),
  rows.map((r) => [r.id, r.theme, r.text, r.source, r.locator, r.tone].join("|")).join("\n") + "\n",
  "utf8",
);
console.log("OK " + rows.length + " quotes, " + TARGET + " per theme");
