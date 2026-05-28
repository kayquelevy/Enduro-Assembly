# Enduro RV32I

Implementação simplificada do jogo **Enduro** (Activision, 1983, Atari 2600) em **Assembly RISC-V (RV32I)** para o simulador **RARS**, com renderização gráfica via **Bitmap Display**.

> Trabalho da disciplina Arquitetura de Computadores — 7º Semestre, Unisantos 2026
>
> Kayque de Jesus Levy Rodrigues (6593272) e Miguel Nepomuceno Gil (5196718)

---

## Status

- [x] **Etapa 1** — Estudo da ISA RV32I, *syscalls* do RARS e análise do Enduro original
- [x] **Etapa 2** — Movimentação em X e Y, renderização da pista e geração de obstáculos
- [x] **Etapa 3** — Detecção de colisão, sistema de vidas, placar **e versão gráfica completa**
- [ ] **Etapa 4** — Análise arquitetural, otimizações e relatório final

---

## O que está implementado

O jogo está **completamente jogável e com renderização gráfica colorida**:

- **Cenário gráfico 64×64 pixels** desenhado via Bitmap Display do RARS
- **Gramado verde** nas laterais da pista
- **Pista preta** com **zebras vermelho/branco animadas** nas bordas
- **Faixa amarela tracejada** no centro da pista, animada para dar sensação de movimento
- **Carro do jogador** vermelho na parte inferior da tela
- **Carros inimigos** em 4 cores (azul, laranja, verde-água, magenta) descendo pela pista em **duas faixas laterais** — cols `{18, 20, 22, 24, 26}` à esquerda e `{34, 36, 38, 40, 42}` à direita —, nunca cruzando a faixa amarela central
- **Pista anda sozinha** a ~12 fps com `syscall 32` (sleep 80 ms); `avancar_pista` a cada 4 frames para dar tempo de reação
- **Input não-bloqueante via MMIO** (`0xFFFF0000`/`0xFFFF0004`) — o jogo flui mesmo sem teclas; controles via janela do *Keyboard and Display MMIO Simulator*
- Movimento lateral do carro do jogador com *bounds checking*
- Geração pseudo-aleatória de inimigos (LCG em registradores)
- Detecção de colisão por sobreposição retangular com *threshold* 5 (contato lateral já dispara)
- Sistema de 3 vidas com invencibilidade temporária (8 *frames*)
- Efeito visual de pisca durante invencibilidade
- Placar +1 a cada *scroll* sobrevivido
- **HUD gráfica no próprio bitmap**: vidas como quadradinhos vermelhos no gramado esquerdo; *score* como dígitos brancos 3×5 (fonte bitmap *custom*) no gramado direito — sem mais saída textual na *Run I/O* durante o jogo
- Tela de *game over* com placar final na *Run I/O*

**Otimização chave de performance:** o cenário (gramado + pista) é pintado **uma única vez** no início; a cada *frame* apenas as regiões que mudam são repintadas (zebras animadas, faixa central, posições antigas e novas dos carros). Isso reduziu o custo do *render* de ~20 000 para ~700 instruções por *frame*.

---

## Como executar

> **Duas ferramentas do RARS precisam estar conectadas antes do `F5`.** Sem o *Bitmap Display* o jogo dispara `address out of range` ao pintar o primeiro pixel; sem o *Keyboard and Display MMIO Simulator* o input não é lido (o jogo roda mas o carrinho não se move).

