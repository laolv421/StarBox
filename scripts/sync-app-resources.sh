#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/app/Starbox/Resources"
cp "$ROOT/site/v1/"*.json "$ROOT/app/Starbox/Resources/"
echo "Synced site/v1 -> app/Starbox/Resources"
