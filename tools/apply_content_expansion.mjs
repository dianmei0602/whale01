#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const basePath = path.join(
  root,
  "ios",
  "ChineseChronicles",
  "Resources",
  "chronicles.v1.json"
);
const expansionPath = path.join(root, "content", "expansion.v1.json");
const checkOnly = process.argv.includes("--check");

const base = JSON.parse(fs.readFileSync(basePath, "utf8"));
const expansion = JSON.parse(fs.readFileSync(expansionPath, "utf8"));

const dynastyIds = new Set(base.dynasties.map((item) => item.id));
const sourceIds = new Set(base.sources.map((item) => item.id));
const baseEventIds = new Set(base.events.map((item) => item.id));
const newEvents = expansion.events.filter((item) => !baseEventIds.has(item.id));
const allEventIds = new Set([
  ...base.events.map((item) => item.id),
  ...newEvents.map((item) => item.id)
]);

for (const dynasty of base.dynasties) {
  if (!expansion.dynastyProfiles[dynasty.id]) {
    throw new Error(`missing dynasty profile: ${dynasty.id}`);
  }
}

for (const event of base.events) {
  if (
    !event.background &&
    !expansion.eventProfiles[event.id]
  ) {
    throw new Error(`missing event profile: ${event.id}`);
  }
}

for (const event of expansion.events) {
  if (baseEventIds.has(event.id) && !base.events.find((item) => item.id === event.id)?.background) {
    throw new Error(`new event duplicates an existing id: ${event.id}`);
  }
}

const entityGroups = {
  people: expansion.people,
  places: expansion.places,
  topics: expansion.topics
};
const entityIds = {};
for (const [key, items] of Object.entries(entityGroups)) {
  const ids = new Set();
  for (const item of items) {
    if (ids.has(item.id)) throw new Error(`duplicate ${key} id: ${item.id}`);
    ids.add(item.id);
  }
  entityIds[key] = ids;
}

const allEvents = [
  ...base.events.map((event) => ({
    ...event,
    ...(expansion.eventProfiles[event.id] ?? {})
  })),
  ...newEvents
].sort(
  (left, right) =>
    left.date.year - right.date.year ||
    left.title.localeCompare(right.title, "zh-CN")
);

const allDynasties = base.dynasties.map((dynasty) => ({
  ...dynasty,
  ...expansion.dynastyProfiles[dynasty.id]
}));

function assertReferences(owner, values, ids, label) {
  for (const id of values ?? []) {
    if (!ids.has(id)) throw new Error(`${owner} references unknown ${label}: ${id}`);
  }
}

for (const dynasty of allDynasties) {
  assertReferences(dynasty.id, dynasty.peopleIds, entityIds.people, "person");
  assertReferences(dynasty.id, dynasty.placeIds, entityIds.places, "place");
  assertReferences(dynasty.id, dynasty.topicIds, entityIds.topics, "topic");
}

for (const event of allEvents) {
  if (!dynastyIds.has(event.dynastyId)) {
    throw new Error(`${event.id} references unknown dynasty: ${event.dynastyId}`);
  }
  assertReferences(event.id, event.peopleIds, entityIds.people, "person");
  assertReferences(event.id, event.placeIds, entityIds.places, "place");
  assertReferences(event.id, event.topicIds, entityIds.topics, "topic");
  assertReferences(event.id, event.sourceIds, sourceIds, "source");
  assertReferences(event.id, event.relatedDynastyIds, dynastyIds, "dynasty");
}

for (const person of expansion.people) {
  assertReferences(person.id, person.eventIds, allEventIds, "event");
  assertReferences(person.id, person.dynastyIds, dynastyIds, "dynasty");
  assertReferences(person.id, person.sourceIds, sourceIds, "source");
}

for (const place of expansion.places) {
  assertReferences(place.id, place.eventIds, allEventIds, "event");
  assertReferences(place.id, place.dynastyIds, dynastyIds, "dynasty");
  assertReferences(place.id, place.sourceIds, sourceIds, "source");
}

for (const topic of expansion.topics) {
  assertReferences(topic.id, topic.eventIds, allEventIds, "event");
  assertReferences(topic.id, topic.dynastyIds, dynastyIds, "dynasty");
  assertReferences(topic.id, topic.sourceIds, sourceIds, "source");
}

const output = {
  ...base,
  contentVersion: `2026.11.18-${expansion.version}`,
  reviewedAt: expansion.reviewedAt,
  editorialNote: expansion.editorialNote,
  dynasties: allDynasties,
  events: allEvents,
  people: expansion.people,
  places: expansion.places,
  topics: expansion.topics
};

const serialized = JSON.stringify(output, null, 2) + "\n";
if (checkOnly) {
  if (fs.readFileSync(basePath, "utf8") !== serialized) {
    console.error("chronicles.v1.json is out of date; run node tools/apply_content_expansion.mjs");
    process.exit(1);
  }
  console.log("expanded chronicle content is current");
} else {
  fs.writeFileSync(basePath, serialized, "utf8");
  console.log(
    JSON.stringify(
      {
        dynasties: output.dynasties.length,
        events: output.events.length,
        people: output.people.length,
        places: output.places.length,
        topics: output.topics.length,
        sources: output.sources.length
      },
      null,
      2
    )
  );
}
