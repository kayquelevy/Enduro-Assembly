# Enduro RV32I

Implementação simplificada do jogo **Enduro** (Activision, 1983, Atari 2600) em **Assembly RISC-V (RV32I)** para o simulador **RARS**.

> Trabalho da disciplina Arquitetura de Computadores — 7º Semestre, Unisantos 2026
>
> Kayque de Jesus Levy Rodrigues (6593272) e Miguel Nepomuceno Gil (5196718)

---

## Status

- [x] **Etapa 1** — Estudo da ISA RV32I, *syscalls* do RARS e análise do Enduro original
- [x] **Etapa 2** — Movimentação em X e Y, renderização da pista e geração de obstáculos
- [ ] **Etapa 3** — Detecção de colisão e placar
- [ ] **Etapa 4** — Análise arquitetural, otimizações e relatório final

---

## O que está implementado

- Pista textual com **8 linhas verticais**
- Carro controlado pelo jogador na linha inferior
- **Movimento lateral** (eixo X) com *bounds checking*
- **Movimento vertical** simulado por *scroll* do vetor de obstáculos (eixo Y)
- **Obstáculos** `X` descendo pela pista a cada avanço
- **Gerador pseudo-aleatório (LCG)** implementado inteiramente em registradores
- **HUD** com contador de frames e posição X do carro
- Limpeza de tela por *frame* via *escape* ANSI

---

## Como executar

1. Instale o [RARS](https://github.com/TheThirdOne/rars/releases) (requer Java 8+).
2. Abra `enduro.asm` no RARS.
3. Pressione **F3** para *Assemble*.
4. Pressione **F5** para *Run*.
5. Foque a aba **Run I/O** e use os controles abaixo.

### Controles

| Tecla | Ação |
|---|---|
| `a` | Mover carro para a esquerda |
| `d` | Mover carro para a direita |
| `espaço` (ou qualquer tecla) | Avançar a pista sem mover o carro |
| `q` | Sair do jogo |

> No RARS é necessário pressionar **Enter** após cada tecla, pois `read_char` (*syscall* 12) lê de *stdin* em modo de linha.

> Se a tela aparecer com lixo do tipo `[2J[H`, a aba **Run I/O** do seu RARS não está interpretando os *escape codes* ANSI. Basta comentar a chamada que imprime `limpa_tela` no início de `render` — o jogo continua funcional, apenas empilha os *frames* um abaixo do outro.

### Saída esperada

```
=== ENDURO RV32I (Etapa 2) ===
'a'/'d'=lados  ' '=avancar  'q'=sair
+---------+
|  X      |
|         |
|       X |
|    X    |
|         |
| X       |
|         |
|    C    |
+---------+

Frame: 12  Pos X: 4
```

---

## Estrutura do repositório

```
Enduro-Assembly/
├── README.md                Este arquivo
├── enduro.asm               Código-fonte RV32I
└── docs/
    ├── entrega-etapa-1.docx Relatório da Etapa 1
    └── entrega-etapa-2.docx Relatório da Etapa 2
```

---

## Convenção de registradores

Todo o estado global do jogo é mantido em registradores `s` (*callee-saved*), evitando *loads* e *stores* a cada *frame*:

| Registrador | Uso |
|---|---|
| `s0` | Posição X do carro (0 a 8) |
| `s1` | Semente do LCG (gerador pseudo-aleatório) |
| `s2` | Score *(reservado — Etapa 3)* |
| `s3` | Contador de *frames* |
| `s4` | *Flag* de jogo ativo (1 = rodando, 0 = sair) |
| `s5` | Endereço base do vetor de obstáculos |
| `s6` | Índice de linha durante o *render* (salvo na pilha) |

---

## Arquitetura do código

```
main
 └── game_loop
       ├── render             desenha 8 linhas + carro
       │     └── reset_buffer limpa o buffer de linha
       ├── debug_info         imprime frame e posição
       ├── ler_input          syscall 12 (read char)
       └── atualizar          processa tecla
             └── avancar_pista
                   └── gerar_obstaculo  LCG em registradores
```

---

## Custo de instruções por *frame*

| Etapa | Instruções/*frame* | Funcionalidade |
|---|---|---|
| Etapa 1 | ~92 | *Game loop* mínimo, 1 linha |
| **Etapa 2** | **~370** | 8 linhas, obstáculos, RNG, *scroll* |
| Etapa 3 (estimado) | ~400 | + colisão + placar |

A estimativa é manual; será refinada com o *Instruction Counter* do RARS no relatório final.

---

## Referências

- D. A. Patterson e J. L. Hennessy, *Computer Organization and Design — RISC-V Edition*, 2ª ed., Morgan Kaufmann, 2020.
- RISC-V International, *The RISC-V Instruction Set Manual, Vol. I: Unprivileged ISA*. Disponível em <https://riscv.org/specifications/>.
- N. Montfort e I. Bogost, *Racing the Beam: The Atari Video Computer System*, MIT Press, 2009.
- J. Larus, *RARS — RISC-V Assembler and Runtime Simulator*. Disponível em <https://github.com/TheThirdOne/rars>.
