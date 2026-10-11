# BRX 0 — especificação inicial da linguagem

## Identidade e limite

BRX é a linguagem de programação que estamos definindo. Esta especificação descreve o significado dos arquivos `.brx`; não é o próprio mecanismo que os executa. Para provar a sintaxe sem usar C ou runtime de bibliotecas, o primeiro executor (`brx0`) está escrito manualmente em assembly x86-64 e usa chamadas de sistema Linux. O bootstrap precisa de GNU `as` e `ld` para ser montado e ligado. Isso evita C e libc nesta versão, mas não elimina a cadeia de ferramentas inicial.

## Modelo do programa

Um arquivo BRX 0 é uma sequência de comandos, um por linha. Espaços e tabulações antes do comando são ignorados. `#` inicia comentário até o fim da linha. A primeira versão é deliberadamente de inteiros com sinal de 64 bits e texto literal entre aspas duplas.

```brx
run "meu_programa"       # rótulo opcional, sem efeito na execução
var pontos:num = 12      # declara ou redefine uma variável
out "pontos:"            # escreve texto seguido de nova linha
out pontos                # escreve o valor numérico
pontos += 3
pontos -= 1
pontos *= 2
pontos /= 2
pontos = -9
```

## Regras semânticas implementadas

- Variáveis são identificadores ASCII (letras, dígitos e `_`), com nome de até 63 bytes. Há espaço para 64 nomes por programa.
- `var nome:num = inteiro` armazena inteiro assinado de 64 bits. A anotação `:num` pode ser omitida.
- `nome = inteiro` substitui o valor; `+=`, `-=`, `*=` e `/=` atualizam o valor existente. Divisão é inteira e truncada em direção a zero.
- `out "texto"` escreve os bytes do literal até a aspa de fechamento; escapes ainda não existem. `out nome` escreve o valor numérico.
- `run "rótulo"` é metadado ignorado pelo executor inicial.
- Linhas iniciadas por `#` e linhas vazias são ignoradas.
- Arquivo de entrada: até 65.535 bytes; runtime: Linux x86-64.

## Ainda não implementado

Expressões gerais (como `a + b` à direita de uma atribuição), números decimais, strings como valores de variáveis, booleanos, condicionais, laços, funções, listas, escopos, entrada do usuário, diagnóstico com número de linha, outras arquiteturas e sistema operacional. Esses recursos serão incorporados por etapas, depois de testes de cada fase.

## Roteiro técnico

1. Estabilizar leitor de arquivo, declarações, atribuições numéricas e saída via syscall.
2. Criar tokenizador e parser de expressões com precedência.
3. Criar representação de instruções/AST e condições/loops/funções.
4. Escrever o compilador do BRX em BRX quando a linguagem puder representar buffers, laços, funções e emissão de bytes.
5. Compilar o compilador BRX com o bootstrap anterior; comparar saídas e manter testes de reprodução (bootstrap/auto-hospedagem).

A etapa 4 não apaga retroativamente o bootstrap: cada compilador auto-hospedado depende de uma versão anterior confiável que o compilou.
