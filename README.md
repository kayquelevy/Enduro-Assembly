# Enduro RV32I

Implementação simplificada do jogo Enduro (Activision, 1983, Atari 2600) em Assembly RISC-V (RV32I) para o simulador RARS.

> Trabalho de Arquitetura de Computadores — 2026
> Kayque de Jesus Levy Rodrigues (6593272) e Miguel Nepomuceno Gil (5196718)

---

## Status

- [x] Etapa 1 — Estudo da ISA RV32I, *syscalls* do RARS e análise do Enduro original
- [x] *Game loop* mínimo funcional (prova de conceito)
- [ ] Etapa 2 — Movimentação completa e renderização da pista (em andamento)
- [ ] Etapa 3 — Obstáculos, colisão e placar
- [ ] Etapa 4 — Análise arquitetural, otimizações e relatório final

---

## Como executar

1. Instale o [RARS](https://github.com/TheThirdOne/rars) (requer Java 8+).
2. Abra `src/enduro.asm` no RARS.
3. Pressione F3 para *Assemble*.
4. Pressione F5 para *Run*.
5. Foque a aba Run I/O e use os controles abaixo.

### Controles

| Tecla | Ação |
|---|---|
| `a` | Mover carro para a esquerda |
| `d` | Mover carro para a direita |
| `q` | Sair do jogo |

> No RARS é necessário pressionar Enter após cada tecla, pois `read_char` (*syscall* 12) lê de *stdin* em modo de linha.

### Saída esperada

```
=== ENDURO RV32I (Prova de Conceito) ===
Controles: 'a'=esq  'd'=dir  'q'=sair

+---------+
|    C    |
+---------+
Frame: 0  | Pos X: 4
```

---

## Estrutura do repositório

```
enduro-rv32i/
├── README.md
├── docs/
│   └── entrega-etapa-1.md      Documento da entrega parcial
└── src/
    └── enduro.asm              Prova de conceito do game loop
```

---

## Convenção de registradores

| Registrador | Uso |
|---|---|
| `s0` | Posição X do carro |
| `s1` | Velocidade *(Etapa 2)* |
| `s2` | Score *(Etapa 3)* |
| `s3` | Contador de frames |
| `s4` | *Flag* de jogo ativo |

---

## Referências

- D. A. Patterson e J. L. Hennessy, *Computer Organization and Design — RISC-V Edition*, 2ª ed., Morgan Kaufmann, 2020.
- RISC-V International, *The RISC-V Instruction Set Manual, Vol. I: Unprivileged ISA*. Disponível em https://riscv.org/specifications/.
- N. Montfort e I. Bogost, *Racing the Beam: The Atari Video Computer System*, MIT Press, 2009.
- J. Larus, *RARS — RISC-V Assembler and Runtime Simulator*. Disponível em https://github.com/TheThirdOne/rars.
