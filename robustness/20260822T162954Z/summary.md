# Robustness experiment summary

The data do not support the claim that every rewrite plan outperforms its original DuckDB plan.

- Expected rewrite plans: 46
- Completely measured plans: 37
- Faster by median: 30/46
- Faster by arithmetic mean: 30/46
- All faster by median: false
- All faster by mean: false
- Median plan speedup (from plan medians): 1.745x
- Arithmetic mean plan speedup: 1.862x
- Geometric mean plan speedup: 1.496x
- Minimum / p05 / p95 / maximum speedup: 0.184x / 0.456x / 4.466x / 4.557x

The primary robustness criterion is strict: every expected rewrite must pass exact-result validation, finish every repetition, and have a median runtime below the corresponding original median.
