# BRXE — formato executável portátil da BRX (v1 em implementação)

## Objetivo

A ideia proposta para BRX é válida: em vez de exigir que cada aplicação seja um executável ELF/PE/Mach-O nativo, a BRX pode definir seu próprio executável — **módulos BRXE com instruções para uma máquina virtual BRX**. O código de aplicação é compilado uma vez para BRXE e roda sem recompilação em sistemas que tenham um runtime BRX compatível.

Isso significa que BRXE seria uma **ISA virtual**, com conjunto de instruções, codificação binária e semântica definidos por nós. Java VM e WebAssembly demonstram o modelo: há um formato de código/ISA independente da CPU hospedeira e um runtime/embedding que o carrega e executa [1] [2].

## Uma distinção essencial

O arquivo BRXE pode ser o **executável da camada BRX**, mas não é a CPU física. Ele não roda sozinho: cada aparelho ainda precisa de um runtime BRX compatível que lê o módulo e traduz/interpreta suas instruções, além de uma forma de instalar/abrir esse runtime. O runtime pode ser compilado para CPU/OS diferentes, escrito em assembly próprio para cada alvo, ou futuramente JIT-compilar BRXE para instruções nativas. Aplicativos BRX ficam portáveis na medida em que o runtime implementa a versão do formato e os serviços que cada aplicação usa.

A sintaxe/semântica de BRX e o formato bytecode devem ser portáveis. O runtime do host, a instalação, I/O, ABI e driver GPU continuam específicos da plataforma. WebAssembly explicita justamente essa separação: define ISA binária/validação/semântica core, enquanto I/O e ambiente vêm de APIs de embedding [2].

## Formato de arquivo proposto — BRXE v1

A proposta inicial do contêiner é pequena e versionada. Valores inteiros de cabeçalho e operandos são little-endian.

| Campo | Tamanho | Significado |
|---|---:|---|
| magic | 4 bytes | ASCII `BRXE` |
| version | u16 | `1` |
| flags | u16 | zero no v1; bits futuros só por versão definida |
| code_size | u32 | tamanho exato do fluxo de instruções |
| data_size | u32 | bytes de literais/constantes |
| code | code_size | instruções e operandos do VM |
| data | data_size | constantes imutáveis do módulo |

O runtime lê até EOF, aceita no máximo 131071 bytes e rejeita input maior; também rejeita magia/versão desconhecida, tamanhos que não correspondem exatamente ao arquivo, opcode inválido e acessos além das regiões declaradas. Antes de executar, faz um passe linear pelo código para confirmar opcodes/operandos, ranges de literais, profundidade máxima de pilha e leituras locais inicializadas. Assim, um opcode malformado no fim do módulo é rejeitado antes de qualquer saída. Isso não é ainda um verificador de fluxo de controle: saltos/chamadas não estão implementados. A especificação final também deve fixar alinhamento e limites públicos de recursos.

## ISA virtual

Conjunto inicial de opcodes (operandos little-endian; IDs definidos para este estágio):

- `0x00 HALT` — terminar o módulo.
- `0x01 PUSH_I64 imm64` — colocar inteiro assinado de 64 bits na pilha de operandos.
- `0x02 LOAD_LOCAL u16` / `0x03 STORE_LOCAL u16` — carregar/guardar uma variável local num dos 256 slots (`u16` little-endian; só os índices 0–255 são válidos). O verificador rejeita leitura antes da primeira gravação.
- `0x04 ADD_I64`, `0x05 SUB_I64`, `0x06 MUL_I64`, `0x07 DIV_I64`, `0x08 MOD_I64` — consumir dois inteiros e deixar resultado.
- `0x09 PRINT_I64` — imprimir inteiro com sinal e nova linha.
- `0x0A PRINT_CONST u32 offset, u32 length` — imprimir os bytes da seção data e nova linha.
- `0x0B..0x0E` — reservados como propostas de controle de fluxo/chamadas; não são executáveis na versão atual e devem ser rejeitados. Só definir sua semântica após especificar nova versão e verificador de CFG.

Pilha vazia demais, divisão por zero, índice inválido, salto fora do código e limite excedido devem causar trap BRX determinístico. No runtime atual, soma, subtração e multiplicação mantêm os 64 bits baixos; isso é comportamento observado desta build, ainda não garantia normativa estável do formato. Definir e testar a regra de overflow antes de declarar compatibilidade v1.

## Serviços da plataforma e hardware

