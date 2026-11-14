#!/usr/bin/env node
// Generate the offline Swift quote corpus from the reviewed sample JSON.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = path.join(root, "review", "2026-11-14-quote-corpus-v1", "quotes.sample.json");
const target = path.join(root, "ios", "WhaleAgent", "Models", "DailyQuoteCorpus.swift");
const items = JSON.parse(fs.readFileSync(source, "utf8"));

if (items.length !== 1440) throw new Error(`expected 1440 quotes, got ${items.length}`);
if (new Set(items.map((item) => item.id)).size !== items.length) throw new Error("duplicate quote ids");
for (const item of items) {
  for (const key of ["id", "theme", "text", "source", "locator", "tone"]) {
    if (!String(item[key] ?? "").trim()) throw new Error(`${item.id} missing ${key}`);
  }
}

const literal = (value) => String(value).replaceAll("\\", "\\\\").replaceAll('"', '\\"');
const lines = [
  "import Foundation",
  "",
  "/// 由 review/2026-11-14-quote-corpus-v1/quotes.sample.json 生成的离线金句语料。",
  "/// 共 1440 条，覆盖 6 个主题。请通过 tools/generate_daily_quote.mjs 重新生成，勿手工编辑。",
  "enum DailyQuoteCorpus {",
  "    struct Item: Equatable, Identifiable {",
  "        let id: String",
  "        let theme: String",
  "        let text: String",
  "        let source: String",
  "        let locator: String",
  "        let tone: String",
  "",
  '        var displayText: String { "\\(text)——\\(source)" }',
  "    }",
  "",
];

const groups = new Map();
for (const item of items) {
  const prefix = item.id.split("-")[0].toLowerCase();
  if (!groups.has(prefix)) groups.set(prefix, []);
  groups.get(prefix).push(item);
}
const order = ["xs", "cs", "xj", "dx", "lz", "gj"];
if (order.some((prefix) => !groups.has(prefix))) throw new Error("missing theme group");

for (const prefix of order) {
  const group = groups.get(prefix);
  if (group.length !== 240) throw new Error(`${prefix} expected 240 quotes, got ${group.length}`);
  lines.push(`    private static let ${prefix}Items: [Item] = [`);
  for (const item of group) {
    lines.push(
      `        Item(id: "${literal(item.id)}", theme: "${literal(item.theme)}", text: "${literal(item.text)}", ` +
        `source: "${literal(item.source)}", locator: "${literal(item.locator)}", tone: "${literal(item.tone)}"),`,
    );
  }
  lines.push("    ]", "");
}

lines.push(
  `    static let items: [Item] = ${order.map((prefix) => `${prefix}Items`).join(" + ")}`,
  "}",
  "",
);
fs.writeFileSync(target, lines.join("\n"), "utf8");
console.log(`wrote ${target} (${items.length} items)`);
