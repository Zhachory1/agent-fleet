#!/usr/bin/env bash
# Deterministic synthesis check: reads persona verdicts (one per line: "<persona> <verdict>")
# from stdin, prints "FALSE-CONSENSUS" if all identical, else "SPLIT", and lists dissenters.
set -euo pipefail
cmd="${1:-}"; shift || true
case "$cmd" in
  flag)
    verdicts="$(cat)"
    uniq_v="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort -u | wc -l | tr -d ' ')"
    if [ "$uniq_v" = "1" ]; then echo "FALSE-CONSENSUS"; else
      echo "SPLIT"
      # dissenters = verdicts != majority
      maj="$(printf '%s\n' "$verdicts" | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
      printf '%s\n' "$verdicts" | awk -v m="$maj" '$2!=m {print "DISSENT: "$0}'
    fi
    ;;
  *) echo "usage: synth.sh flag  (stdin: '<persona> <verdict>' lines)" >&2; exit 1;;
esac
