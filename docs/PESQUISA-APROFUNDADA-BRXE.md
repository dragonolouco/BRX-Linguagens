# Relatório técnico final — BRX/BRXE

**Escopo:** decisões de formato e evolução do BRXE, semântica da VM, validação, segurança, BRX-HAL, portabilidade gráfica, compilador e bootstrap.

**Natureza deste documento:** os itens marcados como **fato documentado** reproduzem somente os resultados de pesquisa fornecidos. Os itens marcados como **decisão proposta** são recomendações de projeto para o BRX; não devem ser lidos como funcionalidades já implementadas.

## 1. Conclusão executiva

O estado atual do working tree é um runtime BRXE em **assembly x86-64/Linux**, com contêiner de 16 bytes, pilha numérica, 256 slots locais e saída. Há também um passe de validação linear anterior à execução. Ainda não existem compilador BRX→BRXE, HAL, sondagem de hardware pelo runtime, adapters BRX para drivers nem ports testados para outros sistemas operacionais e ISAs. O projeto executa um subconjunto de módulos, mas ainda não demonstrou uma cadeia fonte→bytecode nem portabilidade entre runtimes.

A decisão central recomendada é **não tentar transformar o BRXE em uma cópia de WebAssembly, JVM, Vulkan ou de qualquer ABI de host**. Essas tecnologias são referências úteis: WebAssembly separa ISA virtual, validação, execução e embedding; a JVM separa class file, verificação e implementação da máquina abstrata; WASI/Component Model exemplificam capabilities e imports versionados; Vulkan, DRM e WDDM mostram que gráficos dependem de capacidades reais e de drivers. Nenhuma dessas referências fornece uma especificação BRXE pronta [1] [6] [11] [12] [19].

O relatório priorizou um pipeline `decode → validate → execute`. A implementação atual já cobre parte dessa recomendação: lê até EOF, limita o arquivo, valida o fluxo de opcodes/operandos, stack-depth, ranges de literais e leitura de locais antes de executar. Testes incluem opcode inválido tardio sem saída parcial, arquivo truncado/superdimensionado, underflow e local não inicializado. Isso **não completa P0**: ainda faltam códigos de erro distintos, corpus mais exaustivo, quotas de output/execução, fluxo de controle e testes/fuzz de todos os immediates truncados. Traps dinâmicos, como divisão por zero, ainda usam mensagem genérica.

Em paralelo, o BRX deve congelar sua especificação própria: endianness, tabela de opcodes, efeitos de pilha, aritmética, bounds de dados, versionamento e host ABI. Extensões estruturais devem usar uma nova versão, preferencialmente um contêiner TLV em BRXE v2, e não reinterpretar arquivos v1. O código portátil deve enxergar apenas capacidades e handles opacos; syscalls Linux, ponteiros, endereços de função e estruturas de driver nunca devem entrar no módulo.

## 2. Estado factual do projeto

### 2.1 O que está documentado sobre o estado atual

A base factual fornecida para este relatório informa:

- o BRX possui um interpretador textual e o BRXE possui um runtime escritos manualmente em assembly x86-64;
- o alvo testado é Linux x86-64;
- o contêiner BRXE atual tem header de 16 bytes composto por magic, `u16 version`, `u16 flags`, `u32 code_size` e `u32 data_size`;
- o subconjunto atual inclui HALT, `PUSH_I64`, `LOAD_LOCAL`, `STORE_LOCAL`, aritmética inteira, `PRINT_I64` e `PRINT_CONST`;
- o runtime faz validação linear prévia de opcodes/operandos, profundidade de pilha, limites de literais e inicialização de locais;
- não há ainda compilador fonte→BRXE, HAL formalizada, drivers/adaptadores portáveis ou ports testados para outros OS/ISAs;
- o bootstrap de build assume `as`/`ld` e Linux.

Esses pontos descrevem o estado atual do projeto, revisto após as mudanças recentes; não são uma auditoria formal completa do código. Não há implementação de jumps, calls, memória linear, imports, gráficos nem sondagem de hardware na VM. O módulo de exemplo confirma que os campos numéricos gravados no BRXE atual são little-endian; isso ainda não constitui uma especificação normativa congelada.

### 2.2 O que o estado atual permite afirmar sem exagero

É defensável afirmar que o projeto tem um runtime nativo capaz de executar o subconjunto informado no ambiente alvo. Não é defensável afirmar, apenas a partir desse estado, que:

1. qualquer arquivo BRXE é portável entre máquinas;
2. o mesmo bytecode funciona em outro OS ou ISA;
3. existe uma linguagem BRX compilável de ponta a ponta;
4. há segurança de sandbox ou isolamento contra drivers;
5. há acesso gráfico portátil;
6. o bootstrap é “100% do zero”;
7. há self-hosting, reprodutibilidade bit a bit ou DDC demonstrados.

A razão é estrutural: WebAssembly e JVM também separam a máquina abstrata do embedding, e deixam a implementação escolher interpretação, compilação ou JIT [1] [4] [7]. Formato portátil, runtime portado, ABI de host e ferramenta de compilação são entregáveis distintos.

## 3. Fatos documentados que orientam as decisões

### 3.1 Separação entre ISA, contêiner e ambiente

**Fato documentado.** WebAssembly se define como uma ISA/máquina virtual; a camada core especifica instruções, codificação, validação e semântica de execução, enquanto a interação com ambiente, APIs e embedders fica fora do core [1]. Imports são fornecidos pelo embedder e controlam as capacidades que o módulo recebe; não há acesso implícito ao ambiente [1] [4].

**Fato documentado.** A JVM também descreve uma máquina abstrata e não fixa layout, otimizações ou modo de execução. O laço conceitual busca opcode, busca operandos e executa; tradução para outra VM ou ISA nativa durante carga/execução, inclusive JIT, é decisão do implementador [7].

**Implicação para BRX.** O formato BRXE deve descrever semântica e dados portáveis, não o layout interno do runtime. Um executor assembly, um interpretador de referência e um futuro JIT podem compartilhar os mesmos bytes somente se a especificação congelar o comportamento observável.

