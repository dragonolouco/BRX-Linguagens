# Como um programa BRX chega à CPU

## O caminho da versão atual

```text
arquivo .brx (texto)
  -> brx0, nosso interpretador escrito em assembly x86-64
  -> instruções de máquina x86-64 no executável ELF
  -> kernel Linux carrega o processo e mapeia memória/pilha
  -> CPU busca, decodifica e executa as instruções do processo
  -> instrução SYSCALL solicita serviços ao kernel (abrir/ler arquivo, escrever saída, encerrar)
  -> o kernel valida a solicitação e realiza a operação permitida
  -> retorno da syscall para o processo BRX
```

A linguagem BRX define o que significam `var`, `out` e as atribuições. A CPU não reconhece essas palavras. Quem as lê é o programa `brx0`, que foi montado em instruções x86-64. O processador executa essas instruções; o kernel fornece os serviços de processo e I/O.

## CPU não é a mesma coisa que kernel

A CPU executa instruções de máquina de sua arquitetura (neste bootstrap, x86-64): carregar dados, comparar, somar, saltar, chamar funções e assim por diante. O arquivo executável contém bytes codificados como essas instruções, além de metadados que o carregador do sistema entende.

Um programa comum começa em espaço de usuário. Não pode arbitrariamente ler disco, desenhar na tela física ou controlar dispositivos. No Linux, solicita essas operações ao kernel através da interface de chamadas de sistema. O kernel verifica argumentos e permissões, conversa com drivers/dispositivos quando necessário e devolve um resultado. Chamadas de sistema são uma interface do sistema operacional, não uma conversa direta e universal da linguagem com qualquer hardware.

## Exemplo: escrever a saída

No Linux x86-64, `write` é a syscall número 1. Para a chamada direta usada em `brx0`, o programa coloca o número em `RAX`, o descritor em `RDI`, o endereço do texto em `RSI` e o tamanho em `RDX`; executa a instrução `syscall`; e lê o retorno em `RAX`. O descritor `1` corresponde à saída padrão. Os números e convenções são específicos da ABI Linux x86-64; outra arquitetura/OS usa interface diferente.

O bootstrap faz a mesma classe de operação para abrir e ler o arquivo-fonte, escrever `out` e sair. Ele não chama `printf`, não usa libc e não importa uma biblioteca externa. Ainda usa o kernel Linux e instruções da ISA x86-64.

## O que “sem dependências” quer dizer neste estágio

- **Sem bibliotecas de terceiros:** sim.
- **Sem C ou runtime C:** sim para `brx0.s`.
- **Sem bibliotecas de sistema:** o ELF está ligado diretamente com `ld`, não precisa de libc dinâmica.
- **Sem ferramentas:** não; `as` transforma o texto assembly em objeto, e `ld` produz o ELF.
- **Sem sistema operacional:** não; o protótipo usa syscalls do Linux.
- **Sem arquitetura/instruções preexistentes:** não; x86-64 é o alvo.
- **Sem qualquer outra linguagem em toda a história:** impossível na etapa inicial prática. Assembly é a notação simbólica das instruções da máquina, mas ainda precisa de um assembler para virar bytes. Um processador executa bytes, não uma especificação textual recém-inventada.

## Bibliografia técnica

- Intel, *Intel 64 and IA-32 Architectures Software Developer’s Manuals*: arquitetura, instruções, registradores e programação de sistema.
- Linux man-pages, `syscall(2)`: instrução/ABI de syscall e registradores de argumentos em cada arquitetura.
- x86-64 psABI: interface de baixo nível e convenções do alvo x86-64.

## Referências

- https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
- https://man7.org/linux/man-pages/man2/syscall.2.html
- https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/master/x86-64-ABI/low-level-sys-info.tex
- https://docs.kernel.org/userspace-api/index.html
