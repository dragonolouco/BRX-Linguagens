---
name: brx-language-bootstrap
description: Design and implement a new programming language from its grammar through an executable virtual machine. Use when creating a language from scratch without third-party libraries, bootstrapping a compiler, defining a portable bytecode/runtime, adding hardware/driver access, or planning self-hosting and cross-platform ports.
---

# Construir uma linguagem própria, seu executável e runtime

## Princípio central

Separe a **especificação da linguagem** da implementação que a executa. A sintaxe e a semântica podem ser portáteis. Se a meta é distribuir um mesmo arquivo binário a muitos sistemas, defina uma ISA virtual e um formato executável da linguagem (como BRXE), e construa um runtime para cada host. O bytecode será portátil entre runtimes compatíveis; cada runtime é um programa nativo e precisa ser instalado/portado.

Atenda “sem bibliotecas” implementando manualmente lexer, parser, runtime e integrações sem frameworks/bibliotecas de terceiros, conforme permitido pelo usuário. Não afirme que código executável pode existir sem qualquer camada prévia: há sempre um mecanismo de execução, carregamento e hardware subjacentes. Um bootstrap assembly pode evitar C/libc, mas ainda exige um assembler/linker inicial e um ABI/OS; escreva isso com transparência. Leia [architecture-and-bootstrap.md](references/architecture-and-bootstrap.md) para máquinas, bytecode, syscalls, drivers e limites.

## Fluxo de trabalho

1. **Definir os requisitos e hipóteses.** Identifique domínio/usuários, recursos do núcleo e alvos pretendidos. Diferencie requisito atual de recurso futuro.
2. **Especificar primeiro.** Fixe encoding/tokens, EBNF, precedência, tipos, semântica, variáveis, inicialização, escopo, ordem de avaliação, erros e limites. Para cada construção escreva exemplos válidos, inválidos e saídas esperadas.
3. **Implementar o front-end à mão.** Fazer scanner com posições, parser recursive descent/precedence-climbing, AST/IR, resolução de nomes, verificador semântico/tipos e executor, tudo sem geradores ou bibliotecas se o pedido exigir.
4. **Escolher o executável.** Para aplicações portáveis, especifique uma VM/ISA virtual e um bytecode/binário versionado (header, sections, opcodes, endianness, validação, stack/memory, traps). Separar o core bytecode das APIs específicas ao host. Não anunciar “um binário para qualquer máquina” sem runtimes conformes.
5. **Construir o runtime inicial.** Escreva manualmente o primeiro VM/runtime em baixo nível e documente linguagem/ISA, as/linker, OS, ABI, formato nativo e serviços usados. O runtime de cada host deve aceitar o mesmo arquivo virtual e passar os mesmos testes.
6. **Projetar a HAL.** Aplicativos importam capacidades estáveis (console, arquivos, memória, CPU info, GPU); adaptadores BRX convertem-nas para OS/driver existente. O app pode ignorar o OS se runtime+driver compatível estiverem disponíveis e autorizados.
7. **Não confundir HAL com acesso físico.** Driver instalado não concede acesso irrestrito: hosted runtime usa a interface/permissões do driver. Acesso bruto privilegiado exige runtime de kernel/bare-metal e suporte concreto a CPU/placa; isso é criar também uma parte do OS/driver.
8. **Testar por estágio.** Testar token/AST/semântica, bytecode bom e malformado, bounds, underflow, divisão por zero, opcodes inválidos, compatibilidade entre hosts e permissões de hardware. Manter regressões.
9. **Evoluir para auto-hospedagem.** Quando BRX puder ler arquivos, manipular buffers, controlar fluxo e emitir bytecode, escreva compilador em BRX e compile com versão anterior; comparar artefatos/testes. Self-hosting não remove a história do bootstrap.
10. **Entregar alegações verificáveis.** Reportar o que funciona, dependências externas, build/runtime/OS/ISA e targets não testados. Não reduzir o projeto a “brinquedo”; nomear escopo e versão e evitar alegar universalidade antes da validação.

## Regras para BRX

- Priorizar especificação portátil e módulos BRXE; o atual runtime x86-64/Linux é só um primeiro executor.
- Núcleo sem C/libc/terceiras bibliotecas. Assembler/linker de bootstrap e syscalls Linux são dependências do build/host atuais, não dependências de app BRXE depois que um VM estiver instalado.
- Definir formato BRXE versão/opcodes/traps com testes antes de afirmar compatibilidade.
- Criar `BRX-HAL` versionada e baseada em capacidades; especificar como cada adaptador lida com recursos ausentes.
- Antes de GPU, identificar família/geração/driver para o primeiro teste real; desenhar API de alto nível e backend por host, validar comandos e nunca fazer write a registradores desconhecidos.
- Registrar as diferenças entre aplicativo, arquivo virtual, runtime, adaptador, driver, kernel/OS e hardware.

## Referências

- Leia [architecture-and-bootstrap.md](references/architecture-and-bootstrap.md) para VM/ISA virtual, host services, syscalls e GPUs.
- Leia [brx-language-implementation.md](references/brx-language-implementation.md) para frontend, variáveis, gramática, testes e estado/roteiro da BRX.