### 3.2 Contêineres, versionamento e endianness

**Fato documentado.** O módulo WebAssembly começa com magic de quatro bytes `\\0asm` e versão; depois há seções com `id` de um byte, comprimento `u32` e conteúdo. Custom sections têm `id=0`, podem aparecer em qualquer posição e são ignoradas pela semântica; as demais ocorrem no máximo uma vez e em ordem prescrita [2]. A codificação usa LEB128 para inteiros variáveis, enquanto valores de ponto flutuante e valores lidos/escritos na memória usam little-endian [2].

**Fato documentado.** Class files da JVM são fluxos de bytes sem padding ou alinhamento implícito; quantidades multibyte são big-endian. O início contém magic `0xCAFEBABE`, `minor_version`, `major_version` e estruturas como constant pool, métodos e attributes [6]. Attributes não definidos podem ser ignorados silenciosamente, mas não podem mudar a semântica do class file [6].

**Fato documentado.** WebAssembly prevê aumento de versão quando uma mudança é incompatível, mas tenta adicionar recursos sem incrementar a versão quando isso é possível; essa política não significa que qualquer runtime antigo aceite qualquer recurso novo [2]. A JVM versiona class files por major/minor e exige que uma implementação conforme suporte os majors definidos para sua edição [6].

**Implicação para BRX.** Endianness, versionamento e política para campos desconhecidos precisam ser decisões normativas próprias. Não se deve importar sem reflexão a política de custom sections do Wasm nem a de attributes da JVM: uma seção pode conter capability obrigatória ou alterar a interpretação do módulo, caso em que ignorá-la seria inseguro.

### 3.3 Validação antes da execução

**Fato documentado.** A validação do WebAssembly atribui a cada instrução um efeito de pilha tipado, exige labels existentes e tipos compatíveis e prepara o módulo para execução; a instanciação exige que o módulo seja válido e que imports correspondam aos tipos declarados [3] [4]. A especificação prevê traps, inclusive em inicialização e acessos fora dos limites [4].

**Fato documentado.** Na JVM, o class-file verifier verifica restrições estáticas e estruturais antes que bytecode válido seja executado. A operand stack tem tipos e profundidade máxima por frame; `StackMapTable` pode fornecer frames para o type checker; branches devem apontar para o opcode de uma instrução dentro do método [6] [8].

**Implicação para BRXE.** O runtime atual já faz um passe linear antes de executar o subconjunto sem branches, conferindo header/regiões, opcodes/operandos, stack-depth, literais e inicialização local. Como ainda não há fluxo de controle, a validação segue um único caminho; antes de introduzir jumps/calls será necessário construir boundaries de instruções, conferir destinos e verificar estados/alturas de pilha em cada join.

### 3.4 Limites, fuel e segurança não são automáticos

**Fato documentado.** A documentação de segurança do WebAssembly descreve sandbox, imports/APIs, CFI e bounds checks, mas também ressalta limitações como TOCTOU, corridas, side channels e code reuse em chamadas indiretas [5]. Sandbox de bytecode não equivale a segurança total do host.

**Fato documentado.** Wasmtime oferece fuel para contabilizar execução e epochs como alternativa menos determinística; nenhuma dessas estratégias interrompe código que está bloqueado dentro de uma chamada host [9]. `ResourceLimiter` limita crescimento de memories/tables e instâncias, mas não representa toda a memória do Store nem todas as alocações do embedder [10].

**Implicação para BRXE.** O runtime precisa de caps de arquivo, code/data, pilhas, output, host calls e memória, além de fuel/step budget para loops futuros. Um watchdog de wall-clock deve ser uma camada adicional para chamadas host bloqueantes, não a semântica portátil da VM.

### 3.5 Capabilities, imports e versionamento de host

**Fato documentado.** WASI adota segurança baseada em capabilities e deny-by-default: sem import de filesystem o módulo não lê arquivos; sem import de rede não abre sockets [11]. Um WIT world descreve imports requeridos e exports fornecidos, e o host que suporta o world deve satisfazer os imports [12]. WIT usa package IDs com namespace, nome e semver; `@since` e `@unstable` apoiam evolução, enquanto mudança breaking exige nova major ou definição distinta [13].

**Implicação para BRX.** BRX-HAL deve ser uma ABI pequena e explícita, separada da ISA. O guest deve declarar imports, versões, assinaturas e rights pedidos; o host concede ou nega capabilities. A ausência de capability não pode virar no-op silencioso.

### 3.6 Gráficos dependem de drivers, OS e capacidades reais

**Fato documentado.** No Linux, a UAPI DRM expõe interfaces de memória, contextos, DMA, fences e gerenciamento de memória, além de ioctls específicos por driver. Render nodes permitem acesso de renderização sem DRM master, mas não permitem modesetting nem ioctls privilegiados; acesso depende das permissões do device node [14]. KMS organiza framebuffers, planes, CRTCs e connectors, e controlar uma tela é uma capacidade distinta de renderizar offscreen [15].

**Fato documentado.** No Windows, o Direct3D runtime, UMD, `dxgkrnl` e KMD formam uma cadeia mediada pelo WDDM; o vendor fornece UMD e KMD, enquanto memória de vídeo e scheduler ficam na infraestrutura do sistema [16]. DXCore/DXGI enumeram adapters e retornam um adapter para criação de device, não endereços físicos de hardware [17] [18]. Feature levels e `CheckFeatureSupport` informam capacidades, mas feature level não implica desempenho [19].

**Fato documentado.** Vulkan é uma API aberta e multiplataforma, mas exige enumerar physical devices, queues, heaps, tipos de memória, formatos, extensões e capacidades reais; a aplicação gerencia explicitamente memória do device [20]. Documentações AMD, NVIDIA e Intel mostram pilhas e coberturas dependentes de vendor, geração, OS, driver e versão [21] [22].

