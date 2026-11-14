# -*- coding: utf-8 -*-
import json, os, re, sys, unicodedata

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "_corpus.pipe")
THEMES = ["修身自省", "处世智慧", "心境审美", "读书学习", "励志进取", "家国天下"]
PREFIX = {"修身自省": "XS", "处世智慧": "CS", "心境审美": "XJ",
          "读书学习": "DX", "励志进取": "LZ", "家国天下": "GJ"}

rows = []
with open(SRC, encoding="utf-8") as f:
    for lineno, line in enumerate(f, 1):
        line = line.rstrip("\n").rstrip("\r")
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) != 6:
            sys.exit(f"line {lineno}: expected 6 fields, got {len(parts)}")
        qid, theme, text, source, locator, tone = [p.strip() for p in parts]
        rows.append(dict(id=qid, theme=theme, text=text, source=source,
                         locator=locator, tone=tone, status="pending"))

errors = []
if len(rows) != 480:
    errors.append(f"total is {len(rows)}, expected 480")

seen_ids = {}
seen_text = {}
for i, q in enumerate(rows):
    for k in ("id", "theme", "text", "source", "locator", "tone"):
        if not q[k]:
            errors.append(f"{q['id']}: empty {k}")
    if q["id"] in seen_ids:
        errors.append(f"duplicate id {q['id']}")
    seen_ids[q["id"]] = 1
    if q["theme"] not in THEMES:
        errors.append(f"{q['id']}: bad theme {q['theme']}")
    key = re.sub(r"[\s，。；：！？、“”‘’《》·,.!?;:\"'()（）—\-]", "", q["text"])
    if key in seen_text:
        errors.append(f"duplicate text {q['id']} == {seen_text[key]}")
    seen_text[key] = q["id"]
    if not re.match(r"^%s-\d{3}$" % PREFIX.get(q["theme"], "??"), q["id"]):
        errors.append(f"{q['id']}: id prefix does not match theme {q['theme']}")

counts = {t: 0 for t in THEMES}
for q in rows:
    counts[q["theme"]] = counts.get(q["theme"], 0) + 1
for t in THEMES:
    if counts[t] != 80:
        errors.append(f"theme {t} has {counts[t]}, expected 80")

if errors:
    print("VALIDATION FAILED")
    for e in errors:
        print(" -", e)
    sys.exit(1)

with open(os.path.join(BASE, "quotes.tsv"), "w", encoding="utf-8", newline="\n") as f:
    for q in rows:
        f.write("\t".join([q["id"], q["theme"], q["text"], q["source"], q["locator"], q["tone"]]) + "\n")

with open(os.path.join(BASE, "quotes.sample.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(rows, f, ensure_ascii=False, indent=2)
    f.write("\n")

with open(os.path.join(BASE, "_template.html"), encoding="utf-8") as f:
    html = f.read()
payload = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
html = html.replace("__QUOTE_DATA__", payload)
with open(os.path.join(BASE, "index.html"), "w", encoding="utf-8", newline="\n") as f:
    f.write(html)

len_map = {}
for q in rows:
    n = len(re.sub(r"[\s，。；：！？、“”‘’《》·]", "", q["text"]))
    len_map.setdefault(q["theme"], []).append(n)

print("OK 480 quotes")
for t in THEMES:
    arr = len_map[t]
    print(f"  {t}: {len(arr)} 条, 最短 {min(arr)} 字, 最长 {max(arr)} 字, 平均 {sum(arr)/len(arr):.1f} 字")
alllen = [n for arr in len_map.values() for n in arr]
print(f"  total: min {min(alllen)}, max {max(alllen)}, avg {sum(alllen)/len(alllen):.1f}")
print(f"  index.html: {os.path.getsize(os.path.join(BASE, 'index.html'))} bytes")
