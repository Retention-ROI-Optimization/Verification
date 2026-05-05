# Dunn_Experiment: dunnhumby Complete Journey 기반 이탈 점수 노후화 실험

이 디렉토리는 **dunnhumby The Complete Journey** 데이터를 내부 리텐션 실험 스키마로 변환한 뒤, 이탈 점수의 신선도 저하(score staleness)가 예산 제약형 리텐션 정책의 가치와 대상 안정성에 미치는 영향을 평가하기 위한 실험 패키지입니다.

핵심 질문은 단순히 오래된 점수가 평균 정책 가치(policy value)를 얼마나 낮추는지가 아닙니다. 본 실험은 같은 의사결정 엔진에서 최신 점수 정책과 노후 점수 정책을 비교하여, **평균 가치 변화**, **타깃 고객 집합 변동**, **위험 고객 누락**, **개입 시점 누락**을 함께 측정합니다.

---

## 1. 무엇을 재현하는가

본 패키지는 다음 실험을 재현하거나 점검할 수 있도록 구성되어 있습니다.

1. **dunnhumby 데이터 변환**  
   `transaction_data.csv`, `hh_demographic.csv`, `campaign_desc.csv`, `campaign_table.csv`, `coupon_redempt.csv`, `product.csv`를 읽어 내부 raw-grid 스키마로 변환합니다.

2. **점수 노후화 정책 비교**  
   같은 고객·예산·의사결정 시점에서 최신 점수 정책과 노후 점수 정책을 비교합니다.

3. **모델 강도와 점수 신선도 분리 평가**  
   `base-stale`, `full-refresh`, `stronger-but-stale`, `weaker-but-fresh`를 비교하여 모델 성능 향상과 점수 최신화의 효과를 분리합니다.

4. **부분 재최적화 및 민감도 점검**  
   노후화 영향이 큰 일부 고객만 다시 계산하는 partial re-optimization의 비용 대비 효과를 평가합니다.

5. **CRC 기반 선택적 갱신 실험**  
   `run-conformal` 모드로 CRC 기반 후보 선택과 partial 후보를 함께 비교할 수 있습니다.

---

## 2. 디렉토리 구조

```text
Dunn_Experiment/
├── main.py
├── README.md
├── README_FOR_RESEARCH.md
├── requirements.txt
├── requirements.original.txt
├── scripts/
│   ├── prepare_dunnhumby_complete_journey.py
│   ├── run_smoke_paper.sh
│   ├── run_full_paper.sh
│   ├── run_theta_sensitivity.sh
│   └── run_conformal.sh
├── src/
│   ├── external_datasets/
│   │   └── dunnhumby_complete_journey.py
│   ├── features/
│   ├── optimization/
│   ├── paper_latency/
│   └── simulator/
├── artifacts/
│   └── results/
│       ├── paper_latency/
│       │   ├── block_level_metrics.csv
│       │   └── summary_metrics.csv
│       └── training/
└── results/
    ├── README.md
    ├── 01_summary_clean.csv
    ├── 02_by_scenario_policy.csv
    ├── 03_policy_overall.csv
    ├── 04_latency_effect.csv
    ├── 05_budget_effect.csv
    ├── 06_block_stats.csv
    └── 07_policy_vs_full_refresh.csv
```

`artifacts/results/paper_latency/`에는 원본 실험 결과가 있고, `results/`에는 논문 해석용으로 재구성한 요약 CSV가 있습니다.

> 주의: 이 패키지에는 dunnhumby 원본 ZIP과 변환된 `artifacts/raw_grid/`가 포함되어 있지 않을 수 있습니다. 완전 재현을 하려면 원본 데이터를 내려받아 4절의 변환 절차를 먼저 실행해야 합니다.

---

## 3. 설치

Python 3.10 이상을 권장합니다.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`requirements.txt`는 실험 재현에 필요한 최소 의존성만 포함합니다.

```text
pandas
numpy
scikit-learn
xgboost
joblib
matplotlib
PyYAML
```

---

## 4. dunnhumby 데이터 준비

### 4-1. 필요한 원본 테이블

`prepare_dunnhumby_complete_journey.py`는 원본 ZIP 또는 압축 해제 폴더에서 아래 파일을 찾습니다.

```text
transaction_data.csv
hh_demographic.csv
campaign_desc.csv
campaign_table.csv
coupon_redempt.csv
product.csv
```

### 4-2. 내부 실험 스키마로 변환

