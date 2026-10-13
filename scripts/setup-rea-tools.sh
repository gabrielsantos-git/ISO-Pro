#!/usr/bin/env bash
# Installs the Android engines REA needs (apktool + jadx-headless-mcp) into
# ~/.cache/rea-tools, verifying pinned SHA-256 digests. Idempotent.
# When run from a Claude Code SessionStart hook, also exports the REA_*
# variables into the session through $CLAUDE_ENV_FILE.
set -euo pipefail

TOOLS_DIR="${REA_TOOLS_DIR:-$HOME/.cache/rea-tools}"

APKTOOL_VERSION="2.12.1"
APKTOOL_SHA256="66cf4524a4a45a7f56567d08b2c9b6ec237bcdd78cee69fd4a59c8a0243aeafa"
APKTOOL_URL="https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar"

# Must match the release REA audits (dist/android/JadxRelease.js).
JADX_VERSION="0.7.1"
JADX_SHA256="6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
JADX_URL="https://github.com/1013503897/jadx-headless-mcp/releases/download/v${JADX_VERSION}/jadx-headless-mcp-${JADX_VERSION}-all.jar"

fetch() { # url dest sha256
  local url="$1" dest="$2" sha="$3"
  if [[ -f "$dest" ]] && echo "$sha  $dest" | sha256sum -c --status; then
    return 0
  fi
  curl -fsSL --retry 3 -o "$dest.part" "$url"
  echo "$sha  $dest.part" | sha256sum -c --status || {
    echo "setup-rea-tools: checksum mismatch for $url" >&2
    rm -f "$dest.part"
    return 1
  }
  mv "$dest.part" "$dest"
}

if ! command -v java >/dev/null 2>&1; then
  echo "setup-rea-tools: java not found; apktool/jadx need a JDK 17+" >&2
  exit 0
fi

mkdir -p "$TOOLS_DIR"
fetch "$APKTOOL_URL" "$TOOLS_DIR/apktool_${APKTOOL_VERSION}.jar" "$APKTOOL_SHA256"
fetch "$JADX_URL" "$TOOLS_DIR/jadx-headless-mcp-${JADX_VERSION}-all.jar" "$JADX_SHA256"

cat > "$TOOLS_DIR/apktool" <<LAUNCHER
#!/usr/bin/env bash
exec java -jar "$TOOLS_DIR/apktool_${APKTOOL_VERSION}.jar" "\$@"
LAUNCHER
chmod +x "$TOOLS_DIR/apktool"

if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  {
    echo "export REA_APKTOOL_COMMAND=\"$TOOLS_DIR/apktool\""
    echo "export REA_JADX_MCP_JAR=\"$TOOLS_DIR/jadx-headless-mcp-${JADX_VERSION}-all.jar\""
  } >> "$CLAUDE_ENV_FILE"
fi

echo "setup-rea-tools: apktool ${APKTOOL_VERSION} and jadx-headless-mcp ${JADX_VERSION} ready in $TOOLS_DIR"
