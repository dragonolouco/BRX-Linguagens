# Estudo: como criar uma linguagem de programação do zero

**Projeto relacionado:** BRX. **Data da síntese:** 11 de outubro de 2026. **Objetivo:** explicar o projeto sem ocultar ferramentas, runtimes, sistemas ou hardware preexistentes e orientar uma linguagem/executável virtual próprios.

## 1. O que significa criar uma linguagem

Uma linguagem é um **contrato**: a sintaxe define quais textos são programas; a semântica define o que esses programas fazem. A implementação — interpretador, compilador, bytecode, AST ou algoritmo de parsing — realiza esse contrato, mas não é a definição da linguagem. Referências normativas como Python e ECMAScript separam gramática/estrutura de regras de execução [1] [2].

Por isso, construir uma linguagem própria de verdade envolve mais que inventar palavras. Precisamos especificar exemplos válidos e inválidos, significado de variáveis, tipos, precedência, escopo, chamadas, erros, I/O e como o programa vai executar. Começamos com pouco, testamos e só então adicionamos estruturas.

> A linguagem pode ser independente do sistema operacional. A **implementação executável**, o runtime e os dispositivos precisam conversar com uma máquina concreta, diretamente ou por uma camada de compatibilidade.

## 2. Pipeline escrito à mão

Uma implementação manual costuma separar etapas assim:

```text
bytes do arquivo
    -> lexer/scanner: agrupa caracteres em tokens
    -> parser: valida a gramática e constrói uma AST
    -> semântica: resolve nomes, escopos e tipos
    -> executor: interpreta AST/bytecode ou produz executável
    -> runtime/adaptador: memória, I/O, OS e dispositivos
```

### Lexer e tokens

O lexer percorre o arquivo e reconhece identificadores, palavras-chave, números, textos, operadores, comentários e separadores. Um token precisa ter uma categoria, conteúdo/valor e posição (linha/coluna ou span) para diagnósticos. Regras como encoding, espaços, comentário, final de linha, escape de aspas e precedência de operadores longos devem ser explícitas. **Maximal munch** é a regra de consumir o lexema válido mais longo; por exemplo, reconhecer `+=` como token composto em vez de `+` e `=` separados [3].

### Gramática e parser

Uma gramática descreve, por produções, quais sequências de tokens são válidas. Por exemplo, uma gramática de expressão pode dizer que produto contém primárias e que soma combina produtos; isso faz `2 + 3 * 4` significar `2 + (3 * 4)`. O parser pode ser uma função por produção (recursive descent), feito manualmente sem gerador. A gramática precisa não ser ambígua ou declarar como resolver precedência e associatividade [4].

O parser produz uma árvore de sintaxe (AST), não necessariamente os mesmos caracteres ou parênteses da fonte. Uma expressão `a + b * c` vira um nó `+` cuja direita é um nó `*`; daí o executor consegue seguir a regra de precedência sem adivinhá-la.

### Semântica, variáveis e tipos

Definir uma variável implica pelo menos nome, valor, tipo, momento de inicialização, escopo e regras de leitura/atribuição. Uma tabela de bindings mapeia cada nome a um valor; para escopo léxico pode haver um ambiente local ligado ao ambiente externo. Uma função/closure futura deve capturar o ambiente onde foi declarada, não o ambiente do chamador [5].

Decisões a fixar antes de implementar: `var` pode ser redefinido? A atribuição a nome ausente cria variável? Inicialização pode ler a própria variável? Variáveis internas ocultam globais? Tipos convertem implicitamente? A ordem de avaliação dos argumentos é esquerda→direita? `if` avalia apenas um ramo? Divisão por zero é trap? Overflows envolvem, saturam ou geram erro? Não existe resposta universal; a especificação escolhe.

Tipos estáticos podem rejeitar certos erros antes da execução, mas “bem tipado” não significa “nunca falha”: o programa ainda pode não terminar, dividir por zero ou exceder recursos. Artigos didáticos baseiam garantias limitadas em progresso e preservação, sob hipóteses sobre semântica/runtime [6].

## 3. Especificação antes de crescer o código

Versão inicial deve registrar:

1. codificação, tokens, comentários e EOF;
2. gramática EBNF e precedência/associatividade;
3. formas da AST e literais;
4. tipos e regras de compatibilidade;
5. criação/leitura/atualização de variáveis e escopos;
6. ordem de avaliação, efeitos, chamadas e retornos;
7. mensagens/categorias de erro e limites de recursos;
8. o que ainda não está definido ou implementado.

Cada regra precisa de um teste positivo, um negativo e resultado esperado. A implementação pode usar outros detalhes internos — desde que produza os resultados da especificação.

## 4. O formato executável que você imaginou

