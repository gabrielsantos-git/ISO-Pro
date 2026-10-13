# ISO-Pro

Pro camera app project. Phase 1 is a feature study of existing pro camera apps
(starting with Blackmagic Camera); later phases build our own app.

## Reverse engineering with REA

- REA (`rea-agents@6.4.0`) is registered as the `rea` MCP server in `.mcp.json`;
  the `reverse-engineer-anything` skill lives in `.claude/skills/`.
- `scripts/setup-rea-tools.sh` (run by the SessionStart hook in
  `.claude/settings.json`) installs apktool 2.12.1 and jadx-headless-mcp 0.7.1
  into `~/.cache/rea-tools` and exports `REA_APKTOOL_COMMAND` / `REA_JADX_MCP_JAR`.
- The REA CLI works too: `npx -y rea-agents@6.4.0 <command>`
  (e.g. `inspect-android-package`, `decode-android-resources`,
  `inspect-android-class`, `inspect-android-method`).
- Put target binaries in `targets/` (git-ignored). Never commit third-party
  APKs, decompiled source, or extracted assets.

## Clean-room rule

Analysis documents (`docs/analysis/`) record features, behaviors, platform APIs
and formats observed — not copied code, strings, icons or layouts. Our app's
code is written from those specs and public platform docs only.
