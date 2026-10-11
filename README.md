# BRX — linguagem e máquina virtual em construção

BRX é uma linguagem própria em desenvolvimento. Seu bootstrap inicial `brx0` e o runtime virtual `brxvm0` foram escritos manualmente em assembly x86-64, sem C, libc ou bibliotecas de terceiros. O código-fonte dos executores não usa outra linguagem de alto nível. O build inicial ainda usa GNU `as` e `ld`; os programas executáveis ELF deste estágio dependem do Linux x86-64 e de suas syscalls.

## Duas camadas executáveis

- **Fonte `.brx`:** `brx0` lê e interpreta diretamente um subconjunto textual da linguagem.
- **Executável virtual `.brxe`:** `brxvm0` lê um arquivo binário com cabeçalho BRXE e executa os opcodes da VM BRX.

BRXE é o caminho para que um mesmo aplicativo rode sem recompilação em qualquer host que disponha de um runtime BRX compatível. O runtime/adaptador precisa ser portado e instalado em cada sistema; não estamos afirmando que já há suporte a qualquer OS, CPU ou GPU. Consulte a [especificação BRXE](docs/FORMATO-EXECUTAVEL-BRX.md), a [arquitetura e fallback de hardware](docs/ALVOS-E-BACKENDS.md) e o [relatório de pesquisa aprofundada](docs/PESQUISA-APROFUNDADA-BRXE.md).

O requisito de hardware é que futuros runtimes detectem automaticamente as capacidades e escolham o melhor adapter disponível: específico/acelerado, genérico exposto pelo host, fallback básico/software ou erro legível. A Microsoft documenta um exemplo real: Basic Display Adapter funciona como driver genérico para recursos básicos quando o driver do fabricante não está disponível; os recursos/performance são menores [documentação](https://support.microsoft.com/en-us/windows/hardware/display-graphics/microsoft-basic-display-adapter-in-windows). Isso não representa um driver universal. A sondagem/HAL BRX ainda **não está implementada** em `brxvm0`.

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

`examples/hello.brxe` é um módulo binário que grava um valor num slot local, carrega-o, soma outro valor e imprime o resultado e uma constante de texto. Saída:

```text
42
BRX VM OK
```

O runtime BRXE aceita arquivos de até 131071 bytes e executa `HALT`, `PUSH_I64`, `LOAD_LOCAL`, `STORE_LOCAL`, aritmética inteira, `PRINT_I64` e `PRINT_CONST`. Antes de executar, verifica a estrutura linear de todas as instruções, limites de operandos, profundidade da pilha e inicialização de locais, evitando saída parcial para módulos malformados. **Ainda faltam** saltos, funções, compilador `.brx`→`.brxe`, sondagem/HAL e ports do runtime a outros sistemas e arquiteturas.

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

A suíte monta os dois executores e testa CPUID, expressões fonte, módulo BRXE com local, saída e rejeição de arquivo truncado, opcode inválido tardio, underflow, local não inicializado e overflow de divisão.
