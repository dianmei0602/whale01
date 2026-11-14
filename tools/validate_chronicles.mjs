#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dataPath = path.join(root, "ios", "ChineseChronicles", "Resources", "chronicles.v1.json");
const manifestPath = path.join(
  root,
  "ios",
  "ChineseChronicles",
  "Resources",
  "content-manifest.v1.json"
);
const checkOnly = process.argv.includes("--check");

const raw = fs.readFileSync(dataPath);
const data = JSON.parse(raw.toString("utf8"));
const problems = [];

function requireText(value, label) {
  if (typeof value !== "string" || !value.trim()) problems.push(`${label} 不能为空`);
}

function unique(items, label) {
  const seen = new Set();
  for (const item of items) {
    requireText(item.id, `${label}.id`);
    if (seen.has(item.id)) problems.push(`${label} id 重复：${item.id}`);
    seen.add(item.id);
  }
  return seen;
}

if (data.schemaVersion !== "1.0") problems.push("schemaVersion 必须为 1.0");
requireText(data.contentVersion, "contentVersion");
requireText(data.reviewedAt, "reviewedAt");
requireText(data.editorialNote, "editorialNote");

for (const [key, label] of [
  ["eras", "era"],
  ["dynasties", "dynasty"],
  ["events", "event"],
  ["sources", "source"],
]) {
  if (!Array.isArray(data[key]) || data[key].length === 0) {
    problems.push(`${key} 必须是非空数组`);
  } else {
    unique(data[key], label);
  }
}

const eraIds = new Set(data.eras.map((item) => item.id));
const dynastyIds = new Set(data.dynasties.map((item) => item.id));
const sourceIds = new Set(data.sources.map((item) => item.id));

for (const era of data.eras) {
  requireText(era.title, `${era.id}.title`);
  if (!Number.isInteger(era.startYear) || !Number.isInteger(era.endYear) || era.startYear > era.endYear) {
    problems.push(`${era.id} 起止年份无效`);
  }
}

for (const dynasty of data.dynasties) {
  requireText(dynasty.name, `${dynasty.id}.name`);
  requireText(dynasty.summary, `${dynasty.id}.summary`);
  if (!eraIds.has(dynasty.eraId)) problems.push(`${dynasty.id} 引用了未知时代 ${dynasty.eraId}`);
  if (!Number.isInteger(dynasty.startYear) || !Number.isInteger(dynasty.endYear) || dynasty.startYear > dynasty.endYear) {
    problems.push(`${dynasty.id} 起止年份无效`);
  }
  if (!Array.isArray(dynasty.sourceIds) || dynasty.sourceIds.length === 0) {
    problems.push(`${dynasty.id} 缺少出处`);
  } else {
    for (const sourceId of dynasty.sourceIds) {
      if (!sourceIds.has(sourceId)) problems.push(`${dynasty.id} 引用了未知出处 ${sourceId}`);
    }
  }
}

for (const event of data.events) {
  requireText(event.title, `${event.id}.title`);
  requireText(event.summary, `${event.id}.summary`);
  requireText(event.date?.display, `${event.id}.date.display`);
  if (!dynastyIds.has(event.dynastyId)) problems.push(`${event.id} 引用了未知政权 ${event.dynastyId}`);
  if (!Number.isInteger(event.date?.year)) problems.push(`${event.id}.date.year 必须是整数`);
  if (!Number.isInteger(event.importance) || event.importance < 1 || event.importance > 3) {
    problems.push(`${event.id}.importance 必须在 1—3`);
  }
  if (!Array.isArray(event.sourceIds) || event.sourceIds.length === 0) {
    problems.push(`${event.id} 缺少出处`);
  } else {
    for (const sourceId of event.sourceIds) {
      if (!sourceIds.has(sourceId)) problems.push(`${event.id} 引用了未知出处 ${sourceId}`);
    }
  }
}

for (const source of data.sources) {
  requireText(source.title, `${source.id}.title`);
  requireText(source.citation, `${source.id}.citation`);
  if (!["primary", "reference"].includes(source.kind)) {
    problems.push(`${source.id}.kind 非法`);
  }
}

if (problems.length) {
  console.error(problems.map((problem) => `- ${problem}`).join("\n"));
  process.exit(1);
}

const manifest = {
  schemaVersion: data.schemaVersion,
  contentVersion: data.contentVersion,
  reviewedAt: data.reviewedAt,
  dynastyCount: data.dynasties.length,
  eventCount: data.events.length,
  sourceCount: data.sources.length,
  chroniclesSHA256: crypto.createHash("sha256").update(raw).digest("hex"),
};

if (checkOnly) {
  if (!fs.existsSync(manifestPath)) {
    console.error("content-manifest.v1.json 不存在，请先运行 node tools/validate_chronicles.mjs");
    process.exit(1);
  }
  const expected = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  for (const key of Object.keys(manifest)) {
    if (expected[key] !== manifest[key]) {
      console.error(`content manifest 不匹配：${key}`);
      process.exit(1);
    }
  }
} else {
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", "utf8");
}

console.log(
  JSON.stringify(
    {
      status: "ok",
      dynasties: data.dynasties.length,
      events: data.events.length,
      sources: data.sources.length,
      contentVersion: data.contentVersion,
      sha256: manifest.chroniclesSHA256,
    },
    null,
    2
  )
);
