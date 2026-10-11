# Implementar a linguagem BRX

## Pipeline manual recomendado

```text
fonte BRX -> scanner/tokens -> parser -> AST/IR -> semântica -> emissor BRXE -> runtime BRXE -> HAL/host
```

- **Scanner:** agrupar bytes em identificadores, palavras-chave, operadores, literais e posição de origem.
- **Parser:** aplicar a gramática escrita a tokens e construir AST; recursive descent/precedence climbing manual evita gerador.
- **Semântica:** resolver nomes/tipos/escopo e erros em regras versionadas.
- **Emissor:** traduzir AST/IR para opcodes BRXE definidos, sem vazar ISA/OS.
- **Runtime:** validar formato e executar opcodes; abstrair host services pela HAL.
- **Adaptador:** implementar I/O e acesso autorizado aos drivers para cada host.

## Subconjunto de fonte executável

```brx
run "calculo"
hw cpu
var base:num = 10
var ajuste:num = 3 * 4
var resultado:num = base + ajuste
resultado = resultado * 2 - 4
out "resultado"
out resultado
```

O interpretador `src/boot/brx0.s` em Linux x86-64 lê linha a linha, aceita até 65.535 bytes, identificadores globais até 63 bytes e 64 variáveis inteiras de 64 bits; calcula `+ - * / %` com precedência multiplicativa; faz `= += -= *= /=`; imprime literais/números; ignora comentário `#` e metadata `run`; implementa `hw cpu` via CPUID leaf 0. Sem parênteses, booleanos ou funções ainda.

## Execução BRXE implementada

`src/vm/brxvm0.s` é um runtime x86-64/Linux escrito manualmente em assembly. Valida módulo BRXE antes de executar e suporta: `HALT`, `PUSH_I64`, `LOAD_LOCAL`, `STORE_LOCAL`, `ADD_I64`, `SUB_I64`, `MUL_I64`, `DIV_I64`, `MOD_I64`, `PRINT_I64`, `PRINT_CONST`. O cabeçalho BRXE inclui magia `BRXE`, version=1, flags, code_size e data_size little-endian. O loader lê em loop até EOF, repete `EINTR`, permite no máximo 131071 bytes e prova que não há byte extra; também exige correspondência exata entre arquivo e cabeçalho. Pilha e 256 slots locais têm limites fixos; a verificação linear checa largura de operandos, stack-depth, ranges de literais e leitura de local previamente inicializado. `examples/hello.brxe` grava/carrega um valor local e imprime `42` e `BRX VM OK`.

A suíte `tests/smoke.sh` monta `brx0` e `brxvm0`, testa CPUID/expressões/saída, módulo truncado, arquivos no tamanho exato máximo e um byte acima, opcode desconhecido (inclusive opcode inválido após instruções que produziriam saída), underflow, local não inicializado e divisão com overflow. Build via GNU `as` + `ld`; os binários testados são ELF sem `PT_INTERP`. Nenhum C, libc ou biblioteca de terceiros faz parte dos dois executores.

## Não implementado

- Compilador fonte `.brx` → `.brxe`.
- Saltos, fluxo de controle, funções e chamadas.
- Inteiros com política final de overflow; diagnóstico de linha para VM; módulos/imports/capabilities.
- Runtimes compatíveis por outros OS/ISAs.
- `BRX-HAL`, CPU_INFO portável e GPU.
- Auto-hospedagem.

## Ordem sugerida de trabalho

1. Estabilizar parser/gramática textual e erros de fonte.
2. Fixar versão formal do header/opcodes BRXE, traps, limites e resultado de overflows.
3. Adicionar branches/labels e ampliar o verificador para estados de pilha por bloco/aresta.
4. Implementar emissor BRX→BRXE que compile expressões/saídas; comparar execução fonte vs VM.
5. Portar runtime pequeno a outro OS/ISA; testar o mesmo `.brxe` sem recompilar.
6. Criar imports versionados `BRX.IO`/`BRX.HAL` por capability, e adaptar drivers.
7. Adicionar funções/stack frames e front-end features; depois escrever compilador em BRX e bootstrap.

## Testes do parser/VM

Tokens e posições, maximal munch, precedência (`2 + 3*4`), associatividade (`8-3-2`), variável ausente, divisão por zero, bounds do header, magic/version inválidas, código truncado, opcode não suportado, stack underflow/overflow, operand bounds, saída comum entre hosts, imports não atendidos e capability negada.
