# BRX — linguagem e máquina virtual em construção

BRX é uma linguagem própria em desenvolvimento. Seu bootstrap inicial `brx0` e o runtime virtual `brxvm0` foram escritos manualmente em assembly x86-64, sem C, libc ou bibliotecas de terceiros. O código-fonte dos executores não usa outra linguagem de alto nível. O build inicial ainda usa GNU `as` e `ld`; os programas executáveis ELF deste estágio dependem do Linux x86-64 e de suas syscalls.

## Duas camadas executáveis

- **Fonte `.brx`:** `brx0` lê e interpreta diretamente um subconjunto textual da linguagem.
- **Executável virtual `.brxe`:** `brxvm0` lê um arquivo binário com cabeçalho BRXE e executa os opcodes da VM BRX.

BRXE é o caminho para que um mesmo aplicativo rode sem recompilação em qualquer host que disponha de um runtime BRX compatível. O runtime/adaptador precisa ser portado e instalado em cada sistema; não estamos afirmando que já há suporte a qualquer OS, CPU ou GPU. O estado e os opcodes estão descritos na [especificação BRXE](docs/FORMATO-EXECUTAVEL-BRX.md).

## Construir e executar

```sh
# Interpretador do texto BRX
as --64 src/boot/brx0.s -o /tmp/brx0.o
ld -o brx0 /tmp/brx0.o
./brx0 examples/boot.brx

# Runtime da VM BRXE
as --64 src/vm/brxvm0.s -o /tmp/brxvm0.o
ld -o brxvm0 /tmp/brxvm0.o
./brxvm0 examples/hello.brxe
```

`examples/hello.brxe` é um módulo binário que executa duas constantes inteiras, soma-as, imprime o resultado e depois imprime uma constante de texto. Saída:

```text
42
BRX VM OK
```

O runtime BRXE neste estágio executa `HALT`, `PUSH_I64`, aritmética inteira, `PRINT_I64` e `PRINT_CONST`. Ele valida a assinatura/versão/tamanhos do módulo e limita a pilha. **Ainda falta** o compilador `.brx`→`.brxe`, variáveis/controle de fluxo no bytecode e ports do runtime a outros sistemas e arquiteturas.

## Subconjunto fonte BRX

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

`brx0` mantém variáveis numéricas globais, avalia expressões inteiras (`+ - * / %`, com precedência usual), executa atribuições (`= += -= *= /=`), imprime texto/números e consulta o fabricante de CPU via CPUID. A [especificação BRX 0](docs/ESPECIFICACAO-0.md) fixa gramática e limites.

## Pesquisa, arquitetura e testes

- [Pesquisa: como criar uma linguagem do zero](docs/ESTUDO-COMO-CRIAR-UMA-LINGUAGEM.md) — especificação, lexer, parser, semântica, variáveis, bootstrap, VM e hardware, com referências.
- [Arquitetura do formato BRXE](docs/FORMATO-EXECUTAVEL-BRX.md) — ISA virtual, módulo binário e estado implementado.
- [Alvos e backends](docs/ALVOS-E-BACKENDS.md) — separar formato BRX, runtime/adaptador de host e GPU.
- [Como a BRX conversa com hardware](docs/CAMINHO-ATE-O-HARDWARE.md) — CPU, syscalls, memória e driver.
- [Skill reutilizável de criação](skills/brx-language-bootstrap/SKILL.md) — workflow prático para desenvolver linguagens com bootstrap transparente.

Executar todos os testes:

```sh
tests/smoke.sh
```

A suíte monta os dois executores e testa CPUID, expressões fonte, módulo BRXE, saída e rejeição de arquivo truncado, opcode desconhecido e underflow.