O seu conceito se encaixa em uma **máquina virtual própria**: BRX define uma ISA virtual, um formato binário de módulos e sua semântica. Compila-se um aplicativo para `.brxe`; esse mesmo arquivo pode rodar sem recompilação em computadores com uma implementação compatível da VM. Java define instruções bytecode/class-file sem exigir uma CPU única [7]. WebAssembly define uma ISA virtual, codificação binária, validação e semântica e, deliberadamente, deixa a integração com I/O/ambiente para APIs de embedding [8].

```text
programa-fonte BRX -> compilador BRX -> executável virtual .brxe
                                           ↓
                         runtime BRX portado para o host
                                           ↓
                             CPU, memória, OS e drivers
```

Assim, o aplicativo pode não precisar conhecer Windows/Linux/macOS: chama serviços estáveis da BRX. **O runtime**, entretanto, precisa ser instalado/portado para esses sistemas e fazer a adaptação. Um `.brxe` sem runtime não é instrução que uma CPU comum execute diretamente. Um runtime poderia interpretar bytecode ou JIT-compilá-lo.

O mesmo módulo só funciona em hosts que suportem a versão do bytecode e as capacidades importadas. Por exemplo, um app que exija `BRX.GFX` precisa de runtime com adaptador para a API gráfica e de driver compatível. O formato virtual continua o mesmo, mas o port do runtime e os drivers não são iguais entre sistemas.

## 5. Conversa com CPU, RAM e GPU

A CPU executa seu conjunto de instruções nativo; não conhece palavras inventadas como `var` ou `out`. Um runtime feito para x86-64 é uma sequência x86-64; outro runtime pode ser feito para ARM64. Syscalls e convenções de chamada dependem da ABI e do OS. O bootstrap BRX atual demonstra `CPUID` para informação de fabricante em x86, mas isso não é uma operação universal para toda arquitetura [9] [10]. Em VM de sistema, CPU física pode aparecer mascarada/virtualizada.

Quando o runtime BRX está hospedado num OS, sua RAM de processo é geralmente **memória virtual concedida pelo OS**. Ele não ganha acesso arbitrário a RAM física só porque executa programas em sua própria pilha. Operações privilegiadas passam por serviços autorizados do sistema.

Com drivers instalados, o modelo desejado pelo usuário é viável no nível do aplicativo: criar uma **BRX-HAL** com pedidos como `cpu.info`, `gpu.create_surface`, `gpu.submit` e `audio.play`. Runtime BRX converte a operação para a interface de driver disponível no host. Se driver/adaptador, permissões e recurso necessários existem, o app não precisa saber a syscall/OS específica.

Para adaptação automática, o runtime deve enumerar as interfaces e capabilities anunciadas pelo host e escolher, para cada função, o melhor backend instalado: específico/acelerado, genérico fornecido pelo OS, básico/software, ou erro explícito. O programa pode pedir capability obrigatória ou opcional e degradar se a opcional faltar. A Microsoft documenta o Basic Display Adapter genérico para funções gráficas básicas quando o driver do fabricante está ausente; drivers específicos ampliam desempenho/recursos [18] [19]. Isso é um fallback por classe/OS, não prova que exista um driver genérico para todo hardware. O runtime não deve instalar drivers nem elevar permissões.

O driver já instalado não implica acesso bruto ao hardware. Drivers executam parte privilegiada e controlam buffers, memória, sincronização e comandos. Linux DRM documenta esse papel e APIs UAPI por driver [11] [12]. GPU tem ISA e formatos de comando por fabricante e geração; manuais AMD RDNA/CDNA são específicos de família [13].

> “Conversa direta com o hardware” pode significar que o aplicativo BRX usa sua própria API abstrata, cujo runtime fala com drivers instalados. Se significar acesso físico sem OS/driver, BRX precisa assumir kernel/firmware/driver e privilégios — praticamente criar um sistema operacional. São dois objetivos diferentes.

## 6. O que “100% do zero” pode significar

É razoável exigir que o núcleo BRX não use **bibliotecas de terceiros** e não seja implementado em C ou outra linguagem de alto nível. Ainda assim, qualquer runtime inicial tem de nascer por algum mecanismo executável. Escrevê-lo em assembly evita C/libc no código, mas um assembler/linker e o OS continuam na cadeia inicial. Escrever o bytecode manualmente remove o assembler de uma etapa, mas não remove quem o carrega nem a CPU.

**Auto-hospedagem** significa que um compilador BRX é escrito em BRX e pode compilar seu próprio fonte. Isso é conquistado por bootstrap: um compilador anterior constrói o novo. Projetos como Rust, Go e GCC documentam estágios anteriores/ferramentas seed [14] [15] [16]. Formulação honesta: “BRX é auto-hospedada depois do seed S”. Isso não quer dizer que nenhuma linguagem/ferramenta existiu na história do projeto.

