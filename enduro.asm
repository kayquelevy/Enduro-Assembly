# =============================================================================
# Enduro RV32I - Prova de Conceito (Etapa 1 + início da Etapa 2)
# Arquitetura de Computadores - 2026
# Autores: Kayque de Jesus Levy Rodrigues (6593272)
#          Miguel Nepomuceno Gil (5196718)
#
# Descricao:
#   Game loop minimo do jogo Enduro em Assembly RV32I para o simulador RARS.
#   Esta versao implementa apenas o esqueleto do laco principal:
#     - Leitura de tecla via syscall 12 (read char)
#     - Atualizacao da posicao do carro em registrador
#     - Renderizacao textual da pista via syscall 4 (print string)
#     - Contador de frames
#   Modulos de obstaculos, colisao e placar serao adicionados nas Etapas 2 e 3.
#
# Convencoes de registradores (definidas para todo o projeto):
#   s0 = posicao X do carro (0..LARGURA_PISTA-1)
#   s1 = velocidade do carro (reservado p/ Etapa 2)
#   s2 = score / placar       (reservado p/ Etapa 3)
#   s3 = contador de frames
#   s4 = flag de "rodando" (1 = jogo ativo, 0 = sair)
#
# Controles:
#   'a' -> mover carro para esquerda
#   'd' -> mover carro para direita
#   'q' -> sair do jogo
#   qualquer outra tecla -> apenas avanca o frame
#
# Como executar no RARS:
#   1) Abrir RARS, carregar este arquivo (File > Open)
#   2) Assemble (F3)
#   3) Run (F5)
#   4) Ao ler tecla, focar a aba "Run I/O" e digitar a, d ou q + Enter
# =============================================================================

# -----------------------------------------------------------------------------
# Secao de dados: strings constantes da pista
# -----------------------------------------------------------------------------
.data

# Constantes de layout textual da pista.
# A pista tem 9 colunas internas (entre as bordas '|').
# A posicao inicial do carro eh a coluna 4 (centro).

borda_top:      .asciz "+---------+\n"
borda_bot:      .asciz "+---------+\n"
linha_vazia:    .asciz "|         |\n"

# Buffer de uma linha da pista que sera modificado em tempo de execucao
# para desenhar o carro 'C' na coluna correta.
# Layout (indices):
#   0='|', 1..9 = colunas internas, 10='|', 11='\n', 12=0
linha_carro:    .asciz "|         |\n"

# Mensagens de UI
msg_titulo:     .asciz "=== ENDURO RV32I (Prova de Conceito) ===\n"
msg_controles:  .asciz "Controles: 'a'=esq  'd'=dir  'q'=sair\n\n"
msg_frame:      .asciz "Frame: "
msg_pos:        .asciz "  | Pos X: "
msg_nl:         .asciz "\n"
msg_fim:        .asciz "\n=== Fim de jogo ===\n"

# -----------------------------------------------------------------------------
# Secao de codigo
# -----------------------------------------------------------------------------
.text
.globl main

main:
    # ---------- Inicializacao do estado ----------
    li   s0, 4              # posicao X inicial = 4 (centro da pista de 9 cols)
    li   s1, 0              # velocidade (nao usada nesta etapa)
    li   s2, 0              # score (nao usado nesta etapa)
    li   s3, 0              # contador de frames = 0
    li   s4, 1              # flag rodando = 1

    # Imprime cabecalho uma unica vez
    la   a0, msg_titulo
    li   a7, 4
    ecall
    la   a0, msg_controles
    li   a7, 4
    ecall

# =============================================================================
# game_loop: laco principal do jogo
# A cada iteracao:
#   1) renderiza o frame atual
#   2) imprime info de debug (frame, posicao)
#   3) le uma tecla
#   4) atualiza estado conforme a tecla
#   5) incrementa contador de frames
#   6) se s4 == 0, sai do laco
# =============================================================================
game_loop:
    beqz s4, fim_jogo       # se flag rodando == 0, encerra

    jal  ra, render         # desenha o frame
    jal  ra, debug_info     # imprime "Frame: X | Pos X: Y"
    jal  ra, ler_input      # le tecla -> a0
    jal  ra, atualizar      # atualiza estado com base em a0

    addi s3, s3, 1          # frame++
    j    game_loop

