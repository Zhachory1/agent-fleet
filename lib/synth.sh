#!/usr/bin/env bash
# Deterministic synthesis check: reads persona verdicts (one per line: "<persona> <verdict>")
# from stdin. Prints:
#   FALSE-CONSENSUS      — all verdicts identical (warn: unanimity is not safety)
#   SPLIT                — a clear plurality exists; lists DISSENT: lines (non-majority)
#   SPLIT-NO-MAJORITY    — top two verdicts tie; lists VERDICT: lines (no arbitrary "majority")
#   NO-INPUT (exit 1)    — empty/blank input
set -euo pipefail
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-V" ]; then
  cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo unknown; exit 0
fi
# synth.sh is pure bash/awk/sort — no jq dependency
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
  converged)
    # stdin: prev block, exactly ONE "---" line, curr block. Lines: "<persona> <verdict> <issue_count>".
    raw="$(cat)"; [ -n "$(printf '%s' "$raw" | tr -d '[:space:]')" ] || { echo NO-INPUT; exit 1; }
    seps="$(printf '%s\n' "$raw" | grep -c '^---$' || true)"
    [ "$seps" = "1" ] || { echo NO-INPUT; exit 1; }          # exactly one separator, else malformed
    first="$(printf '%s\n' "$raw" | sed '/^[[:space:]]*$/d' | head -1)"
    [ "$first" != "---" ] || { echo NO-INPUT; exit 1; }      # separator-first = empty prev block
    prev="$(printf '%s\n' "$raw" | sed -n '1,/^---$/p' | sed '/^---$/d' | sed '/^[[:space:]]*$/d')"
    curr="$(printf '%s\n' "$raw" | sed -n '/^---$/,$p' | sed '/^---$/d' | sed '/^[[:space:]]*$/d')"
    [ -n "$prev" ] && [ -n "$curr" ] || { echo NO-INPUT; exit 1; }
    # curr majority verdict (plurality). Empty => malformed curr (lines lacking a verdict field).
    maj="$(printf '%s\n' "$curr" | awk '{print $2}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"
    [ -n "$maj" ] || { echo NO-INPUT; exit 1; }
    pv() { printf '%s\n' "$prev" | awk -v p="$1" '$1==p{print $2; exit}'; }
    pc() { printf '%s\n' "$prev" | awk -v p="$1" '$1==p{print $3; exit}'; }
    flips=0; degraded=0; changed=0
    while read -r p v c; do
      [ -n "$p" ] || continue
      ov="$(pv "$p")"; oc="$(pc "$p")"
      [ -n "$ov" ] && [ "$ov" != "$v" ] && changed=1                              # guard: missing prev != change
      if [ -n "$ov" ] && [ "$ov" != "$maj" ] && [ "$v" = "$maj" ]; then          # moved TO majority
        flips=$((flips+1))
        if [[ "$c" =~ ^[0-9]+$ ]] && [[ "$oc" =~ ^[0-9]+$ ]] && [ "$c" -lt "$oc" ]; then degraded=1; fi # ...while dropping issues (both counts numeric)
      fi
    done <<< "$curr"
    if [ "$flips" -ge 2 ] || [ "$degraded" = 1 ]; then echo SUSPICIOUS-FLIP
    elif [ "$changed" = 1 ]; then echo CHANGED
    else echo CONVERGED
    fi
    ;;
  *) echo "usage: synth.sh {flag | converged}  (flag: '<persona> <verdict>' lines; converged: prev block, '---', curr block of '<persona> <verdict> <issue_count>')" >&2; exit 1;;
esac
