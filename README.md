# BRX — linguagem experimental

BRX é uma linguagem que estamos projetando do zero: nós definimos sua gramática e o significado dos comandos. O primeiro executor não é escrito em C; é um bootstrap manual em **assembly x86-64**, que usa chamadas diretas ao kernel Linux. Não usa libc nem bibliotecas de terceiros.

Isso não significa independência absoluta de ferramentas: o bootstrap ainda requer GNU `as` e `ld` para transformar assembly em executável ELF e roda sobre Linux x86-64. Veja [o caminho até o hardware](docs/CAMINHO-ATE-O-HARDWARE.md) para entender o percurso.

## Montar e executar

```sh
as --64 src/boot/brx0.s -o /tmp/brx0.o
ld -o brx0 /tmp/brx0.o
./brx0 examples/boot.brx
```

Saída esperada:

```text
valor inicial
10
resultado
26
```

## BRX 0

```brx
run "meu_programa"
var pontos:num = 12
out "pontos:"
out pontos
pontos += 3
pontos *= 2
out pontos
```

A primeira versão executável aceita inteiros assinados, declaração/atribuição de variáveis, operações compostas `+=`, `-=`, `*=`, `/=`, saída de números/textos literais, comentários `#` e linhas `run` opcionais. Um comando ocupa uma linha. Detalhes e limites estão na [especificação BRX 0](docs/ESPECIFICACAO-0.md).

## Testes

```sh
tests/smoke.sh
```

O protótipo é intencionalmente pequeno. Expressões gerais, texto/booleanos como valores, `if`, laços, funções, listas, REPL, diagnósticos completos e outras arquiteturas ainda não estão implementados. Próxima etapa planejada: parser e expressões; depois controle de fluxo e funções; finalmente, um compilador escrito em BRX e o processo de auto-hospedagem.