**Fato documentado.** O Microsoft Basic Display Adapter é um driver genérico incluído no Windows e usado quando o driver do fabricante não está disponível. Fornece capacidades básicas de display/gráficos; drivers do fabricante tendem a oferecer melhor desempenho, resolução, múltiplos monitores e recursos adicionais [41]. O Microsoft Basic Display Driver também cobre setup/safe mode e transições de driver, com finalidade principal de escrita ao linear framebuffer; em certas configurações, herda o modo de vídeo do boot e não pode mudar a resolução [42]. Isso é fallback concreto para um ambiente/classe específica, não um driver universal para todo hardware.

**Implicação para BRX.** Uma eventual BRX-GFX deve ser uma API capability-driven de handles opacos, traduzida para backends hospedados. Driver instalado não equivale a acesso raw privilegiado, nem garante uma tela, permissões ou a mesma capacidade em outro host.

### 3.7 Autodetecção e fallback de hardware

**Decisão proposta.** A adaptação automática é responsabilidade do **runtime BRX e dos adapters do host**, não do código-fonte isoladamente. Ao carregar o módulo, o runtime enumera dispositivos/APIs por interfaces autorizadas e consulta capacidades anunciadas. Para cada capability lógica, escolhe o backend compatível mais capaz: driver específico/acelerado → adapter genérico/classe disponibilizado pelo host → modo básico/software presente → erro legível. O módulo declara capabilities obrigatórias/opcionais; as obrigatórias são verificadas antes de iniciar, e as opcionais podem ativar uma experiência degradada. BRX não instala drivers, não eleva privilégios e não envia comandos raw como fallback.

O aplicativo pode ignorar marca/modelo/OS se o adapter cumprir a mesma capability. “Qualquer hardware” significa tentar automaticamente os caminhos que o host realmente expõe, não prometer que todo dispositivo tenha driver genérico. Sem interface ou adapter compatível, a capability continua indisponível até haver implementação. Testes devem cobrir adapters acelerado, genérico, software, capability ausente, versão incompatível e permissão negada; mocks determinísticos devem preceder testes em hosts reais.

### 3.8 Compilador, gramática e testes

**Fato documentado.** A arquitetura didática de Crafting Interpreters separa scanner, tokens, parser, AST, resolução e emissão de bytecode; a VM stack-based mantém instruction pointer, decodifica opcode e usa a pilha para produzir/consumir valores [23] [24]. O tutorial do LLVM separa parser/AST, geração de IR e verificação de well-formedness [25]. ECMAScript e Python também distinguem gramática léxica, tokens, gramática sintática, spans e erros antecipados [26] [27].

**Fato documentado.** O guia de testes do LLVM diferencia testes unitários, regressão e programas completos, usando comandos e comparação com saída de referência [25]; Test262 é uma suíte de conformidade que cobre comportamentos observáveis, mas declara que sua cobertura não é completa [40].

**Implicação para BRX.** O próximo compilador deve ter fronteiras claras: scanner → parser/AST → análise semântica → StackIR → verificador → serializador BRXE. A saída deve ser testada tanto por bytes golden quanto por comportamento diferencial contra um interpretador de referência.

### 3.9 Bootstrap e confiança

**Fato documentado.** GNU Binutils separa assembler `as`, linker `ld` e ferramentas de objetos/ELF [28]. Rust usa um bootstrap por estágios com compilador stage0; Go requer um Go de bootstrap para toolchains atuais; GCC exige, para o bootstrap convencional, compilador C++14, headers/libc, binutils e bibliotecas auxiliares [29] [30] [31].

**Fato documentado.** Bootstrappable Builds, Stage0 e Onramp reduzem e tornam auditável a cadeia de confiança, mas começam com um seed: monitor hexadecimal, ferramenta/VM ou artefato equivalente [32] [33] [34]. Reprodutibilidade significa reconstruir bit a bit sob o mesmo fonte, ambiente e instruções; o ambiente inclui versões, flags, sistema, arquitetura e demais premissas [35]. DDC fornece evidência de correspondência entre fonte e compilador sob hipóteses explícitas, não uma prova sem premissas [36]. O ataque “trusting trust” mostra por que inspecionar apenas a fonte não basta [37].

**Implicação para BRX.** A formulação precisa é: “runtime distribuído sem dependência de C/libc/terceiros, atualmente nativo e testado em Linux x86-64, com `as`/`ld` como seed de build”. Isso não é bootstrap literal do zero. Self-hosting, builds reproduzíveis e DDC devem ser marcos separados.

## 4. Decisões propostas para BRX/BRXE

### D1 — Congelar BRXE v1, sem reinterpretar módulos existentes

**Decisão proposta.** Manter os 16 bytes do header e o significado atual dos módulos v1. Publicar uma especificação byte a byte com:

- tamanho e bytes exatos do magic;
- `version=1` e a política para versões maiores/desconhecidas;
- bits de `flags`, incluindo bits reservados;
- limites de `code_size` e `data_size`;
- posição exata das regiões code/data;
- codificação de todos os `u16`/`u32`;
- tabela fechada de opcodes, comprimento dos immediates e efeitos de pilha;
- layout de `data`, constantes e `PRINT_CONST`;
- política de bytes residuais/trailing bytes.

A ordem observada no runtime e no módulo de exemplo é little-endian para campos multibyte. Ao congelar a norma, especificar isso byte a byte e exigir que futuros runtimes decodifiquem independentemente da endianness nativa, sem mapear o arquivo para structs do host. O arquivo golden atual deve ser preservado como fixture; se surgir artefato em ordem diferente, usar migrador ou versão distinta, não reinterpretar silenciosamente.

`u32` limita cada tamanho declarado a 4 GiB. O runtime deve impor caps menores e configuráveis; tamanho de campo não é política de disponibilidade nem fornece checksum, assinatura, compressão ou autenticação.

### D2 — Versionamento explícito e flags não silenciosas

