# Journal scan capacity note

**Date:** 2026-06-23
**Scope:** issue #67 — decide whether full-journal `jq -s` scans in `lib/journal.sh stats` need an index/cache.

## Result

No cache/index needed at current scale. Synthetic 10k-row journals run `journal.sh stats` in ~0.17s median locally.

## Benchmark

Command shape:

```bash
AGENT_FLEET_JOURNAL=/tmp/journal-<n>.jsonl bash lib/journal.sh stats
```

Synthetic rows included current schema fields, mixed `run_kind`, baseline fields, and judged rows so the stats path exercised its normal aggregations.

Seven timed reps after one warm-up:

| Rows | Median | Max observed | Mean |
|---:|---:|---:|---:|
| 100 | 0.0246s | 0.0274s | 0.0247s |
| 1,000 | 0.0334s | 0.0353s | 0.0338s |
| 10,000 | 0.1654s | 0.1816s | 0.1697s |

## Interpretation

At Phase 2 target scale (50 judged rooms, low hundreds of total runs), scan cost is noise. Even 10k rows is below human-visible latency for an interactive CLI.

Linear extrapolation from 10k rows suggests:

- ~50k rows: likely <1s.
- ~100k rows: likely 1-2s.

Actual growth should be measured before optimizing because `jq -s` cost depends on row size, machine, and filesystem.

## Threshold for adding an index/cache

Do not add a cache now. Revisit only if either condition holds on a representative local journal:

1. `bash lib/journal.sh stats` p95 exceeds 1s at normal use scale.
2. CI/test fixtures need >2s per stats call because generated journals grew large.

If threshold is hit, prefer a small derived summary cache with explicit invalidation over changing the JSONL source of truth. Keep JSONL append-only semantics intact.
