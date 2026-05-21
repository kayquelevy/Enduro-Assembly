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
- **Carros inimigos** em 4 cores (azul, laranja, verde-água, magenta) descendo pela pista, sempre dentro dos limites da pista (nunca colidindo visualmente com as zebras)
- Movimento lateral do carro do jogador com *bounds checking*
- Movimento vertical simulado por *scroll* do vetor de inimigos
- Geração pseudo-aleatória de inimigos (LCG em registradores)
- Detecção de colisão por sobreposição retangular
- Sistema de 3 vidas com invencibilidade temporária (8 *frames*)
- Efeito visual de pisca durante invencibilidade
- Placar +1 por *frame* sobrevivido (estilo Enduro original)
- HUD textual na aba *Run I/O* com *frame*, vidas e *score*
- Tela de *game over* com placar final

**Otimização chave de performance:** o cenário (gramado + pista) é pintado **uma única vez** no início; a cada *frame* apenas as regiões que mudam são repintadas (zebras animadas, faixa central, posições antigas e novas dos carros). Isso reduziu o custo do *render* de ~20 000 para ~700 instruções por *frame*.

---

## Como executar

> **A configuração do Bitmap Display é obrigatória.** Sem ela, o jogo monta mas dispara um erro "address out of range" assim que tenta pintar o primeiro pixel.

1. Instale o [RARS](https://github.com/TheThirdOne/rars/releases) (requer Java 8+).
2. Abra `enduro.asm` no RARS.
3. Vá em **Tools → Bitmap Display** e configure:

| Campo | Valor |
|---|---|
| Unit Width in Pixels | `8` |
| Unit Height in Pixels | `8` |
| Display Width in Pixels | `512` |
| Display Height in Pixels | `512` |
| Base address for display | `0x10010000 (static data)` |

4. Clique em **Connect to Program** e **mantenha a janela aberta**.
5. Volte à janela principal do RARS, pressione **F3** para *Assemble* e **F5** para *Run*.
6. Foque a aba **Run I/O** para usar os controles.

### Controles

| Tecla | Ação |
|---|---|
| `a` | Mover carro para a esquerda |
| `d` | Mover carro para a direita |
| `espaço` (ou qualquer tecla) | Avançar a pista sem mover o carro |
| `q` | Sair do jogo |

> No RARS é necessário pressionar **Enter** após cada tecla, pois `read_char` (*syscall* 12) lê de *stdin* em modo de linha. Para ver a animação fluir, basta apertar a tecla várias vezes seguidas.

### Solução de problemas comuns

- **"Address out of range 0xff000000"** — você esqueceu de clicar em *Connect to Program* na janela do Bitmap Display, ou fechou a janela antes de rodar.
- **Tela toda preta com pixels coloridos esquisitos** — o endereço base no Bitmap Display não bate com o `BITMAP_BASE` definido no código (`0x10010000`).
- **Erro "instrução desconhecida `mul`"** — vá em *Settings → RISC-V Settings* e habilite a extensão **RV32M**.
- **Carros sumindo nas bordas da pista** — corrigido nesta versão: a geração de inimigos é restrita às colunas 18 a 42, mantendo distância segura das zebras animadas.

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
- Colunas 16 e 47: **zebras** alternando vermelho/branco (animadas com `s3`)
- Colunas 17–46: **pista preta**
- Colunas 31–32: **faixa amarela tracejada** (animada com `s3`)
- Carros inimigos: colunas 18 a 42 (sempre dentro da pista)
- Carro do jogador: linha 56, controlado por `a`/`d`

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
 ├── pintar_cenario_inicial   pinta gramado + pista UMA VEZ
 └── game_loop
       ├── atualizar_zebras        repinta zebras animadas e faixa central
       ├── atualizar_inimigos      apaga posição antiga, desenha nova
       │     └── desenhar_carro
       ├── atualizar_jogador       move o carro vermelho do jogador
       │     └── desenhar_carro
       ├── hud_texto               imprime frame, vidas, score na Run I/O
       ├── ler_input               syscall 12 (read char)
       ├── processar_tecla         atualiza s0 com base na tecla
       ├── avancar_pista           rola vetor de inimigos
       │     └── gerar_inimigo     LCG + cor + coluna
       ├── checar_colisao          sobreposição retangular
       └── pontuar                 +1 por frame sobrevivido
```

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