**Decisão proposta.** O loader aceita somente versões que conhece. Versão maior ou desconhecida é rejeitada com código determinístico antes de interpretar o corpo. Bits de flag desconhecidos que sejam requeridos devem causar rejeição; flags opcionais só podem ser ignorados se a especificação disser que não alteram a semântica. Flags nunca devem mudar silenciosamente o significado de opcodes v1.

Essa decisão segue a separação observada em Wasm e JVM entre versão do formato e recursos, mas não copia a política de compatibilidade deles [2] [6]. Um runtime antigo deve rejeitar BRXE v2 antes de assumir que após o header há `code_size` bytes no layout v1.

### D3 — BRXE v2 como contêiner estrutural novo

**Decisão proposta.** Se forem necessárias imports, exports, capabilities, metadados ou múltiplos segmentos, criar BRXE v2. Não aplicar TLV a arquivos v1. Um corpo v2 pode usar:

```text
[u8 section_id][u32le length][payload]
```

`CODE` e `DATA` seriam seções obrigatórias; `IMPORTS`, `EXPORTS` e `CAPABILITIES` poderiam ser seções padrão opcionais ou obrigatórias conforme o perfil; haveria uma faixa `vendor/custom` explicitamente pulável. Seção padrão desconhecida, malformada ou semanticamente necessária rejeita o módulo. Seção vendor opcional pode ser pulada somente depois da validação do `length`.

Essa mudança é deliberadamente incompatível com qualquer loader que espera, após o header, `code_size` bytes seguidos imediatamente de `data_size` bytes. O parser v1 deve rejeitar `version=2`; o emissor também precisa ser versionado.

### D4 — Semântica da ISA independente de acidentes do x86

**Decisão proposta.** Fixar na especificação:

- valores BRXE como `i64` em complemento de dois;
- `ADD`, `SUB` e `MUL` com wrap modular `2^64` ou traps, escolhendo uma política única e documentada;
- signedness de `DIV`/`MOD`;
- divisor zero;
- caso `INT64_MIN / -1`;
- underflow/overflow da pilha;
- opcode desconhecido;
- immediate truncado;
- `HALT`;
- consumo ou preservação do valor por `PRINT_I64`;
- formato, índice, comprimento e bounds de `PRINT_CONST`.

A implementação atual já observa wrap dos 64 bits baixos em `ADD`/`SUB`/`MUL`, `DIV`/`MOD` assinados e rejeita divisor zero e `INT64_MIN / -1` com erro BRXE genérico; `PRINT_I64` consome o valor. Recomenda-se congelar essas regras como semântica do v1 depois de criar testes golden de extremos. A VM não deixa `idiv` emitir SIGFPE para os dois casos inválidos; o código de erro ainda não distingue as causas. Mudança semântica posterior exige versão ou tradução, não alteração silenciosa do contrato.

### D5 — Validador fechado antes do executor

**Decisão proposta.** O pipeline normativo é:

1. `decode`: ler bytes com bounds e endian explícito;
2. `validate`: validar formato, opcodes, immediates, regiões, pilha e limites;
3. `execute`: executar somente um módulo validado.

A validação deve ocorrer antes de output, syscall, alocação grande ou efeito de host. Cada opcode declara comprimento, inputs/outputs da pilha e possíveis traps. O verificador rejeita opcode desconhecido, immediate incompleto, referência fora de `code`/`data`, underflow/overflow e demais inconsistências. A meta é que erros de entrada retornem status BRXE sem crash, output parcial ou execução de prefixo.

### D6 — BRX-HAL separado, capability-based e versionado

**Decisão proposta.** Nenhum opcode ou payload deve carregar syscall Linux, file descriptor, ponteiro, endereço de função x86-64 ou estrutura de driver. O módulo referencia uma capability por ID/nome e assinatura estável; o adapter do runtime mapeia-a para o driver disponível.

Em uma versão que suporte HAL, o manifesto deve declarar pelo menos:

```text
namespace/interface, operação, major, assinatura, rights pedidos, required/optional
```

Um desenho compatível com o header fixo é reservar em v2 um registro `HAL0` no corpo, com campos sem padding e little-endian explicitamente especificados: `hal_abi_major`, `import_count`, `manifest_size` e a lista de imports. `manifest_size` deve ser conferido contra `data_size`, e o offset dos dados da aplicação deve ser inequívoco.

Para a primeira versão, manter a ABI restrita a `i64` e operações pequenas, como console, clock e status. Usar handles opacos do runtime, não handles do OS. Proibir import genérico de raw syscall ou “open anything”. Uma tabela mínima de status pode conter `BRX_OK`, `BRX_E_MISSING`, `BRX_E_UNAVAILABLE`, `BRX_E_DENIED`, `BRX_E_BAD_ARG` e `BRX_E_IO`. Erro de serviço deve retornar status; erro de contrato, opcode, bounds ou formato pode abortar com trap determinístico.

Imports obrigatórios ausentes, incompatíveis ou não autorizados fazem o loader recusar a instanciação antes do primeiro opcode. Imports opcionais podem ser ligados a um slot `unavailable`, mas `HAL_CALL` deve retornar `BRX_E_UNAVAILABLE`, nunca virar no-op silencioso. A ideia é inspirada por WASI e WIT, sem exigir adotar o Component Model inteiro [11] [12] [13].

`PRINT_I64` e `PRINT_CONST` podem permanecer como aliases legados para `brx:console`, mas devem ser documentados como efeitos de host. Para tratar erros condicionalmente, a VM precisará futuramente de controle de fluxo e, possivelmente, de uma instrução mínima `DROP`.

### D7 — Congelar slots locais em v1; branches e chamadas depois

O runtime atual já implementa `LOAD_LOCAL` (`0x02`) e `STORE_LOCAL` (`0x03`) com immediate `u16` little-endian e slots 0–255. Esses IDs já apareciam no rascunho BRXE v1, mas o runtime anterior ainda não os executava. Como v1 continua explicitamente em implementação e não foi declarado como versão normativa estável, a decisão deste working tree é congelar agora a semântica dos locais em v1; não prometer compatibilidade com qualquer outro runtime v1 antigo que desconheça os opcodes.

