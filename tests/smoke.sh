#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
as --64 "$ROOT/src/boot/brx0.s" -o "$TMP/brx0.o"
ld -o "$TMP/brx0" "$TMP/brx0.o"
"$TMP/brx0" "$ROOT/examples/boot.brx" > "$TMP/output"
printf 'valor inicial\n10\nresultado\n26\n' > "$TMP/expected"
cmp "$TMP/expected" "$TMP/output"
cat > "$TMP/error.brx" <<'EOF'
out ausente
EOF
if "$TMP/brx0" "$TMP/error.brx" > "$TMP/error.out" 2> "$TMP/error.log"; then
  echo 'Falha: variável não declarada deveria ser erro' >&2
  exit 1
fi
grep -q 'BRX erro:' "$TMP/error.log"
echo 'BRX 0: testes passaram'
