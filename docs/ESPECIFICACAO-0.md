# BRX 0 — gramática e semântica da linguagem

## Execução e base atual

BRX é a linguagem cujas regras definimos neste projeto. O executor `brx0` é a implementação inicial dessas regras em assembly x86-64, sem C, runtime C, libc ou bibliotecas de terceiros. Ele usa syscalls Linux para ler o arquivo e escrever a saída, e uma instrução CPUID nativa para ler o identificador de fabricante da CPU.

Esta versão é executada no Linux x86-64. Para criar o ELF inicial, são necessários GNU `as` e `ld`. Isso significa **sem bibliotecas externas**, mas não “sem ferramenta nenhuma”: CPU, ISA, formato ELF, kernel e assembler/linker já existem.

## Forma de um programa

O arquivo BRX é processado linha a linha. Cada comando ocupa uma linha. São ignorados espaços/tabs antes e depois de um comando; `#` inicia um comentário de linha.

```brx
run "calculo"
hw cpu
var base:num = 10
var ajuste:num = 3 * 4
var total:num = base + ajuste
total = total * 2 - 4
out "total:"
out total
```

## Gramática do subconjunto executável

```text
programa       := linha*
linha          := comentario | comando | vazia
comando        := run_string | hw_cpu | declaracao | atribuicao | saida_texto | saida_expr
run_string     := "run" STRING
hw_cpu         := "hw" "cpu"
declaracao     := "var" IDENT [":num"] "=" expressao
atribuicao     := IDENT ("=" | "+=" | "-=" | "*=" | "/=") expressao
saida_texto    := "out" STRING
saida_expr     := "out" expressao
expressao      := termo (("+" | "-") termo)*
termo          := primaria (("*" | "/" | "%") primaria)*
primaria       := inteiro_com_sinal | IDENT
```

Multiplicação, divisão e resto têm precedência maior que soma e subtração; operadores da mesma precedência são avaliados da esquerda para a direita. Parênteses, comparações e operadores lógicos ainda não fazem parte da gramática implementada.

## Regras atuais

- Valores são inteiros assinados de 64 bits; aritmética é realizada em registradores de 64 bits. `/` e `/=` fazem divisão inteira truncada em direção a zero. `%` calcula o resto. Divisão/remainder por zero encerra com erro.
- Identificadores aceitam ASCII (letras, dígitos e `_`), até 63 bytes; no máximo 64 variáveis globais.
- `var x:num = expressão` declara ou redefine `x`. `:num` é atualmente opcional e descritivo, pois a versão só tem valores numéricos.
- `x = expressão` substitui o valor; `+=`, `-=`, `*=` e `/=` combinam o valor atual com a expressão à direita.
- `out expressão` imprime o inteiro seguido por nova linha. `out "texto"` imprime bytes do literal sem as aspas, sem escapes, seguido por nova linha.
- `hw cpu` executa CPUID leaf 0 e imprime o texto de fabricante retornado em EBX, EDX, ECX. A CPU observada no sandbox pode ser virtualizada e não refletir a máquina física do usuário.
- `run "rótulo"` é metadado atualmente ignorado.
- Arquivo de entrada: até 65.535 bytes; identificadores e tabela de variáveis têm limites fixos nesta etapa.

## Próximas partes da linguagem

Ainda não estão implementados: literais de texto armazenados em variáveis, booleanos, condicionais, laços, funções, listas, escopos locais, entrada do usuário, decimais, escape de strings, tratamento de overflow, mensagens de erro com linha/coluna, backends além de Linux x86-64 e consultas específicas de GPU.

O próximo avanço do núcleo é adicionar comparação/booleanos e blocos (`if`/`end`), depois loops e funções com call stack. A linguagem deve ganhar a capacidade de manipular buffers e emitir bytes antes de iniciarmos um compilador escrito em BRX. Auto-hospedagem é uma meta posterior, construída sobre e testada contra um bootstrap anterior; ela não remove a dependência histórica do primeiro bootstrap.
