# Como um programa BRX chega à CPU e aos dispositivos

## Dois caminhos de execução

O código-fonte textual atual passa por este caminho:

```text
arquivo .brx -> brx0 (interpretador assembly x86-64)
             -> instruções nativas ELF/Linux
             -> processo Linux -> CPU
```

O módulo executável virtual passa por outro caminho:

```text
arquivo .brxe -> runtime BRX nativo do host -> CPU/OS
               -> chamadas BRX-HAL -> adaptador/driver instalado -> dispositivo
```

O formato BRXE pretende ser o mesmo em todos os hosts compatíveis; `brxvm0` hoje prova só um primeiro runtime Linux x86-64, para poucos opcodes. A VM lê bytes e executa a semântica dos opcodes. A CPU do host executa as instruções nativas de `brxvm0` — ela ainda não entende a ISA virtual BRX diretamente.

## O que “conversar com hardware” significa

A interface BRX-HAL pode deixar o **aplicativo** independente do sistema: o programa pede uma capacidade (`console.write`, `cpu.info`, `gpu.create_surface`, por exemplo) pelo contrato BRX, e o runtime/adapter escolhe a chamada correta para OS, ABI e driver já instalados. Assim, se existir runtime e driver compatíveis com as permissões necessárias, o mesmo `.brxe` pode funcionar sem o app saber qual sistema está por baixo.

O comportamento automático pretendido é: sondar APIs/devices visíveis ao host → consultar capabilities e permissões → escolher backend específico acelerado → tentar um adapter genérico do OS, se existir → fallback básico/software, se cumprir o requisito → retornar erro legível se a capability obrigatória não existir. Recursos opcionais podem degradar; o app não seleciona marca/modelo. Isso não instala driver nem contorna permissões. A Microsoft documenta o Basic Display Adapter como fallback genérico com recursos gráficos básicos quando o driver do fabricante falta; o driver específico entrega recursos e desempenho melhores [7] [8]. Não há um driver único que automaticamente cubra todo tipo de hardware.

No modo hosted normal, o runtime BRX e o aplicativo executam em memória virtual sob controle do OS. O runtime pede ao OS operações permitidas, e usa interfaces de driver para acessar dispositivos. O Linux, por exemplo, usa syscalls: na ABI Linux x86-64 o número fica em RAX, os seis argumentos em RDI, RSI, RDX, R10, R8, R9 e o resultado em RAX [2]. Isso não é acesso irrestrito nem elimina kernel/driver. A especificação WebAssembly separa seu core virtual das APIs que integram o módulo a cada ambiente; BRX-HAL deve seguir separação semelhante [6].

Se por “diretamente” quisermos dizer escrever em registradores de GPU ou controlar memória física sem usar o driver/OS, BRX terá de rodar privilegiada — implementando um kernel/OS/driver ou em bare-metal — e suportar uma placa/ISA concreta. Nesse modelo a linguagem ganha controle, mas também assume boot, memória física e virtual, interrupções, processos, driver e segurança. Um driver já instalado não concede por si só acesso bruto: o runtime precisa usar a interface que o driver publica, e o host pode exigir permissões.

## CPU

A CPU física só executa sua ISA nativa. O bootstrap atual executa `CPUID` leaf 0 para ler a cadeia do fabricante x86 e imprime EBX, EDX, ECX. CPUID é específico de x86; virtualização pode mascarar dados ou expor uma CPU virtual. No futuro, `BRX.HW.CPU_INFO` pode oferecer uma chamada de alto nível idêntica em `.brxe`, com implementação distinta por arquitetura [1].

## GPU

GPU tem outra ISA, buffers de memória, filas/comandos e sincronização. Para app portátil, BRX define operações gráficas comuns e adaptadores convertem-nas para driver disponível. No Linux, DRM/driver gerencia buffers, mapeamentos, execução e sincronização [3] [4]. Pode-se evitar Mesa/OpenGL/Vulkan como bibliotecas de usuário se BRX implementar a integração diretamente, mas o driver/kernel continuam presentes no modo hosted.

Comando de GPU de baixo nível varia por geração. Os manuais AMD RDNA/CDNA são separados por arquitetura [5]; conhecer ISA não substitui o UAPI do driver, firmware, sincronização nem acesso autorizado. A primeira implementação gráfica precisa identificar placas e drivers testados, criar superfícies/buffers de teste e falhar com segurança em hardware não suportado. Não emitir opcode/registro desconhecido contra uma GPU real.

## Dependências e estado comprovado

- **Bibliotecas de terceiros:** nenhuma usada pelos executores assembly `brx0` e `brxvm0`.
- **C/libc:** não usados na implementação desses executores.
- **Build:** GNU `as` + `ld`.
- **Execução testada:** Linux x86-64; binários sem `PT_INTERP` no build de teste.
- **Fonte:** `brx0` lê `.brx`, interpreta inteiros/expressões e consulta CPU via CPUID.
- **BRXE:** `brxvm0` lê um módulo binário de até 131071 bytes com pilha inteira e 256 slots locais; um verificador linear checa estrutura, literais, stack-depth e inicialização de locais antes de produzir saída. O compilador `.brx`→`.brxe`, autodetecção/HAL e ports multicross-platform faltam.
- **GPU/adapters:** ainda não implementados.

“Sem biblioteca” descreve os executores atuais, não independência total de ambiente: o Linux carrega os processos e fornece syscalls, e o assembler/linker geram o ELF inicial. O executável virtual BRXE não depende do formato nativo do host, mas depende de um runtime BRX instalado nele.

## Referências

[1] Intel Software Developer’s Manual: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
[2] Linux man-pages `syscall(2)`: https://man7.org/linux/man-pages/man2/syscall.2.html
[3] Linux DRM memory management: https://docs.kernel.org/gpu/drm-mm.html
[4] Linux DRM driver UAPI: https://dri.freedesktop.org/docs/drm/gpu/driver-uapi.html
[5] AMD GPU architecture programming documentation: https://gpuopen.com/amd-gpu-architecture-programming-documentation/
[6] WebAssembly core specification: https://www.w3.org/TR/wasm-core-2/
[7] Microsoft Basic Display Adapter: https://support.microsoft.com/en-us/windows/hardware/display-graphics/microsoft-basic-display-adapter-in-windows
[8] Microsoft Basic Display Driver: https://learn.microsoft.com/en-us/windows-hardware/drivers/display/microsoft-basic-display-driver
