#!/bin/bash
# Backward-compatible alias; use purge script for full cleanup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/purge-mac-harmony.sh"
