# BRX

BRX é uma linguagem experimental em português, criada neste repositório. A primeira versão é um interpretador pequeno escrito do zero em C: o lexer, o parser e a avaliação das expressões são próprios, sem frameworks, dependências de terceiros ou bibliotecas adicionais. O executável usa apenas a biblioteca padrão/runtime C do sistema. Um compilador C é necessário para construir o interpretador — uma linguagem nova precisa de uma implementação hospedeira até que exista um compilador próprio.

## Compilar

```sh
cc -std=c11 -O2 brx.c -o brx
```

## Executar

```sh
./brx exemplos/ola.brx
```

## Exemplo

```brx
// Comentários começam com duas barras
let nome = "mundo";
let resposta = 6 * 7;
print("Olá, " + nome);
print(resposta);

if (resposta == 42) {
  print(true);
} else {
  print(false);
}
```

## Sintaxe nesta versão

- Declaração imutável? **Não**: `let nome = expressão;` declara; `nome = expressão;` atualiza uma variável já declarada.
- Tipos: número, texto, booleanos (`true`/`false`) e `null`.
- Operadores: `+`, `-`, `*`, `/`, `%`, comparações, igualdade, `&&`, `||` e `!`.
- Saída: `print(expressão);`.
- Condicional: `if (condição) { ... } else { ... }`.
- Comentários de linha: `// ...`.

O escopo inicial é deliberadamente pequeno: não há funções, arrays, entrada interativa nem laços executáveis ainda (`while` está reservado, mas não implementado). Erros mostram a linha e interrompem a execução. Esta é uma base inicial para evoluir a gramática e a implementação.
