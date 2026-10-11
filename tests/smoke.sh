#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
as --64 "$ROOT/src/boot/brx0.s" -o "$TMP/brx0.o"
ld -o "$TMP/brx0" "$TMP/brx0.o"
as --64 "$ROOT/src/vm/brxvm0.s" -o "$TMP/brxvm0.o"
ld -o "$TMP/brxvm0" "$TMP/brxvm0.o"
"$TMP/brx0" "$ROOT/examples/boot.brx" > "$TMP/output"
sed -n '1p' "$TMP/output" | grep -Eq '^CPU vendor: .{12}$'
printf 'resultado\n40\n' > "$TMP/expected"
tail -n 2 "$TMP/output" > "$TMP/tail"
cmp "$TMP/expected" "$TMP/tail"
cat > "$TMP/error.brx" <<'EOF'
out ausente
EOF
if "$TMP/brx0" "$TMP/error.brx" > "$TMP/error.out" 2> "$TMP/error.log"; then
  echo 'Falha: variável não declarada deveria ser erro' >&2
  exit 1
fi
grep -q 'BRX erro:' "$TMP/error.log"
cat > "$TMP/zero-div.brx" <<'EOF'
var x:num = 7 / 0
EOF
if "$TMP/brx0" "$TMP/zero-div.brx" > "$TMP/zero.out" 2> "$TMP/zero.log"; then
  echo 'Falha: divisão por zero deveria ser erro' >&2
  exit 1
fi
grep -q 'BRX erro:' "$TMP/zero.log"
"$TMP/brxvm0" "$ROOT/examples/hello.brxe" > "$TMP/vm.out"
printf '42\nBRX VM OK\n' > "$TMP/vm.expected"
cmp "$TMP/vm.expected" "$TMP/vm.out"
head -c 15 "$ROOT/examples/hello.brxe" > "$TMP/truncated.brxe"
if "$TMP/brxvm0" "$TMP/truncated.brxe" > "$TMP/truncated.out" 2> "$TMP/truncated.log"; then
  echo 'Falha: módulo BRXE truncado deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/truncated.log"
printf '\102\122\130\105\001\000\000\000\357\377\001\000\000\000\000\000' > "$TMP/exact-limit.brxe"
dd if=/dev/zero bs=131055 count=1 status=none >> "$TMP/exact-limit.brxe"
"$TMP/brxvm0" "$TMP/exact-limit.brxe" > "$TMP/exact-limit.out"
test ! -s "$TMP/exact-limit.out"
printf '\102\122\130\105\001\000\000\000\357\377\001\000\000\000\000\000' > "$TMP/oversized.brxe"
dd if=/dev/zero bs=131055 count=1 status=none >> "$TMP/oversized.brxe"
printf '\001' >> "$TMP/oversized.brxe"
if "$TMP/brxvm0" "$TMP/oversized.brxe" > "$TMP/oversized.out" 2> "$TMP/oversized.log"; then
  echo 'Falha: módulo maior que o limite deveria ser rejeitado' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/oversized.log"
cp "$ROOT/examples/hello.brxe" "$TMP/opcode.brxe"
printf '\377' | dd of="$TMP/opcode.brxe" bs=1 seek=16 conv=notrunc 2>/dev/null
if "$TMP/brxvm0" "$TMP/opcode.brxe" > "$TMP/opcode.out" 2> "$TMP/opcode.log"; then
  echo 'Falha: opcode desconhecido deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/opcode.log"
cp "$ROOT/examples/hello.brxe" "$TMP/late-opcode.brxe"
printf '\377' | dd of="$TMP/late-opcode.brxe" bs=1 seek=51 conv=notrunc 2>/dev/null
if "$TMP/brxvm0" "$TMP/late-opcode.brxe" > "$TMP/late-opcode.out" 2> "$TMP/late-opcode.log"; then
  echo 'Falha: opcode inválido tardio deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/late-opcode.log"
test ! -s "$TMP/late-opcode.out"
cp "$ROOT/examples/hello.brxe" "$TMP/underflow.brxe"
printf '\004' | dd of="$TMP/underflow.brxe" bs=1 seek=16 conv=notrunc 2>/dev/null
if "$TMP/brxvm0" "$TMP/underflow.brxe" > "$TMP/underflow.out" 2> "$TMP/underflow.log"; then
  echo 'Falha: underflow da pilha deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/underflow.log"
printf '\102\122\130\105\001\000\000\000\004\000\000\000\000\000\000\000\002\000\000\000' > "$TMP/uninitialized.brxe"
if "$TMP/brxvm0" "$TMP/uninitialized.brxe" > "$TMP/uninitialized.out" 2> "$TMP/uninitialized.log"; then
  echo 'Falha: leitura de local não inicializado deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/uninitialized.log"
printf '\102\122\130\105\001\000\000\000\004\000\000\000\000\000\000\000\002\000\001\000' > "$TMP/invalid-slot.brxe"
if "$TMP/brxvm0" "$TMP/invalid-slot.brxe" > "$TMP/invalid-slot.out" 2> "$TMP/invalid-slot.log"; then
  echo 'Falha: índice de local inválido deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/invalid-slot.log"
cp "$ROOT/examples/hello.brxe" "$TMP/invalid-const.brxe"
printf '\377' | dd of="$TMP/invalid-const.brxe" bs=1 seek=47 conv=notrunc 2>/dev/null
if "$TMP/brxvm0" "$TMP/invalid-const.brxe" > "$TMP/invalid-const.out" 2> "$TMP/invalid-const.log"; then
  echo 'Falha: faixa de literal inválida deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/invalid-const.log"
printf '\102\122\130\105\001\000\000\000\024\000\000\000\000\000\000\000\001\000\000\000\000\000\000\000\200\001\377\377\377\377\377\377\377\377\007\000' > "$TMP/div-overflow.brxe"
if "$TMP/brxvm0" "$TMP/div-overflow.brxe" > "$TMP/div-overflow.out" 2> "$TMP/div-overflow.log"; then
  echo 'Falha: overflow da divisão assinada deveria ser erro' >&2
  exit 1
fi
grep -q 'BRXE:' "$TMP/div-overflow.log"
if readelf -l "$TMP/brxvm0" | grep -q INTERP; then
  echo 'Falha: runtime BRXE não deveria depender de dynamic loader neste build' >&2
  exit 1
fi
echo 'BRX: bootstrap, CPUID, expressoes, runtime BRXE e traps passaram'
