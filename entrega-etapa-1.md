# Entrega Parcial — Enduro RV32I

**Disciplina:** Arquitetura de Computadores — 2026
**Etapa:** 1 (concluída) + início da Etapa 2
**Data:** 07 de maio de 2026

**Autores:**
- Kayque de Jesus Levy Rodrigues — 6593272
- Miguel Nepomuceno Gil — 5196718

---

## 1. Status do projeto

A proposta foi aceita em 30/04/2026. Nesta primeira semana concluímos a **Etapa 1** do cronograma (estudo da ISA RV32I, das *syscalls* do RARS e análise do Enduro original) e adiantamos parte da **Etapa 2** com uma prova de conceito do *game loop* já funcional no simulador.

| Entregável desta apresentação | Status |
|---|---|
| Estudo da ISA RV32I (instruções a serem usadas) | Concluído |
| Levantamento das *syscalls* do RARS | Concluído |
| Definição da convenção de uso de registradores | Concluído |
| Protótipo do *game loop* rodando no RARS | Concluído |
| Renderização textual da pista | Concluído |
| Leitura de teclado e movimentação do carro | Concluído |
| Repositório GitHub inicializado | Concluído |
| Obstáculos, colisão, placar | Próximas etapas |

---

## 2. Estudo da ISA RV32I — instruções selecionadas para o projeto

Após leitura do *RISC-V Unprivileged ISA Manual* e do capítulo 2 de Patterson & Hennessy, mapeamos o subconjunto da RV32I que será suficiente para todo o jogo. A escolha privilegia instruções de baixo custo (1 ciclo no modelo *single-cycle* do RARS) e evita pseudo-instruções caras quando o equivalente direto é viável.

**Aritméticas / lógicas (registrador-imediato):**
`addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`

**Aritméticas / lógicas (registrador-registrador):**
`add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`

**Acesso à memória:**
`lw`, `sw` (estado global em `.data`), `lbu`, `sb` (manipulação de caracteres na pista textual)

**Controle de fluxo:**
`beq`, `bne`, `blt`, `bge`, `ble` (pseudo), `bgt` (pseudo), `beqz`, `bnez`, `j`, `jal`, `jr`

**Carregamento de constantes / endereços:**
`li`, `la`, `mv`

Essas instruções cobrem todos os módulos previstos: *game loop*, movimentação, renderização, geração de obstáculos (futuro RNG aritmético com LCG), detecção de colisão (comparações inteiras) e placar (incremento + impressão).

---

## 3. *Syscalls* do RARS utilizadas

| Código (`a7`) | Função | Uso no projeto |
|---|---|---|
| 1 | `print_int` | Imprimir frame atual e posição (debug) |
| 4 | `print_string` | Renderizar bordas e linhas da pista |
| 11 | `print_char` | Reservada para escrita célula-a-célula da pista |
| 12 | `read_char` | Ler tecla do jogador (`a`/`d`/`q`) |
| 10 | `exit` | Encerrar o jogo |

A escolha por `read_char` (síncrona) ao invés de `read_string` simplifica o *game loop* nesta etapa. O custo é o jogador ter de pressionar Enter após cada tecla na aba *Run I/O* do RARS, comportamento aceitável para um protótipo textual.

---

## 4. Convenção de registradores adotada

Definida a alocação fixa de registradores `s` (*callee-saved*) para o estado global do jogo, garantindo que sub-rotinas auxiliares possam usar livremente os `t` (*caller-saved*) sem corromper o estado:

| Registrador | Uso |
|---|---|
| `s0` | Posição X do carro (0 a 8) |
| `s1` | Velocidade do carro *(reservado — Etapa 2)* |
| `s2` | Score / placar *(reservado — Etapa 3)* |
| `s3` | Contador de frames |
| `s4` | *Flag* de jogo ativo (1 = rodando, 0 = sair) |
| `t0`–`t3` | Temporários dentro de sub-rotinas (render, atualizar) |
| `a0`, `a7` | Argumentos e código de *syscall* |
| `sp`, `ra` | Pilha e endereço de retorno (uso padrão da ABI) |

