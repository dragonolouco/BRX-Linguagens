# Arquitetura, bootstrap, VM e hardware

## Fonte, linguagem, arquivo virtual e máquina

A especificação BRX define programas válidos e seu significado; não é por si só um executável. Para rodar fonte, uma implementação interpreta ou compila. Uma alternativa portátil é definir **ISA virtual + formato binário BRXE + semântica de execução**. Java VM faz isso com instruções bytecode e class-files [1]. WebAssembly define virtual ISA, codificação, validação e semântica, deixando I/O/integração com o ambiente a APIs de embedding [2].

O módulo BRXE pode ser o executável virtual distribuído: um mesmo `.brxe` roda sem recompilação em hosts que tenham um runtime BRX compatível com sua versão/opcodes/capacidades. O runtime é um programa nativo diferente, portado para OS/ISA; interpreta ou JIT o bytecode. Isso atinge portabilidade do **app**, não elimina implementação do runtime, instalação, OS/kernel ou carregamento. Um app que usa capacidade não instalada não pode funcionar integralmente no host.

Camadas recomendadas:

```text
fonte -> frontend -> IR -> módulo BRXE -> runtime do host -> CPU/OS
                                               └-> HAL/adaptador/driver -> dispositivo
```

Native backend por alvo pode ser opção, mas não deve ser confundido com o formato virtual portátil.

## Serviços de host e HAL

Defina APIs importadas versionadas como `BRX.IO`, `BRX.HW.CPU_INFO`, `BRX.MEM` e `BRX.GFX`; declare capacidades/permissões. O adaptador BRX mapeia-as para o OS e driver instalados. Isso permite que o **app** não cite Linux/Windows, enquanto o runtime/hardware integration trata diferenças nativas.

Em processo hospedado, RAM do app é normalmente memória virtual atribuída pelo OS. Driver instalado oferece interfaces autorizadas; não significa acesso bruto ao hardware nem contorna controles do OS. Linux syscalls entram no kernel; no x86-64 o número e argumentos seguem ABI documentada por syscall(2) [3].

GPU tem arquitetura, memória, comandos e sincronização próprios. Linux DRM documenta buffers/mapeamentos/execução e driver UAPI [4][5]. É possível evitar bibliotecas de usuário tipo Mesa/OpenGL/Vulkan implementando seu próprio adaptador que fale com UAPI, mas kernel/driver continuam necessários. AMD publica ISA dividida por geração/família [6]; especificação ISA não é um driver completo.

Acesso bruto privilegiado ou bare-metal é diferente: o projeto precisa ser kernel/OS/driver/firmware e implementar boot, memória, interrupções, isolamento e dispositivos para hardware específico. Não é consequência automática de bytecode ou de guardar a aplicação em “memória BRX”.

## Bootstrap

O primeiro compilador/runtime deve ser executado por algum substrato. Uma forma de evitar C e bibliotecas de terceiros é escrever manualmente o bootstrap em assembly e fazer syscalls diretas. O bootstrap atual usa GNU `as` e `ld`, Linux x86-64, ELF e a ISA da CPU; evita C/libc e bibliotecas externas. Isso é “sem C/bibliotecas”, não “sem ferramentas/sistema”. Escrever bytes manualmente também precisa de mecanismo para carregá-los.

Auto-hospedagem é quando compilador em BRX compila seu próprio fonte; exige uma geração anterior confiável para bootstrap. Rust e Go documentam compiladores anteriores/seed; GCC usa vários estágios [7][8][9]. Recompilar não prova, por si, que o seed e hardware são confiáveis; Thompson descreveu risco de trust chain [10].

## CPU

CPU executa instruções da ISA nativa e não reconhece palavras de alto nível. `hw cpu` no bootstrap x86-64 consulta CPUID leaf 0 (EBX, EDX, ECX); outra ISA exige caminho próprio. VM/hypervisor pode filtrar/virtualizar dados. Uma operação BRX-HAL estável pode esconder o mecanismo, não tornar a instrução universal.

## Fontes primárias

[1] Java Virtual Machine Specification — https://docs.oracle.com/en/java/javase/26/docs/specs/jvms/jvms-1.html
[2] W3C WebAssembly Core Specification — https://www.w3.org/TR/wasm-core-2/
[3] Linux syscall(2) — https://man7.org/linux/man-pages/man2/syscall.2.html
[4] Linux DRM memory management — https://docs.kernel.org/gpu/drm-mm.html
[5] DRM Driver UAPI — https://dri.freedesktop.org/docs/drm/gpu/driver-uapi.html
[6] AMD GPU Architecture Programming Documentation — https://gpuopen.com/amd-gpu-architecture-programming-documentation/
[7] Rust bootstrap guide — https://rustc-dev-guide.rust-lang.org/building/bootstrapping/intro.html
[8] Go source installation — https://go.dev/doc/install/source
[9] GCC build stages — https://gcc.gnu.org/install/build.html
[10] Ken Thompson, “Reflections on Trusting Trust” — https://dl.acm.org/doi/10.1145/358198.358210