원본 ZIP을 내려받은 뒤 다음 명령을 실행합니다.

```bash
python scripts/prepare_dunnhumby_complete_journey.py \
  --project-root . \
  --zip-path /path/to/dunnhumby_The-Complete-Journey.zip \
  --seeds 41,42,43
```

압축을 이미 풀어 둔 경우 `--zip-path`에 폴더 경로를 넣어도 됩니다.

```bash
python scripts/prepare_dunnhumby_complete_journey.py \
  --project-root . \
  --zip-path /path/to/dunnhumby_extracted_folder \
  --seeds 41,42,43
```

디버깅용으로 작은 규모만 만들고 싶으면 다음처럼 household 수를 제한할 수 있습니다.

```bash
python scripts/prepare_dunnhumby_complete_journey.py \
  --project-root . \
  --zip-path /path/to/dunnhumby_The-Complete-Journey.zip \
  --seeds 41,42,43 \
  --household-limit 500
```

변환 결과는 아래 경로에 생성됩니다.

```text
artifacts/raw_grid/seed_41/
artifacts/raw_grid/seed_42/
artifacts/raw_grid/seed_43/
artifacts/external_imports/complete_journey/import_manifest.json
```

각 seed 폴더에는 다음 내부 스키마 CSV가 생성됩니다.

```text
customers.csv
orders.csv
events.csv
state_snapshots.csv
campaign_exposures.csv
treatment_assignments.csv
customer_summary.csv
cohort_retention.csv
```

### 4-3. 중요한 주의사항

`prepare-grid --force`는 시뮬레이터 데이터를 다시 만들 수 있으므로, dunnhumby raw-grid를 유지하려면 데이터 변환 후에는 불필요하게 실행하지 않는 것이 좋습니다. `run-paper`, `train-variants`, `run-conformal`은 기존 `artifacts/raw_grid/seed_*`가 있으면 이를 재사용합니다.

---

## 5. 빠른 실행 순서

### 5-1. 구조 점검용 smoke test

```bash
bash scripts/run_smoke_paper.sh
```

동일한 명령을 직접 쓰면 다음과 같습니다.

```bash
python main.py \
  --mode run-paper \
  --project-root . \
  --seeds 41 \
  --scenario-families complaint-heavy,promotion-heavy \
  --latencies 0,1,3,7 \
  --budgets 2640000,7250000,11530000 \
  --decision-week-limit 2 \
  --bootstrap-iterations 100 \
  --training-landmarks 4
```

### 5-2. 논문용 compact run

```bash
python main.py \
  --mode run-paper \
  --project-root . \
  --seeds 41,42,43 \
  --scenario-families complaint-heavy,promotion-heavy,dormancy-heavy,seasonal-shift \
  --latencies 0,1,3,7 \
  --budgets 2640000,7250000,11530000 \
  --burn-in-weeks 12 \
  --training-landmarks 12 \
  --decision-week-limit 16 \
  --bootstrap-iterations 300
```

### 5-3. theta 민감도 실험

```bash
bash scripts/run_theta_sensitivity.sh
```

직접 실행 명령은 다음과 같습니다.

```bash
python main.py \
  --mode run-theta-sensitivity \
  --project-root . \
  --seeds 41,42,43 \
  --scenario-families complaint-heavy,promotion-heavy,dormancy-heavy,seasonal-shift \
  --latencies 1,3,7 \
  --budgets 2640000,7250000,11530000 \
  --burn-in-weeks 12 \
  --training-landmarks 12 \
  --decision-week-limit 16 \
  --bootstrap-iterations 300 \
  --theta-grid 0.05,0.10,0.15 \
  --partial-reopt-high-risk-threshold 0.80 \
  --partial-reopt-top-share 0.15
```

### 5-4. CRC / conformal 실험

```bash
bash scripts/run_conformal.sh
```

이 스크립트는 grid와 모델을 재사용한 뒤 `run-conformal`을 실행합니다. 기본 설정은 다음과 같습니다.

```text
seeds: 141,142,143
scenario families: complaint-heavy, promotion-heavy, dormancy-heavy, seasonal-shift
latencies: 1,3,7
budgets: 220000,390000,560000
alpha grid: 0.05,0.10,0.20
partial theta: 0.10
partial high-risk threshold: 0.80
partial top-share: 0.15
bootstrap iterations: 300
```

---

## 6. 실험 정책 정의

