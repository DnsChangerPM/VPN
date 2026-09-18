#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
flutter create . --project-name nimbus --org pm.dnschanger --platforms=android,windows
python3 scripts/apply_overlays.py
echo "Scaffold ready. Fetch cores with: bash scripts/fetch_cores.sh"
