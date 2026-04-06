#!/usr/bin/env sh
set -e

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DATA_DIR="${DATA_DIR:-$ROOT_DIR/data}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
TMP_DIR="${TMP_DIR:-$DATA_DIR/tmp}"
DEFAULT_CONFIG="$ROOT_DIR/config.defaults.toml"

mkdir -p "$DATA_DIR" "$LOG_DIR" "$TMP_DIR" 2>/dev/null || true

if [ ! -f "$DATA_DIR/config.toml" ]; then
  cp "$DEFAULT_CONFIG" "$DATA_DIR/config.toml" 2>/dev/null || true
fi

if [ ! -f "$DATA_DIR/token.json" ]; then
  echo "{}" > "$DATA_DIR/token.json" 2>/dev/null || true
fi

chmod 600 "$DATA_DIR/config.toml" "$DATA_DIR/token.json" 2>/dev/null || true