Essa decisão segue a ABI do RISC-V e é central para a análise arquitetural prevista na Etapa 4: ao manter o estado em registradores `s`, evitamos *load/store* a cada iteração do *loop*, reduzindo significativamente o número de instruções por frame em comparação a uma implementação que mantivesse tudo em memória.

---

## 5. Prova de conceito implementada

O arquivo `enduro.asm` (em anexo / no repositório) implementa o *game loop* mínimo. A estrutura é a seguinte:

```
main
 ├── inicializa estado (s0..s4)
 ├── imprime título e controles
 └── game_loop  ──────────────────┐
       ├── render        (desenha pista + carro)
       ├── debug_info    (imprime frame e posição)
       ├── ler_input     (syscall 12)
       ├── atualizar     (interpreta tecla)
       ├── s3++          (próximo frame)
       └── volta ao topo se s4 == 1
```

**Saída típica de uma iteração no RARS:**

```
+---------+
|    C    |
+---------+
Frame: 0  | Pos X: 4
```

Após digitar `d` na *Run I/O*:

```
+---------+
|     C   |
+---------+
Frame: 1  | Pos X: 5
```

A pista é representada por um *buffer* fixo de 12 bytes em `.data` (`linha_carro`) que é reescrito a cada frame: a sub-rotina `render` primeiro restaura o conteúdo a partir de `linha_vazia` (cópia byte a byte com `lbu`/`sb`) e depois grava o caractere `'C'` no *offset* `1 + s0`. Esse padrão "limpa-e-redesenha" é a versão textual do que o Atari original fazia movendo *sprites* via TIA — a comparação será aprofundada no relatório final.

---

## 6. Estimativa preliminar de custo de instruções

Contagem manual das instruções executadas em **um frame típico** (sem contar o tempo gasto dentro das *syscalls*, que o RARS reporta separadamente):

| Bloco | Instruções (aprox.) |
|---|---|
| Verificação `beqz s4` no topo do loop | 1 |
| `render` — bordas + cópia do *buffer* (loop de 12 bytes) + escrita do `'C'` | ~70 |
| `debug_info` — preparação dos 5 `ecall` | ~12 |
| `ler_input` | 2 |
| `atualizar` — comparação + branch + (eventual) `addi` | 5–8 |
| `addi s3, s3, 1` + `j game_loop` | 2 |
| **Total por frame** | **~92–95** |

O loop de cópia do *buffer* domina o custo (5 instruções × 12 iterações = 60). Uma otimização planejada para a Etapa 4 é substituir a cópia byte a byte por **três `sw`** (12 bytes = 3 *words* alinhadas), o que reduziria o `render` de ~70 para ~15 instruções. Esse tipo de troca *load/store estreito → load/store largo* é exatamente o tipo de análise arquitetural prometida na proposta.

---

## 7. Próximos passos (Etapa 2 e 3)

1. Adicionar a estrutura de dados de obstáculos (vetor em `.data` com posições e estados).
2. Implementar a sub-rotina de geração pseudo-aleatória (LCG simples em registradores).
3. Estender `render` para desenhar múltiplas linhas da pista, exibindo os obstáculos descendo a tela.
4. Implementar `colisao` comparando `s0` com a coluna do obstáculo na linha do carro.
5. Implementar o placar (incremento de `s2` por frame sem colisão) e impressão na HUD.

---

## 8. Repositório

O código e este documento estão versionados em:

`https://github.com/<usuario>/enduro-rv32i`  *(substituir pelo link real ao publicar)*

A estrutura inicial é:

```
enduro-rv32i/
├── README.md
├── docs/
│   └── entrega-etapa-1.md       (este documento)
└── src/
    └── enduro.asm                (prova de conceito)
```
