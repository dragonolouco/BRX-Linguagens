# Alvos, máquina virtual e acesso a dispositivos da BRX

## O aplicativo BRX pode ser portátil

O objetivo do projeto é que uma aplicação compile para um único formato executável da BRX — **BRXE**, código da ISA virtual BRX — e rode sem recompilação nos computadores que tenham um runtime BRX compatível. O aplicativo pode pedir serviços através de APIs de capacidade da BRX sem conter chamadas Linux, Windows ou macOS.

Essa é uma arquitetura de VM: a especificação BRX define instruções e significados; cada runtime traduz/interpreta essas instruções para a CPU do host. Uma implementação do runtime por sistema/arquitetura é o que faz um mesmo `.brxe` funcionar entre eles. O mesmo executável virtual não implica que um binário nativo `brxvm0` seja universal.

```text
aplicação .brx -> compilador BRX -> módulo .brxe portátil
                                       ↓
                  runtime BRX/host adaptado e instalado
                                       ↓
                        CPU + OS + drivers disponíveis
```

O usuário não precisa escolher o sistema para definir a **linguagem** ou o formato virtual. A equipe escolhe quais hosts suportar ao portar e testar o runtime. Um módulo que pede recursos ausentes (por exemplo, gráfico 3D) pode exigir runtime/driver com essa capacidade.

## Camadas do projeto

1. **Especificação BRX** — sintaxe, tipos, controle de fluxo e semântica independentes do alvo.
2. **Front-end** — scanner, parser, análise semântica e IR comum.
3. **Formato BRXE** — máquina virtual e binário portátil versionado; o mesmo arquivo é distribuído entre alvos.
4. **Runtime BRX** — carrega/valida e executa/JIT o bytecode em cada host.
5. **BRX-HAL (proposta)** — contrato de capacidades como console, arquivos, CPU info, memória, áudio e `BRX.GFX`; o app pede a capacidade e não o nome da syscall/driver.
6. **Adaptador do host/driver** — o runtime converte as chamadas BRX-HAL para o sistema, ABI e drivers instalados.
7. **Extensões específicas** — backend GPU/ISA por fabricante e geração quando operações gráficas comuns não bastarem.

O conteúdo normativo de BRXE deve ficar separado de APIs do host. WebAssembly faz essa separação explícita: o core define ISA binária, validação e semântica; I/O e integração pertencem ao embedding e às APIs do ambiente [1]. A especificação da Java VM também separa bytecode/class-file de cada implementação de runtime [2].

## Hardware e drivers instalados

A proposta do usuário — um programa BRX conversar com hardware por uma porta própria — é atendida no nível da aplicação: **se** o driver e o runtime/adaptador apropriados estiverem instalados e autorizados, o mesmo módulo BRXE pode pedir à HAL, por exemplo, para criar uma superfície gráfica ou consultar CPU/GPU sem saber qual OS atendeu ao pedido.

Essa abstração não faz um processo comum sair da memória/permissões controladas pelo OS. O driver é a ponte privilegiada entre o sistema e o dispositivo; runtime BRX usa a API publicada pelo driver. DRM no Linux, por exemplo, controla buffers, memória, submissão e sincronização via kernel/driver [3] [4]. O runtime BRX pode esconder diferenças para o aplicativo, mas ainda precisa de uma implementação de adaptador por host/driver.

“Direto” também pode significar acesso a registradores/ISA de GPU sem o driver de sistema. Isso é outro modo: exige suporte privilegiado e específico à placa; ou BRX precisa ser o próprio OS/driver/firmware do equipamento. Nesse modo desaparecem alguns serviços do OS, mas BRX passa a implementar boot, memória física, interrupções, agendamento e drivers — não é automático por o arquivo ser BRXE. RAM de uma VM hosted normalmente é memória virtual alocada pelo OS; RAM física/device memory requer mapeamento e privilégios autorizados.

Uma GPU tem ISA/command buffers por fabricante e geração; a ISA varia e não padroniza por si só alocação de memória, apresentação, firmware e driver. AMD publica manuais em famílias RDNA/CDNA [5]. BRX deve ter uma API gráfica portável de alto nível e, se necessário, extensões específicas. Não alegar suporte a todas as GPUs sem implementar e testar cada adaptador.

## O que já funciona e o que falta

O bootstrap `brx0` interpreta texto BRX em Linux x86-64. `brxvm0` é um runtime BRXE inicial, também Linux x86-64; executa um subconjunto de opcodes indicado em [FORMATO-EXECUTAVEL-BRX.md](FORMATO-EXECUTAVEL-BRX.md). Ainda não há compilador de fonte BRX para BRXE, runtime para outro OS/ISA nem HAL/dispositivo gráfico implementado. A meta de portabilidade é arquitetura do projeto; a matriz de alvos só cresce com runtimes e testes reais.

## Critérios para anunciar um host compatível

- Runtime nativo disponível para o par OS/ISA/ABI e versão BRXE declarada.
- O mesmo arquivo BRXE passa nos testes de conformidade em cada host, sem recompilação.
- Módulos que importam recursos ausentes recebem erro previsível ou alternativa documentada.
- Capacidades de hardware são solicitadas explicitamente e concedidas pelo host/driver.
- GPU listada por API, fabricante/geração/driver testados; nunca apenas “qualquer GPU”.

## Referências

[1] https://www.w3.org/TR/wasm-core-2/ — WebAssembly core e embedding APIs.
[2] https://docs.oracle.com/en/java/javase/26/docs/specs/jvms/jvms-1.html — Java VM e class-file/bytecode.
[3] https://docs.kernel.org/gpu/drm-mm.html — Linux DRM memory management.
[4] https://dri.freedesktop.org/docs/drm/gpu/driver-uapi.html — DRM driver UAPI.
[5] https://gpuopen.com/amd-gpu-architecture-programming-documentation/ — AMD GPU ISA documentation.