| 정책 | 의미 |
|---|---|
| `full-refresh` | 의사결정 시점의 최신 점수를 사용하는 기준 정책 |
| `base-stale` | 기본 모델이 L일 전 노후 점수를 사용하는 정책 |
| `stronger-but-stale` | 더 강한 모델이지만 L일 전 노후 점수를 쓰는 정책 |
| `weaker-but-fresh` | 더 약한 모델이지만 최신 점수를 쓰는 정책 |
| `partial re-optimization` | 점수 변화량 또는 고위험 조건을 만족하는 일부 고객만 다시 계산하는 선택적 갱신 |
| `CRC / conformal` | 보정 표본의 불일치 위험을 이용해 추가 갱신 후보를 식별하는 규칙 |

---

## 7. 핵심 지표

| 지표 | 의미 | 해석 |
|---|---|---|
| `policy_value` | 선택된 정책의 기대 가치 | 높을수록 좋음 |
| `stale_regret` | full-refresh 대비 후보 정책의 가치 차이 | 양수면 손실, 음수면 후보 정책 가치가 더 크게 산출됨 |
| `relative_loss` | full-refresh 대비 상대 가치 차이 | 평균 가치 차이의 상대 지표 |
| `target_overlap` | fresh 정책 대상과 후보 정책 대상의 겹침 비율 | 높을수록 대상 목록 안정성 높음 |
| `missed_at_risk` | fresh 기준 위험 고객 중 후보 정책에서 빠진 비율 | 낮을수록 좋음 |
| `window_miss_rate` | 개입 시점을 놓친 비율 | 낮을수록 좋음 |
| `partial_reopt_optimization_call_ratio` | partial 갱신으로 다시 계산한 고객 비율 | 실제 호출비용 |
| `partial_reopt_full_refresh_value_ratio` | partial 갱신의 full-refresh 대비 가치 보전율 | 1에 가까울수록 좋음 |

`stale_regret`이나 `relative_loss`가 음수일 수 있습니다. 이는 stale 정책이 실제로 더 안정적이라는 뜻이 아니라, 오래된 정보와 정책 선택 방식 때문에 평균 가치가 낙관적으로 산출될 수 있음을 의미합니다. 따라서 본 실험에서는 평균 가치뿐 아니라 `target_overlap`, `missed_at_risk`, `window_miss_rate`를 함께 해석해야 합니다.

---

## 8. 포함된 요약 결과 해석

현재 패키지의 `results/` 폴더에는 원본 결과를 논문 해석용으로 정리한 CSV가 포함되어 있습니다.

### 8-1. 정책별 전체 평균

`results/03_policy_overall.csv` 기준 전체 평균은 다음과 같습니다.

| 정책 | policy value (M) | relative loss (%) | target overlap (%) | missed-at-risk (%) | window miss (%) |
|---|---:|---:|---:|---:|---:|
| `base-stale` | 144.13 | -0.57 | 91.10 | 12.33 | 0.569 |
| `full-refresh` | 143.42 | 0.00 | 100.00 | 0.00 | 0.000 |
| `stronger-but-stale` | 149.55 | -4.27 | 78.39 | 32.83 | 1.338 |
| `weaker-but-fresh` | 91.87 | 38.08 | 74.01 | 4.00 | 0.000 |

핵심은 평균 가치만 보면 stale 정책이나 stronger-but-stale이 좋아 보일 수 있지만, 대상 안정성 지표에서는 손상이 뚜렷하다는 점입니다. 특히 `stronger-but-stale`은 평균 가치는 가장 높게 나오지만 `target_overlap`은 78.39%, `missed_at_risk`는 32.83%로 악화됩니다.

### 8-2. 지연 수준 효과

`results/04_latency_effect.csv`의 base-stale 지연 효과는 다음과 같습니다.

| latency | target overlap (%) | missed-at-risk (%) | window miss (%) |
|---:|---:|---:|---:|
| 0일 | 100.00 | 0.00 | 0.000 |
| 1일 | 88.63 | 15.85 | 0.303 |
| 3일 | 88.23 | 16.33 | 0.444 |
| 7일 | 87.52 | 17.15 | 1.529 |

1일 지연만으로도 target overlap이 크게 낮아지고 missed-at-risk가 증가합니다. 7일 지연에서는 개입 시점 누락(`window_miss`)이 가장 크게 증가합니다.

### 8-3. partial re-optimization 효과

