#!/usr/bin/env bash
# Deterministic synthesis check: reads persona verdicts (one per line: "<persona> <verdict>")
# from stdin. Prints:
#   FALSE-CONSENSUS      — all verdicts identical (warn: unanimity is not safety)
#   SPLIT                — a clear plurality exists; lists DISSENT: lines (non-majority)
#   SPLIT-NO-MAJORITY    — top two verdicts tie; lists VERDICT: lines (no arbitrary "majority")
#   NO-INPUT (exit 1)    — empty/blank input
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  flag)
    verdicts="$(cat | sed '/^[[:space:]]*$/d')"          # drop blank lines
    [ -n "$verdicts" ] || { echo "NO-INPUT"; exit 1; }
    uniq_v="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')"
    if [ "$uniq_v" = "1" ]; then
      echo "FALSE-CONSENSUS"
    else
      counts="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort | uniq -c | sort -rn)"
      top1="$(printf '%s\n' "$counts" | sed -n '1p' | awk '{print $1}')"
      top2="$(printf '%s\n' "$counts" | sed -n '2p' | awk '{print $1}')"
      maj="$(printf '%s\n' "$counts" | sed -n '1p' | awk '{print $2}')"
      if [ -n "$top2" ] && [ "$top1" = "$top2" ]; then
        echo "SPLIT-NO-MAJORITY"                          # even split — no arbitrary majority
        printf '%s\n' "$verdicts" | awk '{print "VERDICT: "$0}'
      else
        echo "SPLIT"
        printf '%s\n' "$verdicts" | awk -v m="$maj" '$2!=m {print "DISSENT: "$0}'
      fi
    fi
    ;;
  *) echo "usage: synth.sh flag  (stdin: '<persona> <verdict>' lines)" >&2; exit 1;;
esac