Builds reproduzíveis e comparação de estágios ajudam a auditar a toolchain. Eles não provam sozinhos que o compilador, fonte, kernel e hardware estão livres de comportamento malicioso; Ken Thompson descreveu a limitação de confiar somente no source do compilador [17].

## 7. Evolução sugerida para a BRX

1. Fechar o subconjunto textual BRX atual e ampliar testes.
2. Formalizar BRXE v1: cabeçalho, endian, limites, opcodes, stack/traps e compatibilidade.
3. Ampliar o interpretador BRXE com saltos e funções; 256 slots locais já foram implementados no subset atual.
4. Construir AST/IR no front-end e compilador manual BRX→BRXE, sem bibliotecas externas.
5. Comparar execução do fonte e do bytecode para todos os exemplos.
6. Portar `brxvm0` para outro OS/ISA e demonstrar o **mesmo `.brxe`**, sem recompilação.
7. Definir/importar serviços host `BRX.IO`/`BRX.HAL` de forma versionada e baseada em permissões.
8. Criar a sondagem de capabilities e o fallback genérico/software antes do adapter gráfico; depois testar uma superfície/buffer em hosts e GPUs reais, sempre com erro seguro para capability ausente.
9. Escrever o compilador em BRX quando a linguagem já manipular arquivo/buffers, funções, loops e emitir bytecode; executar bootstrap BRX0→BRX1→BRX2.

## 8. Estado real do repositório

Neste marco, `src/boot/brx0.s` é um interpretador de texto BRX em assembly x86-64. `src/vm/brxvm0.s` implementa um **runtime inicial de BRXE** no Linux x86-64, com loader/validação de cabeçalho, arquivo até 131071 bytes, pilha limitada, inteiros, 256 slots locais, soma/subtração/multiplicação/divisão/resto e saída de inteiro/literal. Antes de executar, verifica o fluxo linear de opcodes/operandos, profundidade da pilha e leitura de slots inicializados; um opcode inválido tardio ou arquivo superdimensionado é rejeitado. `examples/hello.brxe` exercita gravação/leitura de local e execução do formato. A suíte testa ambos os executores e módulos inválidos.

Ainda faltam compilador fonte→BRXE, saltos/funções no bytecode, sondagem/HAL/GPU e runtimes para outros hosts. O executável nativo do runtime atual depende de Linux x86-64 e `as`/`ld` no build, mas os aplicativos futuros serão `.brxe`. Esta distinção é importante: BRXE é a camada virtual portátil pretendida; o runtime nativo que interpreta BRXE ainda é específico do host.

## Referências principais

1. Python Language Reference — https://docs.python.org/3/reference/index.html
2. ECMA-262 — https://tc39.es/ecma262/
3. Python Lexical Analysis (tokens, comments, longest match) — https://docs.python.org/3/reference/lexical_analysis.html
4. Crafting Interpreters, Parsing Expressions — https://craftinginterpreters.com/parsing-expressions.html
5. Crafting Interpreters, Statements and State / Functions — https://craftinginterpreters.com/statements-and-state.html e https://craftinginterpreters.com/functions.html
6. PLAI, Static Types — https://cs.brown.edu/courses/cs173/2012/book/types.html
7. Java Virtual Machine Specification — https://docs.oracle.com/en/java/javase/26/docs/specs/jvms/jvms-1.html
8. W3C WebAssembly Core Specification — https://www.w3.org/TR/wasm-core-2/
9. Intel Software Developer’s Manual — https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
10. Linux syscall(2) — https://man7.org/linux/man-pages/man2/syscall.2.html
11. Linux DRM memory management — https://docs.kernel.org/gpu/drm-mm.html
12. DRM driver UAPI — https://dri.freedesktop.org/docs/drm/gpu/driver-uapi.html
13. AMD GPU Architecture Programming Documentation — https://gpuopen.com/amd-gpu-architecture-programming-documentation/
14. Rust compiler bootstrapping — https://rustc-dev-guide.rust-lang.org/building/bootstrapping/intro.html
15. Installing Go from source — https://go.dev/doc/install/source
16. GCC build/stages — https://gcc.gnu.org/install/build.html
17. Ken Thompson, “Reflections on Trusting Trust” — https://dl.acm.org/doi/10.1145/358198.358210
18. Microsoft Basic Display Adapter — https://support.microsoft.com/en-us/windows/hardware/display-graphics/microsoft-basic-display-adapter-in-windows
19. Microsoft Basic Display Driver — https://learn.microsoft.com/en-us/windows-hardware/drivers/display/microsoft-basic-display-driver