`base-stale` 조건에서 partial re-optimization은 평균적으로 전체 고객의 약 **4.89%**만 다시 계산하면서 full-refresh 대비 약 **99.55%**의 가치 보전율을 보였습니다. 즉, 전체 갱신 없이도 적은 호출비용으로 정책 가치를 거의 유지할 수 있습니다.

---

## 9. 결과 파일 설명

| 파일 | 내용 |
|---|---|
| `artifacts/results/paper_latency/block_level_metrics.csv` | seed, scenario, decision date, budget, latency, policy별 block-level 원본 결과 |
| `artifacts/results/paper_latency/summary_metrics.csv` | block-level 결과의 bootstrap 요약 |
| `results/01_summary_clean.csv` | 요약 결과를 보기 쉽게 재정리한 표 |
| `results/02_by_scenario_policy.csv` | scenario family × policy 평균 |
| `results/03_policy_overall.csv` | 정책별 전체 평균 |
| `results/04_latency_effect.csv` | base-stale에서 latency별 효과 |
| `results/05_budget_effect.csv` | budget × policy 평균 |
| `results/06_block_stats.csv` | block-level seed/date 변동성 |
| `results/07_policy_vs_full_refresh.csv` | full-refresh 기준 상대 성능 비교 |

---

## 10. 논문 관점의 핵심 메시지

이 dunnhumby 실험은 다음 결론을 뒷받침합니다.

1. **점수 노후화 비용은 평균 가치보다 대상 안정성에서 더 선명하게 나타난다.**  
   `base-stale`은 평균 policy value 손실이 제한적이지만, 7일 지연에서 target overlap은 87.52%, missed-at-risk는 17.15%까지 악화됩니다.

2. **강한 모델도 노후 점수를 쓰면 운영적 불안정성을 만들 수 있다.**  
   `stronger-but-stale`은 평균 가치는 높지만 대상 중복률과 위험 고객 누락률이 크게 악화됩니다.

3. **단순 최신화만으로도 충분하지 않다.**  
   `weaker-but-fresh`는 시점 누락은 없지만 평균 가치 손실이 큽니다. 모델 품질과 점수 신선도는 분리해서 평가해야 합니다.

4. **partial re-optimization은 비용 대비 효과가 크다.**  
   약 5% 미만의 재계산으로 full-refresh 가치의 99% 이상을 보전하므로, 전체 갱신이 어려운 운영 환경에서 실용적인 1차 선택 규칙이 됩니다.

---

## 11. 재현 시 흔한 문제

### `raw_grid`가 없는데 run-paper를 실행한 경우

`artifacts/raw_grid/seed_*`가 없으면 `run-paper`가 시뮬레이터 데이터를 생성할 수 있습니다. dunnhumby 실험을 재현하려면 먼저 `prepare_dunnhumby_complete_journey.py`를 실행해 raw-grid를 만들어야 합니다.

### `prepare-grid --force`를 실행한 경우

기존 dunnhumby raw-grid가 시뮬레이터 결과로 덮일 수 있습니다. dunnhumby 변환 결과를 유지하려면 원본 ZIP에서 다시 변환하십시오.

### `stale_regret`이 음수로 나오는 경우

오류가 아닙니다. 평균 가치가 더 크게 산출되더라도 타깃 정합성과 위험 고객 누락을 함께 확인해야 합니다.

---

## 12. 권장 실행 순서 요약

처음부터 완전 재현하려면 아래 순서가 가장 안전합니다.

```bash
# 1. 설치
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. dunnhumby 원본 데이터 변환
python scripts/prepare_dunnhumby_complete_journey.py \
  --project-root . \
  --zip-path /path/to/dunnhumby_The-Complete-Journey.zip \
  --seeds 41,42,43

# 3. smoke test
bash scripts/run_smoke_paper.sh

# 4. 논문용 compact run
python main.py \
  --mode run-paper \
  --project-root . \
  --seeds 41,42,43 \
  --scenario-families complaint-heavy,promotion-heavy,dormancy-heavy,seasonal-shift \
  --latencies 0,1,3,7 \
  --budgets 2640000,7250000,11530000 \
  --burn-in-weeks 12 \
  --training-landmarks 12 \
  --decision-week-limit 16 \
  --bootstrap-iterations 300

# 5. 선택: theta sensitivity
bash scripts/run_theta_sensitivity.sh

# 6. 선택: CRC/conformal run
bash scripts/run_conformal.sh
```
