#!/usr/bin/env bash
# Test: portability-pattern guard for known BSD/GNU footguns (#54).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
note() { printf '  %s\n' "$*"; }

portable_allowed() {
  local line="$1"
  [[ "$line" =~ ^[[:space:]]*# ]] && return 0
  [[ "$line" == *'# portable:'* ]]
}

scan_file() {
  local file="$1"
  local failed=0
  local line_no line
  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: non-portable stat -f; use stat -c first with BSD fallback or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])stat[[:space:]]+-f([[:space:]]|$)' "$file" || true)

  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: non-portable sed -i; BSD/GNU differ, use a temp file or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])sed[[:space:]]+-i([[:space:]]|$|[^[:alnum:]_])' "$file" || true)

  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: grep -P is not available on BSD grep; use grep -E/awk or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])grep[[:space:]][^#]*-P' "$file" || true)

  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: readlink -f is GNU-only; use a portable path resolver or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])readlink[[:space:]]+-f([[:space:]]|$)' "$file" || true)

  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: xargs -r is GNU-only; guard empty input explicitly or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])xargs[[:space:]]+-r([[:space:]]|$)' "$file" || true)

  while IFS=: read -r line_no line; do
    portable_allowed "$line" && continue
    printf '%s:%s: base64 -w is GNU-specific; strip newlines portably or add # portable: reason\n' "$file" "$line_no"
    failed=1
  done < <(grep -nE '(^|[^[:alnum:]_])base64[[:space:]][^#]*-w[0-9]*' "$file" || true)

  return "$failed"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BAD="$WORK/bad.sh"
GOOD="$WORK/good.sh"
cat > "$BAD" <<'EOF'
mtime=$(stat -f %m "$lockdir")
EOF
cat > "$GOOD" <<'EOF'
mtime=$(stat -c %Y "$lockdir" || stat -f %m "$lockdir") # portable: GNU stat -c first, BSD stat -f fallback
EOF

set +e
BAD_OUT=$(scan_file "$BAD" 2>&1)
BAD_RC=$?
GOOD_OUT=$(scan_file "$GOOD" 2>&1)
GOOD_RC=$?
set -e
[ "$BAD_RC" = "1" ] && echo "$BAD_OUT" | grep -q 'non-portable stat -f' \
  && note "PASS catches original stat -f regression shape" \
  || { echo "FAIL: bad fixture should be rejected (rc=$BAD_RC out='$BAD_OUT')"; exit 1; }
[ "$GOOD_RC" = "0" ] && [ -z "$GOOD_OUT" ] \
  && note "PASS allows # portable justification" \
  || { echo "FAIL: good fixture should pass (rc=$GOOD_RC out='$GOOD_OUT')"; exit 1; }

fail=0
while IFS= read -r file; do
  if ! scan_file "$file"; then
    fail=1
  fi
done < <(find "$DIR/lib" "$DIR/test" -type f -name '*.sh' ! -path "$DIR/test/test_portability_patterns.sh" -print; printf '%s\n' "$DIR/install.sh")

[ "$fail" = "0" ] || exit 1
echo "PASS test_portability_patterns"