Jumps, calls, memória linear e imports não estão implementados. Mantê-los inválidos/reservados no v1 estável e introduzir controle de fluxo/imports em versão nova (por exemplo, BRXE v2), com contêiner/manifesto definido e verificador de fluxo de controle. Para `JUMP`/`JUMP_IF_ZERO`, offsets relativos devem partir do primeiro byte após o immediate (`pc_after`), ser calculados em aritmética larga e validados antes da conversão para índice. Antes de executar branches, o verifier constrói o mapa de início de instruções, rejeita alvo no meio de immediate/fora do code e confere estados de pilha em cada destino/join. `CALL`/`RET` ficam para depois, com frames próprios contendo `return_pc`, base de valores, locals e limite de profundidade; não usar a pilha nativa x86 como call stack do guest.

### D8 — Interpreter primeiro; JIT/AOT depois

Implementar primeiro um interpreter com estado explícito: `code_base`, `pc`, `sp`, pilha i64, locals, fuel, limites e estado de trap. Um JIT/AOT futuro pode traduzir a mesma BRXE validada para x86-64 ou outra ISA, mas o código nativo deve ser cache privado do runtime e jamais parte do módulo portátil. Essa liberdade de implementação é coerente com a JVM, mas não exige JIT no bootstrap [7].

### D9 — BRX-GFX como API hospedada, não acesso raw

Se BRX evoluir para gráficos, definir BRX-GFX com handles opacos para Instance, Adapter, Device, Queue, CommandBuffer, Buffer, Image, View/Sampler, Pipeline, Fence/Semaphore, Surface/Swapchain e Query. O perfil mínimo deve negociar buffers/imagens, cópia, renderização básica, filas, sincronização e apresentação opcional. Compute, ray tracing, vídeo, memória externa e recursos protegidos são extensões negociáveis.

Vulkan é o backend hospedado primário recomendado para o perfil portátil, sempre atrás do ABI BRX; não deve virar o formato BRXE [20]. No Linux, separar render node/offscreen de DRM master/KMS/display [14] [15]. No Windows, usar DXGI/D3D12/WDDM para aplicações comuns e verificar feature levels/capabilities [16] [17] [18] [19]. AMD HIP/ROCm, NVIDIA CUDA Driver API e Intel Level Zero devem ser backends opcionais de compute ou extensões vendor, não baseline gráfico intercambiável [21] [22].

Um caminho `BRX-RAW`, se necessário para pesquisa ou driver próprio, deve ser explicitamente privilegiado, exigir política administrativa e identificação exata de vendor/generation, e nunca ser fallback silencioso de BRX-GFX.

## 5. Melhoria concreta priorizada para o runtime existente

### P0 — completar `vm_verify_code` e a execução somente após validação

**Objetivo.** Reduzir a superfície de falhas do runtime atual sem mudar o header v1 nem exigir C, libc, bibliotecas de terceiros, compilador, HAL ou outro OS.

#### 5.1 Entrega funcional

O working tree já contém `vm_verify_code`, uma rotina de verificação linear separada do dispatcher. Ela valida opcodes e comprimentos de operandos, limites de stack, `PRINT_CONST` e uso de slots antes da execução; o loader também lê até EOF, rejeita arquivo maior que 131071 bytes e exige que o tamanho físico coincida exatamente com header + code + data. O pré-passe é sem efeitos de saída e os testes cobrem algumas classes de entrada inválida.

Uma interface futura mais explícita pode ser:

```text
brxe_verify(buffer, file_len, limits) -> BRXE_OK | código de erro
brxe_execute(verified_module, host_caps, limits) -> resultado | trap BRXE
```

O dispatcher só começa depois do retorno do verificador. Para completar P0, separar status/códigos de erro da rotina atual, incluir todas as validações aritméticas e limites normativos e ampliar o corpus para cada opcode/immediate. A verificação deve continuar sem efeitos observáveis: não imprime, não chama driver, não aloca sem caps e não executa um prefixo enquanto valida o restante.

#### 5.2 Ordem de verificação

**Implementado no working tree:** arquivo lido em loop até EOF; EINTR repetido; cap rígido de 131071 bytes com leitura-probe de um byte para rejeitar overflow; mínimo de 16 bytes; magic, versão 1 e flags 0; layout little-endian observado nos artefatos; tamanho exato sem bytes residuais; varredura de todo o code; checagem de operandos/opcodes, limites de `PRINT_CONST`, stack-depth e locals inicializados; execução só após o passe.

**Ainda necessário para P0:** decodificar de forma independente de endianness do host (hoje o build é x86-64), publicar caps normativos para code/data/stack/output, adotar códigos de erro estáveis, cobrir cada truncamento de operando e fuzz controlado, e verificar se todas as falhas dinâmicas/estáticas têm saída e status documentados. A suíte atual já testa arquivo no tamanho máximo de 131071 bytes e um byte acima. Antes de branches, substituir a análise linear por validação de fluxo de controle.

A forma `offset <= size` e `width <= size-offset` deve ser usada para acessar code/data; não se deve calcular primeiro `offset+width` em uma largura que possa embrulhar.

#### 5.3 Erros mínimos e semântica de falha

Publicar códigos estáveis para, pelo menos: header curto, magic inválido, versão não suportada, flags inválidos, tamanho truncado, tamanho acima do limite, opcode desconhecido, immediate truncado, stack underflow, stack overflow, data/index fora de bounds, divisão por zero, overflow de divisão, branch inválido e fuel esgotado.

Toda entrada inválida deve resultar em rejeição ou trap BRXE. O critério é: **sem leitura fora do input, sem syscall/output, sem SIGFPE, sem corrupção, sem crash e sem hang não cancelável**. Erros de driver devem ser distinguidos de erros de formato e de VM.

#### 5.4 Corpus mínimo de aceitação