1. Instale o [RARS](https://github.com/TheThirdOne/rars/releases) (requer Java 8+).
2. Abra `enduro e3.asm` no RARS.
3. Vá em **Tools → Bitmap Display** e configure:

| Campo | Valor |
|---|---|
| Unit Width in Pixels | `8` |
| Unit Height in Pixels | `8` |
| Display Width in Pixels | `512` |
| Display Height in Pixels | `512` |
| Base address for display | `0x10010000 (static data)` |

   Clique em **Connect to Program** e **mantenha a janela aberta**.

4. Vá em **Tools → Keyboard and Display MMIO Simulator**, clique em **Connect to Program** e **mantenha a janela aberta** (sem isso o programa não recebe teclas).

5. Volte à janela principal, pressione **F3** para *Assemble* e **F5** para *Run*.

6. Para mover o carrinho, clique na caixa de texto **inferior (KEYBOARD)** da janela do MMIO Simulator — é nela que as teclas são enviadas ao endereço `0xFFFF0004` que o programa lê.

### Controles

| Tecla | Ação |
|---|---|
| `a` | Mover carro 2 pixels para a esquerda |
| `d` | Mover carro 2 pixels para a direita |
| `q` | Sair do jogo |

> O input é **não-bloqueante** (lido por *polling* MMIO em `0xFFFF0000`). A pista anda sozinha — você só precisa apertar `a`/`d` quando quiser se deslocar. Não precisa de Enter depois.

### Solução de problemas comuns

- **"Address out of range 0xff000000"** — você esqueceu de clicar em *Connect to Program* na janela do Bitmap Display, ou fechou a janela antes de rodar.
- **Carrinho não se move quando aperto `a`/`d`** — você esqueceu de abrir e conectar o *Keyboard and Display MMIO Simulator*, ou está digitando no Run I/O em vez da caixa KEYBOARD do MMIO Simulator.
- **Tela toda preta com pixels coloridos esquisitos** — o endereço base no Bitmap Display não bate com o `BITMAP_BASE` definido no código (`0x10010000`).
- **Erro "instrução desconhecida `mul`/`rem`/`div`"** — vá em *Settings → RISC-V Settings* e habilite a extensão **RV32M**.
- **Jogo termina em ~3 segundos** — quase certo que o sleep `syscall 32` não está habilitado no seu RARS; verifique se a opção *Settings → Enable system call extensions* está marcada.

---

## Layout do cenário

```
┌──────┬──┬──────────────┬──┬──────┐
│ gram │░░│   pista      │░░│ gram │
│ ado  │░░│  ─ ─ ─ ─     │░░│ ado  │
│      │██│              │██│      │
│      │░░│   [inimigo]  │░░│      │
│      │░░│  ─ ─ ─ ─     │░░│      │
│      │██│              │██│      │
│      │░░│              │░░│      │
│      │░░│      [JOGADOR]│░░│      │
└──────┴──┴──────────────┴──┴──────┘
 0   15 16              47 48   63
```

- Colunas 0–15 e 48–63: **gramado verde** (estático)
- Cantos superiores do gramado: **HUD gráfica** — vidas (esq.) e *score* (dir.)
- Colunas 16 e 47: **zebras** alternando vermelho/branco (animadas com `s3`)
- Colunas 17–46: **pista preta**
- Colunas 31–32: **faixa amarela tracejada** (animada com `s3`)
- Carros inimigos: faixa esquerda `{18, 20, 22, 24, 26}` ou faixa direita `{34, 36, 38, 40, 42}` — nunca no meio (preserva a faixa amarela)
- Carro do jogador: linha 56, controlado por `a`/`d` (range 18 a 42)

---

## Estrutura do repositório

```
Enduro-Assembly/
├── README.md                Este arquivo
├── enduro.asm               Código-fonte RV32I (versão gráfica)
└── docs/
    ├── entrega-etapa-1.docx Relatório da Etapa 1
    ├── entrega-etapa-2.docx Relatório da Etapa 2
    └── entrega-etapa-3.docx Relatório da Etapa 3
```

---

## Layout da memória

O Bitmap Display do RARS é *memory-mapped* — uma região contígua da memória é interpretada como matriz de pixels. Como na nossa versão do RARS o endereço `0xFF000000` não está disponível, usamos `0x10010000` (static data). Para evitar que as variáveis do programa fossem interpretadas como pixels, o `.data` reserva os 16 384 bytes do bitmap **antes** de qualquer outra variável:

```
0x10010000 ─┬─────────────────────────┐
            │  bitmap_area (16 KB)    │  ← região visível do display
            │  64 × 64 × 4 bytes      │
0x10014000 ─┼─────────────────────────┤
            │  pos_anterior           │
            │  vetor inimigos[8]      │  ← variáveis do programa
            │  ini_anterior[8]        │     (fora da área visível)
            │  tabela_cores[4]        │
            │  strings de UI          │
            └─────────────────────────┘
```

---

## Convenção de registradores

Todo o estado global do jogo é mantido em registradores `s` (*callee-saved*):

| Registrador | Uso |
|---|---|
| `s0` | Posição X do carro (18 a 42) |
| `s1` | Semente do LCG (gerador pseudo-aleatório) |
| `s2` | *Score* (incrementa por *frame*) |
| `s3` | Contador de *frames* (também controla animações da pista) |
| `s4` | *Flag* de jogo ativo (1 = rodando, 0 = *game over*) |
| `s5` | Endereço base do vetor de inimigos |
| `s6` | Vidas restantes (inicia em 3) |
| `s7` | Contador de invencibilidade pós-colisão |
| `s8` | Endereço base do Bitmap Display (`0x10010000`) |
| `s9`, `s10`, `s11` | Índices temporários no *render* (salvos na pilha) |

---

## Arquitetura do código

```
main
 ├── pintar_cenario_inicial    pinta gramado + pista UMA VEZ
 └── game_loop                  (loop com sleep 80 ms / ~12 fps)
       ├── ler_input             MMIO 0xFFFF0000 (NÃO bloqueante)
       ├── processar_tecla       atualiza s0 com base na tecla
       ├── (a cada 4 frames):
       │     ├── avancar_pista   rola vetor de inimigos
       │     │     └── gerar_inimigo   LCG + 2 faixas laterais
       │     └── pontuar         +1 por scroll sobrevivido
       ├── checar_colisao        sobreposição retangular (threshold 5)
       ├── atualizar_inimigos    apaga posição antiga, desenha nova
       │     └── desenhar_carro
       ├── atualizar_zebras      repinta zebras + faixa central
       │                          (POR CIMA dos inimigos: preserva faixa)
       ├── atualizar_jogador     desenha jogador (POR CIMA da faixa: sólido)
       │     └── desenhar_carro
       └── desenhar_hud_grafico  vidas (esq.) e score (dir.) no bitmap
             └── desenhar_digito  fonte bitmap 3×5
```

**Ordem importante:** input/lógica/colisão **antes** do render para garantir que o que é renderizado é exatamente o que foi checado por colisão. `atualizar_zebras` roda **depois** dos inimigos para que a faixa central nunca seja apagada pelo *erase* de um inimigo que passa pela coluna 31/32 (embora hoje os inimigos sejam restritos a faixas laterais, a ordem se mantém pela robustez). `atualizar_jogador` roda **por último** entre os elementos de pista para que o jogador apareça sólido por cima de tudo (sem a faixa tracejada atravessando-o).

---

## Custo de instruções por *frame*

| Etapa | Instruções/*frame* | Funcionalidade |
|---|---|---|
| Etapa 1 | ~92 | *Game loop* mínimo, texto |
| Etapa 2 | ~370 | 8 linhas textuais, obstáculos, RNG |
| Etapa 3 (texto) | ~385 | + colisão + vidas + placar (texto) |
| **Etapa 3 (gráfica, otimizada)** | **~700** | Versão final: cenário + 4 cores + animações |

A versão gráfica com **render incremental** (cenário pintado uma vez, só repinta o que muda) ficou apenas ~2× mais cara que a versão textual final, apesar de manipular 4 096 pixels coloridos em vez de 80 caracteres. Esse é exatamente o tipo de análise arquitetural que a Etapa 4 vai aprofundar: como decisões de software (onde redesenhar, o que cachear) compensam ausências de hardware dedicado (não temos chip TIA como o Atari).

---

## Cores utilizadas

Cada pixel do bitmap é uma *word* no formato `0x00RRGGBB`:

| Elemento | Cor (hex) | Cor visual |
|---|---|---|
| Gramado | `0x00228B22` | Verde escuro |
| Pista | `0x00202020` | Preto/cinza |
| Zebra (vermelho) | `0x00CC0000` | Vermelho |
| Zebra (branco) | `0x00FFFFFF` | Branco |
| Faixa central | `0x00FFFF00` | Amarelo |
| Carro do jogador | `0x00FF0000` | Vermelho vivo |
| Inimigo 1 | `0x000088FF` | Azul |
| Inimigo 2 | `0x00FFAA00` | Laranja |
| Inimigo 3 | `0x0000FF88` | Verde-água |
| Inimigo 4 | `0x00FF00FF` | Magenta |

---

## Referências

- D. A. Patterson e J. L. Hennessy, *Computer Organization and Design — RISC-V Edition*, 2ª ed., Morgan Kaufmann, 2020.
- RISC-V International, *The RISC-V Instruction Set Manual, Vol. I: Unprivileged ISA*. Disponível em <https://riscv.org/specifications/>.
- N. Montfort e I. Bogost, *Racing the Beam: The Atari Video Computer System*, MIT Press, 2009.
- J. Larus, *RARS — RISC-V Assembler and Runtime Simulator*. Disponível em <https://github.com/TheThirdOne/rars>.
