# Nomi Repository Instructions

Before changing Nomi, read the newest `docs/NOMI_*.md` project record,
`docs/NOMI_1.0_BUILD6_ARCHIVE.md`, and the relevant recent entries in
`docs/DEVLOG.md`.

## Authority and Git

- Do not push, create a release, or trigger a deployment unless the user explicitly asks for it.
- Inspect the worktree before editing and preserve unrelated changes.
- Use one writer for overlapping files. Other agents should do read-only review unless the user requests parallel work.
- Keep commits focused and explain user-visible impact.

## Product Invariants

- Preserve the titanium Nomi body, black glass face, blue eyes, expression system, blinking, gaze following, drag interaction, and physics behavior.
- A black two-eye icon is a small logo, not a replacement for the full character.
- Bottom navigation: conversation, "今天值得知道", todos.
- Settings stays available from the top-right header action and keeps a close path back to home.
- Keep permissions contextual. Do not request all permissions at launch.
- Music must come from the iPhone Music library, never file import, and must not occupy the Dynamic Island.
- News must be Chinese and open inside Nomi.
- Never fabricate news, completed actions, authorization state, or transaction success.
- Preserve the unified full-screen background and the existing swipe/keyboard interactions.

## Verification

- Run `powershell -NoProfile -File "$env:USERPROFILE\.codex\skills\nomi-project-maintainer\scripts\verify_source.ps1"`.
- For a downloaded IPA, run `verify_ipa.ps1` with the expected version and build.
- CI is the authoritative SwiftUI compile check because this Windows host only performs syntax and pure-logic checks.