- arquivos de tamanho `0..15`;
- magic, version e flags inválidos;
- `code_size`/`data_size` zero, máximos e além do arquivo;
- somas que embrulham ou regiões sobrepostas;
- cada opcode com immediate cortado em cada byte possível;
- todos os bytes `0x00..0xff` onde só alguns são válidos;
- aritmética sem operandos e com um só operando;
- PUSH até o limite e mais um;
- DIV/MOD por zero e `INT64_MIN/-1`;
- `PRINT_CONST` com offset/length fora de data, combinação que excede os limites e output acima do cap;
- arquivo exatamente no limite e arquivo um byte acima do limite;
- bytes residuais segundo a política escolhida;
- fuzz por mutação de header e immediates.

Para cada caso, registrar seed/bytes, resultado esperado, código de erro e se algum output foi observado. Acrescentar arquivos golden válidos, incluindo o header atual e casos de cada opcode conhecido. Se a tabela de opcodes ou o formato de `PRINT_CONST` não estiverem documentados, a primeira subentrega de P0 é congelá-los; não é seguro inventar um parser “compatível” por heurística.

#### 5.5 Por que P0 vem antes de compiler, HAL e graphics

Sem decoder/validator total, um compilador apenas aumenta o volume de entradas que o runtime precisa aceitar e torna bugs de formato mais difíceis de localizar. Sem caps e traps controlados, HAL e graphics ampliam a autoridade do host antes de existir uma fronteira confiável. P0 usa o runtime que já existe, não exige novo backend e cria a fundação para testar todos os futuros executores.

### P1 — Especificação e compilador mínimo

Depois de P0:

1. congelar a gramática textual BRX, incluindo whitespace, comentários, case-sensitivity, inteiros e forma de `PRINT_CONST`;
2. criar `brxc0`, um compilador mínimo em assembly que produza BRXE diretamente;
3. manter scanner com tokens e spans, parser, análise semântica, StackIR e serializador;
4. comparar `brx-interp` e `brxc0 + brxe` por stdout, código de erro, spans normalizados e status;
5. publicar golden bytes e `--verify-only`.

A cadeia scanner/parser/IR/VM segue padrões documentados, mas a StackIR deve ser própria e pequena, sem adicionar LLVM ao produto [23] [24] [25].

### P2 — BRX-HAL mínimo

Adicionar manifesto de imports e `HAL_CALL` somente após a política de versionamento e validação estar estável. Começar por console/status com handles opacos, allowlist, assinaturas fixas, rights e erros estáveis. Criar adapter Linux e mock determinístico; o mock é necessário para diferenciar bugs do runtime de diferenças do host.

### P3 — controle de fluxo e quotas

Adicionar branches, fuel e quotas de execução/output antes de permitir bytecode com loops; slots locais já fazem parte do subset atual. Só depois especificar CALL/RET e frames. Testar self-loop, loop que imprime, fuel 0/1, depth máximo e retorno sem frame.

### P4 — ports e BRX-GFX

Portar primeiro o executor/decoder para uma segunda ISA ou OS, mantendo bytes e semântica. Depois criar BRX-GFX hosted com enumeração e negociação de capabilities. Portabilidade de módulo só será demonstrada quando existir ao menos outro runtime conforme, adapter equivalente e uma suíte de conformance que produza os mesmos resultados nos efeitos determinísticos.

## 6. Plano de testes e conformidade

A suíte deve ser em camadas:

1. **Formato:** header, endianness, tamanhos, truncamentos, flags, trailing bytes e versões.
2. **Decoder:** todos os opcodes, immediates, boundaries e bytes desconhecidos.
3. **Validador:** stack effects, limites, constantes, locals e, futuramente, branch targets/imports.
4. **Semântica:** aritmética extrema, traps, HALT, impressão e status.
5. **End-to-end:** fonte BRX → BRXE → execução.
6. **Diferencial:** interpretador textual, compilador, interpreter BRXE e futuro JIT.
7. **Host:** capability ausente, versão incompatível, assinatura errada, driver com erro, retorno inválido, reentrância e bloqueio; para a futura sondagem, exercitar adapter específico, genérico, software, permissão negada e capability indisponível.
8. **Fuzz/negativo:** mutações de headers/immediates e programas aleatórios limitados pela gramática.

Para casos válidos, comparar stdout e resultados normalizados. Para erros de fonte, ambos devem falhar antes de executar; para erros de runtime, compilação deve suceder e o erro normalizado deve coincidir. Mensagens literais não devem ser comparadas se não forem parte da especificação; comparar fase, código, span/byte offset e status.

A suíte deve registrar seed, ambiente, limites e política de nondeterminismo. Relógio, rede, filesystem, random e drivers devem usar stubs quando o objetivo for conformance. Um interpretador de referência simples reduz o risco de o runtime e o compilador compartilharem o mesmo bug.

## 7. Reprodutibilidade, self-hosting e claims de produto

### 7.1 Formulação pública recomendada

A formulação factual e sustentável é:

> “O runtime BRXE distribuído não depende de C, libc ou bibliotecas de terceiros em seu núcleo; a implementação atual é assembly x86-64 para Linux e usa `as`/`ld` como ferramentas de bootstrap. O formato BRXE é projetado para ser portado por runtimes e adapters conformes; compiler fonte→BRXE, ports multicross-platform e autodetecção/HAL automática ainda são trabalho futuro.”

Não usar “100% do zero”, “universal” ou “portátil em qualquer OS/ISA” enquanto os respectivos critérios não forem demonstrados.

### 7.2 Build determinístico

Fixar fonte por commit/hash, versões e hashes de `as`/`ld`, arquitetura, kernel/ambiente, flags e ordem de entradas. Evitar timestamp, caminho absoluto, ordem de diretório e metadados não determinísticos dentro do BRXE; se timestamp for indispensável, usar uma regra determinística como `SOURCE_DATE_EPOCH` [35]. Comparar SHA-256 de builds independentes. Reprodutibilidade demonstra identidade do artefato sob ambiente fixado, não equivalência universal nem ausência de bugs.

### 7.3 Self-hosting e DDC