# =============================================================================
# render: desenha a pista textual atual
#   - imprime borda superior
#   - monta a linha do carro: coloca 'C' na coluna correspondente a s0
#     (offset no buffer = 1 + s0, pois indice 0 eh a borda '|')
#   - imprime a linha do carro
#   - imprime borda inferior
# Custo aproximado: ~70 instrucoes por frame (sem contar syscalls)
# =============================================================================
render:
    addi sp, sp, -4
    sw   ra, 0(sp)          # salva ra (vamos chamar ecall, mas tambem queremos
                            # poder chamar render de dentro de game_loop)

    # Borda superior
    la   a0, borda_top
    li   a7, 4
    ecall

    # Reseta a linha_carro para "|         |\n" antes de inserir o carro.
    # Faz isso copiando da linha_vazia byte a byte (12 bytes incluindo \n e \0).
    la   t0, linha_vazia
    la   t1, linha_carro
    li   t2, 12             # quantidade de bytes a copiar
reset_loop:
    beqz t2, reset_done
    lbu  t3, 0(t0)
    sb   t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t2, t2, -1
    j    reset_loop
reset_done:

    # Insere 'C' na posicao correta: endereco = linha_carro + 1 + s0
    la   t1, linha_carro
    addi t1, t1, 1          # pular borda esquerda '|'
    add  t1, t1, s0         # somar posicao X
    li   t3, 'C'
    sb   t3, 0(t1)

    # Imprime linha do carro
    la   a0, linha_carro
    li   a7, 4
    ecall

    # Borda inferior
    la   a0, borda_bot
    li   a7, 4
    ecall

    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

# =============================================================================
# debug_info: imprime "Frame: <s3>  | Pos X: <s0>\n"
#   Ajuda na medicao de instrucoes por frame durante a Etapa 4.
# =============================================================================
debug_info:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   a0, msg_frame
    li   a7, 4
    ecall

    mv   a0, s3
    li   a7, 1              # print int
    ecall

    la   a0, msg_pos
    li   a7, 4
    ecall

    mv   a0, s0
    li   a7, 1
    ecall

    la   a0, msg_nl
    li   a7, 4
    ecall

    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

# =============================================================================
# ler_input: le um caractere do teclado e retorna em a0
#   syscall 12 (read char) - retorna o codigo ASCII em a0
# =============================================================================
ler_input:
    li   a7, 12
    ecall
    jr   ra

# =============================================================================
# atualizar: recebe tecla em a0 e atualiza o estado
#   'a' (97): se s0 > 0, decrementa s0
#   'd' (100): se s0 < 8, incrementa s0   (LARGURA_PISTA - 1 = 8)
#   'q' (113): zera s4 -> sai do loop
#   outras: nada
# =============================================================================
atualizar:
    li   t0, 'a'
    beq  a0, t0, mover_esq

    li   t0, 'd'
    beq  a0, t0, mover_dir

    li   t0, 'q'
    beq  a0, t0, sair

    jr   ra                 # tecla irrelevante: nao faz nada

mover_esq:
    li   t0, 0
    ble  s0, t0, atualizar_fim   # se s0 <= 0, nao move (limite esquerdo)
    addi s0, s0, -1
    j    atualizar_fim

mover_dir:
    li   t0, 8                   # 9 colunas (0..8) -> max = 8
    bge  s0, t0, atualizar_fim
    addi s0, s0, 1
    j    atualizar_fim

sair:
    li   s4, 0                   # sinaliza fim de jogo

atualizar_fim:
    jr   ra

# =============================================================================
# fim_jogo: imprime mensagem final e encerra programa
# =============================================================================
fim_jogo:
    la   a0, msg_fim
    li   a7, 4
    ecall

    li   a7, 10                  # exit
    ecall
