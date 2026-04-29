#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# ── Step 1: 기존 파이프라인 (grid + training) 재활용 ──
python main.py \
  --mode prepare-grid \
  --project-root "$ROOT_DIR" \
  --seeds 141,142,143

python main.py \
  --mode train-variants \
  --project-root "$ROOT_DIR" \
  --seeds 141,142,143

# ── Step 2: Conformal Risk Control 실험 ──
python main.py \
  --mode run-conformal \
  --project-root "$ROOT_DIR" \
  --seeds 141,142,143 \
  --scenario-families complaint-heavy,promotion-heavy,dormancy-heavy,seasonal-shift \
  --latencies 1,3,7 \
  --budgets 220000,390000,560000 \
  --burn-in-weeks 12 \
  --training-landmarks 12 \
  --decision-week-limit 16 \
  --bootstrap-iterations 300 \
  --partial-reopt-score-delta 0.10 \
  --partial-reopt-high-risk-threshold 0.80 \
  --partial-reopt-top-share 0.15 \
  --alpha-grid 0.05,0.10,0.20 \
  --ensemble-size 5 \
  --conformal-min-cal-size 200 \
  --force