O marco de self-hosting é: `brxc0` compila um compilador BRX escrito em BRX; esse compilador recompila seu próprio fonte e o resultado passa os mesmos testes e, idealmente, produz bytes definidos. DDC só faz sentido depois de existir essa cadeia, um compilador diverso capaz de compilar o pai, determinismo e uma comparação bit a bit. O relatório não afirma que qualquer desses marcos já ocorreu.

## 8. Limitações e riscos residuais

1. **Contrato ainda em rascunho.** A especificação e o exemplo atual definem tabela de opcodes em implementação, campos little-endian, `PRINT_CONST` como offset/length e a semântica observada pelo runtime; ainda faltam congelamento normativo, cap público de recursos, política normativa de overflow, códigos de erro estáveis e conformidade independente em outra ISA.
2. **Wasm/JVM não são especificação BRXE.** São referências arquiteturais e normativas externas. Não provam que o runtime assembly está correto nem que um loader BRXE existente aceita as regras propostas [1] [6].
3. **Portabilidade não é apenas arquivo.** Cada OS/ISA exige decoder/validator, executor, ABI de capabilities e drivers equivalentes. Mesmo bytes iguais podem produzir efeitos diferentes para filesystem, relógio, rede, random, locale, dispositivo ou política de segurança.
4. **Sandbox não substitui segurança do sistema.** Validação só protege propriedades realmente verificadas. Permanecem fora do escopo desta pesquisa hardening de kernel, privilégios Linux, segurança do driver, confidencialidade contra side channels, TOCTOU, disponibilidade de host calls bloqueantes e bugs do assembly [5].
5. **HAL é TCB.** Driver/adaptor pode acessar filesystem, dispositivos, memória ou syscalls. O manifesto limita autoridade solicitada, mas não torna automaticamente seguro um driver mal implementado; bounds, handles, concorrência, reentrância e quotas precisam ser validados em cada chamada.
6. **Gráficos são condicionais.** Vulkan, DRM, WDDM e APIs vendor expõem capacidades mediadas por drivers. Renderizar offscreen, controlar KMS, apresentar por compositor e acessar recursos privilegiados não são a mesma coisa [14] [15] [16] [20].
7. **Fuel não cobre tudo.** Fuel/epoch controlam o caminho guest conforme a política do runtime, mas não interrompem automaticamente host call bloqueante; wall-clock/cancelamento do adapter continua necessário [9].
8. **Bootstrap tem seed.** `as`/`ld`, kernel, CPU, firmware e ambiente continuam premissas. Stage0/Onramp mostram como reduzir e auditar seeds, não eliminá-los [32] [33] [34].
9. **Reprodutibilidade e DDC têm hipóteses.** Reprodutibilidade é condicionada ao ambiente fixado; DDC depende de compilador diverso confiável e determinismo [35] [36].
10. **W3C Core 2 é living standard.** O BRX deve congelar seu próprio documento normativo e não depender de números de seção ou opcodes WebAssembly [2].

## 9. Referências numeradas

[1] **W3C WebAssembly Core Specification 1.0** — ISA virtual, escopo do core, fases de execução e fronteira com embedder/imports. https://www.w3.org/TR/wasm-core-1/

[2] **W3C WebAssembly Core Specification 2 — Binary Format** — magic/version, seções, custom sections, LEB128, little-endian e política de versionamento. https://www.w3.org/TR/wasm-core-2/#binary-format

[3] **WebAssembly Core Specification — Validation: Instructions** — efeitos tipados de pilha, labels e validação de instruções. https://webassembly.github.io/spec/core/valid/instructions.html

[4] **WebAssembly Core Specification — Execution: Modules / Instantiation** — validade do módulo, matching de imports e traps na instanciação. https://webassembly.github.io/spec/core/exec/modules.html#exec-instantiation

[5] **WebAssembly Security** — sandbox, imports, CFI, bounds checks e limitações de segurança. https://webassembly.org/docs/security/

[6] **The Java Virtual Machine Specification SE 24 — Chapter 4: The class File Format** — magic, major/minor, big-endian, attributes e verificação estrutural. https://docs.oracle.com/javase/specs/jvms/se24/html/jvms-4.html

[7] **The Java Virtual Machine Specification SE 24 — Chapter 2: The Structure of the Java Virtual Machine** — máquina abstrata, frames, execução e liberdade de implementação/JIT. https://docs.oracle.com/javase/specs/jvms/se24/html/jvms-2.html

[8] **The Java Virtual Machine Specification SE 24 — Chapter 6: The Java Virtual Machine Instruction Set** — opcode, operandos, branches e verificação. https://docs.oracle.com/javase/specs/jvms/se24/html/jvms-6.html

[9] **Wasmtime — Interrupting Wasm Execution / Config API** — fuel, epochs e limite de host calls bloqueantes. https://docs.wasmtime.dev/examples-interrupting-wasm.html

[10] **Wasmtime ResourceLimiter API** — limites de memories/tables/instâncias e escopo da contabilidade de memória. https://docs.wasmtime.dev/api/wasmtime/trait.ResourceLimiter.html

[11] **WASI — Security** — capability-based security e deny-by-default. https://wasi.dev/security

[12] **WebAssembly Component Model — WIT Worlds** — imports/exports e obrigação do host de satisfazer imports. https://component-model.bytecodealliance.org/design/worlds.html

[13] **WebAssembly Component Model — WIT specification** — package IDs, semver, `@since`, `@unstable` e evolução compatível. https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md

[14] **Linux kernel — Userland interfaces / DRM UAPI** — render nodes, DRM master, permissões e interfaces de renderização. https://docs.kernel.org/gpu/drm-uapi.html

[15] **Linux kernel — Kernel Mode Setting (KMS)** — framebuffer, planes, CRTC, connectors e display. https://docs.kernel.org/gpu/drm-kms.html

[16] **Microsoft — WDDM Architecture** — runtime Direct3D, UMD, KMD, `dxgkrnl`, memória e scheduler. https://learn.microsoft.com/en-us/windows-hardware/drivers/display/windows-vista-and-later-display-driver-model-architecture

