# Content source

`expansion.v1.json` is the authored expansion source for the first full-history content pass.

It contains:

- 23 dynasty profiles with political structure, society and legacy
- 57 event dossiers with background, process, consequence and significance
- 66 person profiles
- 23 place profiles
- 31 institutional and cultural topics
- additional bibliographic sources and cross-source assignments

The app consumes the generated file:

```text
ios/ChineseChronicles/Resources/chronicles.v1.json
```

After editing the authored content, run:

```powershell
node tools/apply_content_expansion.mjs
node tools/validate_chronicles.mjs
node tools/build_web_demo.mjs
```

The merge step is idempotent. CI runs the corresponding `--check` commands and fails if the generated iOS or web data is stale.

Do not treat this as a completed scholarly reference edition. Every event currently has at least two bibliographic sources, but many citations still need page- or chapter-level verification.