Não inserir syscalls Linux nem instruções GPU proprietárias no núcleo portátil dos opcodes. A proposta é definir módulos/imports versionados como `BRX.IO`, `BRX.HW.CPU_INFO` e `BRX.GFX` com capacidades/permissões explícitas. Em runtimes futuros, a meta é detectar automaticamente os adapters, APIs e capacidades que o host anuncia e escolher a melhor implementação disponível; o aplicativo só consultará capacidades lógicas, sem precisar detectar marca/modelo/OS.

- CPU: serviço portável pode retornar vendor/ISA/features disponíveis, mas o backend lê-os por instruções próprias (CPUID em x86, outro mecanismo em outra ISA) e em ambientes virtualizados poderá devolver dados filtrados.
- GPU: definir API gráfica BRX de alto nível independente; backend usa driver documentado do host. Implementar raw command buffer/ISA de GPU como extensão por fabricante/família, nunca exigir que o core BRXE contenha instruções específicas de AMD/NVIDIA/Intel.
- Uma aplicação que só use recursos BRX core pode ser altamente portável. Uma aplicação que exija extensão GPU específica declara essa dependência e precisa de runtime compatível.
- Fallback proposto por capacidade: adapter acelerado do host, adapter genérico exposto pelo OS, fallback por software/modo básico, ou erro legível. Capacidades obrigatórias falham antes de iniciar se indisponíveis; opcionais permitem modo degradado. Fallback não instala driver nem contorna permissões. Windows documenta o Basic Display Adapter genérico e suas capacidades reduzidas [5] [6].

## Implementação atual e próximos passos

O bootstrap de texto `brx0` interpreta arquivos `.brx` em Linux x86-64. O executor `brxvm0` em `src/vm/brxvm0.s` já lê, valida e executa módulos BRXE neste mesmo alvo. O runtime reconhece magia/versão/flags, checa que cabeçalho, código e dados ocupem o tamanho declarado, limita a pilha de operandos e valida opcodes e faixas de literais. O exemplo binário `examples/hello.brxe` imprime um inteiro e um literal.

Opcodes já executados pelo runtime: `HALT`, `PUSH_I64`, `LOAD_LOCAL`, `STORE_LOCAL`, `ADD_I64`, `SUB_I64`, `MUL_I64`, `DIV_I64`, `MOD_I64`, `PRINT_I64` e `PRINT_CONST`. O verificador prévio faz validação linear de operandos e stack-depth e rastreia locais inicializados. Ainda **não** estão implementados saltos, funções, compilador BRX→BRXE, sondagem/HAL de hardware nem runtime para outro OS/ISA. `examples/hello.brxe` grava 40 num slot, carrega e soma 2, imprimindo 42; o compilador da linguagem ainda não emite o módulo.

Etapas seguintes:

1. Formalizar limites, traps e semântica de overflow, strings e capacidades no v1.
2. Implementar saltos e fluxo de controle, depois ampliar verificação para estados de pilha por bloco/aresta.
3. Definir IR/AST independente do host e escrever o primeiro emissor BRX→BRXE.
4. Testar que um programa fonte gera BRXE reproduzível e que `brxvm0` produz a saída esperada.
5. Portar um runtime mínimo para outro OS/ISA e executar sem recompilar o mesmo arquivo `.brxe`.
6. Definir adaptadores de host para serviços BRX e a camada `BRX.HAL` para drivers já instalados.
7. Escrever o emissor/runtime do compilador em BRX e iniciar bootstrap reproduzível/auto-hospedagem.

O formato já tem um primeiro executor e fixture binário funcional, mas ainda não é um ambiente portável completo: faltam o compilador que gera módulos e runtimes para outros hosts. A portabilidade só será comprovada quando o mesmo módulo passar em runtimes de alvos distintos.

## Referências

[1]: https://docs.oracle.com/en/java/javase/26/docs/specs/jvms/jvms-1.html "The Java Virtual Machine Specification — Introduction"
[2]: https://www.w3.org/TR/wasm-core-2/ "WebAssembly Core Specification"
[3]: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html "Intel 64 and IA-32 Architectures Software Developer’s Manual"
[4]: https://man7.org/linux/man-pages/man2/syscall.2.html "Linux man-pages syscall(2)"
[5]: https://support.microsoft.com/en-us/windows/hardware/display-graphics/microsoft-basic-display-adapter-in-windows "Microsoft Basic Display Adapter in Windows"
[6]: https://learn.microsoft.com/en-us/windows-hardware/drivers/display/microsoft-basic-display-driver "Microsoft Basic Display Driver"