[17] **Microsoft — DXCore** — enumeração de adapters gráficos e de computação. https://learn.microsoft.com/en-us/windows/win32/dxcore/dxcore

[18] **Microsoft — IDXGIFactory6::EnumAdapterByGpuPreference** — enumeração e preferência de adapters. https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_6/nf-dxgi1_6-idxgifactory6-enumadapterbygpupreference

[19] **Microsoft — Hardware Feature Levels / DirectX 12 Programming Guide** — feature levels, `CheckFeatureSupport`, command queues e memória. https://learn.microsoft.com/en-us/windows/win32/direct3d12/hardware-feature-levels

[20] **Khronos — Vulkan Specification** — physical devices, queues, heaps, memória, formatos e capabilities. https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html

[21] **AMD — AMD Open Source Driver for Vulkan** — cobertura dependente de GPUs, distribuições, driver e PAL. https://gpuopen.com/amd-open-source-driver-for-vulkan/

[22] **NVIDIA CUDA Driver API — Device Management; Intel oneAPI Level Zero Specification** — enumeração/atributos de devices e API mediada por driver. https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__DEVICE.html ; https://oneapi-src.github.io/level-zero-spec/level-zero/latest/core/INTRO.html

[23] **Crafting Interpreters — Scanning; Representing Code; Parsing Expressions; Resolving and Binding** — tokens, spans, gramática, AST e análise semântica. https://craftinginterpreters.com/scanning.html

[24] **Crafting Interpreters — A Virtual Machine; Compiling Expressions** — bytecode stack-based, instruction pointer e emissão de instruções. https://craftinginterpreters.com/a-virtual-machine.html

[25] **LLVM Kaleidoscope — Parser/AST, Code Generation, Language Reference e Testing Guide** — separação parser/IR/verifier e organização de testes. https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/LangImpl02.html ; https://llvm.org/docs/tutorial/MyFirstLanguageFrontend/LangImpl03.html ; https://llvm.org/docs/LangRef.html ; https://llvm.org/docs/TestingGuide.html

[26] **ECMAScript Language Specification — Notational Conventions / Lexical Grammar** — tokens, spans, gramáticas e Early Errors. https://tc39.es/ecma262/multipage/notational-conventions.html

[27] **Python Language Reference — Lexical analysis / Full Grammar specification / Execution model** — fluxo de tokens, gramática formal, blocos, frames e ambientes. https://docs.python.org/3/reference/lexical_analysis.html

[28] **GNU Binutils** — assembler `as`, linker `ld` e ferramentas de objeto/ELF. https://www.gnu.org/software/binutils/

[29] **How to build and run the compiler — Rustc Dev Guide** — bootstrap stage0/stage1/stage2. https://rustc-dev-guide.rust-lang.org/building/how-to-build-and-run.html

[30] **Installing Go from source** — bootstrap do toolchain Go e `CGO_ENABLED=0`. https://go.dev/doc/install/source

[31] **GCC — Prerequisites for GCC; Installing GCC: Building** — dependências e bootstrap de estágios. https://gcc.gnu.org/install/prerequisites.html ; https://gcc.gnu.org/install/build.html

[32] **Bootstrappable Builds** — dependências circulares e redução de binários opacos de bootstrap. https://www.bootstrappable.org/

[33] **Stage0 bootstrap** — monitor hexadecimal, hex stages e cadeia auditável. https://man.sr.ht/~oriansj/bootstrappable/stage0.md

[34] **Onramp bootstrap path** — cadeia desde ferramenta hexadecimal/VM até assembler e compiladores. https://github.com/ludocode/onramp/blob/develop/docs/bootstrap-path.md

[35] **Reproducible Builds — Definitions; Perimeter; SOURCE_DATE_EPOCH** — ambiente fixado, identidade bit a bit e timestamps determinísticos. https://reproducible-builds.org/docs/definition/ ; https://reproducible-builds.org/docs/perimeter/ ; https://reproducible-builds.org/docs/source-date-epoch/

[36] **Fully Countering Trusting Trust through Diverse Double-Compiling** — DDC, hipóteses e evidência de correspondência entre fonte e binário. https://dwheeler.com/trusting-trust/ ; https://arxiv.org/abs/1004.5534

[37] **Ken Thompson — Reflections on trusting trust** — fonte primária sobre confiança em compiladores e executáveis. https://dl.acm.org/doi/10.1145/358198.358210

[38] **CPython InternalDocs — The bytecode interpreter** — laço de interpretação, opcode, argumento, dispatch e saltos. https://raw.githubusercontent.com/python/cpython/main/InternalDocs/interpreter.md

[39] **Lua 5.4 source — lvm.c** — dispatch e limites como decisões de implementação. https://www.lua.org/source/5.4/lvm.c.html

[40] **TC39 Test262 — ECMAScript Test Suite** — suíte de conformidade e ressalva de cobertura incompleta. https://github.com/tc39/test262

[41] **Microsoft Support — Microsoft basic display adapter in Windows** — fallback genérico embutido e comparação com o driver do fabricante. https://support.microsoft.com/en-us/windows/hardware/display-graphics/microsoft-basic-display-adapter-in-windows

[42] **Microsoft Learn — Microsoft Basic Display Driver** — uso em setup/safe mode/transição, linear framebuffer e limites de modo. https://learn.microsoft.com/en-us/windows-hardware/drivers/display/microsoft-basic-display-driver

---

**Síntese final:** o BRXE deve ser tratado como um contrato pequeno, versionado e validável, não como uma extensão acidental do assembly x86-64. O passe de validação atual já cobre o subconjunto linear, mas ainda falta completar P0 com erros/caps/testes normativos; em seguida, compiler, HAL com autodetecção/fallback por capability, controle de fluxo e ports devem ser etapas separadas. Fallback genérico é válido quando o host o oferece, mas não substitui um adapter universal que não existe. Essa ordem preserva compatibilidade possível, reduz riscos e torna cada alegação futura verificável.
