# Enduro RV32I - Etapa 2: pista rolando + obstaculos
# Kayque Rodrigues (6593272) e Miguel Gil (5196718)
#
# Novidades em relacao a entrega anterior:
#   - Pista com 8 linhas (movimento em Y simulado por scroll)
#   - Obstaculos 'X' que descem junto com a pista
#   - Gerador pseudo-aleatorio (LCG) para posicionar obstaculos
#   - Tela limpa a cada frame
#
# Controles: 'a' esquerda, 'd' direita, ' ' (espaco) avancar, 'q' sair.
#
# Estado em registradores:
#   s0 = posicao X do carro (0..8)
#   s1 = semente do LCG (RNG)
#   s2 = score (Etapa 3 futura)
#   s3 = contador de frames
#   s4 = flag rodando
#   s5 = endereco base do vetor de obstaculos

.data

# Vetor de 8 posicoes: cada byte guarda a coluna do obstaculo naquela
# linha da pista. Valor 255 (0xFF) = linha sem obstaculo.
obstaculos:     .byte 255, 255, 255, 255, 255, 255, 255, 255

# Strings de UI
borda:          .asciz "+---------+\n"
linha_buffer:   .asciz "|         |\n"   # buffer reescrito a cada linha

# Limpa tela com sequencia ANSI: ESC[2J ESC[H
limpa_tela:     .asciz "\033[2J\033[H"

msg_titulo:     .asciz "=== ENDURO RV32I (Etapa 2) ===\n"
msg_controles:  .asciz "'a'/'d'=lados  ' '=avancar  'q'=sair\n"
msg_frame:      .asciz "\nFrame: "
msg_pos:        .asciz "  Pos X: "
msg_nl:         .asciz "\n"
msg_fim:        .asciz "\n=== Fim de jogo ===\n"

.text
.globl main

main:
    li   s0, 4              # carro no centro
    li   s1, 12345          # semente inicial do LCG
    li   s2, 0
    li   s3, 0
    li   s4, 1
    la   s5, obstaculos     # base do vetor de obstaculos

game_loop:
    beqz s4, fim_jogo

    jal  ra, render
    jal  ra, debug_info
    jal  ra, ler_input
    jal  ra, atualizar

    addi s3, s3, 1
    j    game_loop

# ---------------------------------------------------------------
# render: limpa tela, imprime cabecalho, desenha as 8 linhas da pista
# A linha 7 (ultima, mais perto do jogador) eh onde o carro aparece.
# As outras linhas mostram apenas o obstaculo daquela linha.
# ---------------------------------------------------------------
render:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   s6, 4(sp)          # s6 = indice da linha sendo desenhada

    la   a0, limpa_tela
    li   a7, 4
    ecall

    la   a0, msg_titulo
    li   a7, 4
    ecall

    la   a0, borda
    li   a7, 4
    ecall

    li   s6, 0              # comeca pela linha 0 (topo)
render_loop:
    li   t0, 8
    beq  s6, t0, render_done

    # Limpa o linha_buffer (12 bytes = "|         |\n\0")
    jal  ra, reset_buffer

    # Carrega o obstaculo desta linha: obst = obstaculos[s6]
    add  t0, s5, s6
    lbu  t1, 0(t0)          # t1 = coluna do obstaculo (ou 255)

    li   t2, 255
    beq  t1, t2, sem_obst   # 255 -> linha vazia
    # Escreve 'X' na posicao do obstaculo: buffer[1 + t1] = 'X'
    la   t3, linha_buffer
    addi t3, t3, 1
    add  t3, t3, t1
    li   t4, 'X'
    sb   t4, 0(t3)
sem_obst:

    # Se for a ultima linha (linha 7), desenha tambem o carro
    li   t0, 7
    bne  s6, t0, sem_carro
    la   t3, linha_buffer
    addi t3, t3, 1
    add  t3, t3, s0
    li   t4, 'C'
    sb   t4, 0(t3)
sem_carro:

    la   a0, linha_buffer
    li   a7, 4
    ecall

    addi s6, s6, 1
    j    render_loop
render_done:

    la   a0, borda
    li   a7, 4
    ecall

    lw   s6, 4(sp)
    lw   ra, 0(sp)
    addi sp, sp, 8
    jr   ra

# ---------------------------------------------------------------
# reset_buffer: restaura linha_buffer para "|         |\n"
# ---------------------------------------------------------------
reset_buffer:
    la   t0, linha_buffer
    li   t1, '|'
    sb   t1, 0(t0)
    li   t1, ' '
    sb   t1, 1(t0)
    sb   t1, 2(t0)
    sb   t1, 3(t0)
    sb   t1, 4(t0)
    sb   t1, 5(t0)
    sb   t1, 6(t0)
    sb   t1, 7(t0)
    sb   t1, 8(t0)
    sb   t1, 9(t0)
    li   t1, '|'
    sb   t1, 10(t0)
    li   t1, '\n'
    sb   t1, 11(t0)
    jr   ra

# ---------------------------------------------------------------
# debug_info: imprime Frame e Pos X
# ---------------------------------------------------------------
debug_info:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   a0, msg_frame
    li   a7, 4
    ecall
    mv   a0, s3
    li   a7, 1
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

ler_input:
    li   a7, 12
    ecall
    jr   ra

# ---------------------------------------------------------------
# atualizar: processa tecla e faz a pista "rolar"
# A rolagem desloca todos os obstaculos uma linha para baixo
# e gera um possivel novo obstaculo no topo.
# ---------------------------------------------------------------
atualizar:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   t0, 'a'
    beq  a0, t0, mover_esq
    li   t0, 'd'
    beq  a0, t0, mover_dir
    li   t0, 'q'
    beq  a0, t0, sair
    # qualquer outra tecla (incluindo espaco) so avanca o frame
    j    avancar_pista

mover_esq:
    li   t0, 0
    ble  s0, t0, avancar_pista
    addi s0, s0, -1
    j    avancar_pista

mover_dir:
    li   t0, 8
    bge  s0, t0, avancar_pista
    addi s0, s0, 1
    j    avancar_pista

sair:
    li   s4, 0
    j    atualizar_fim

# Rola a pista: obstaculos[i] = obstaculos[i-1], i de 7 ate 1
# Depois gera um novo valor para obstaculos[0]
avancar_pista:
    li   t0, 7              # i = 7
roll_loop:
    beqz t0, roll_done
    addi t1, t0, -1         # i-1
    add  t2, s5, t1         # &obstaculos[i-1]
    lbu  t3, 0(t2)
    add  t2, s5, t0         # &obstaculos[i]
    sb   t3, 0(t2)
    addi t0, t0, -1
    j    roll_loop
roll_done:

    # Gera novo obstaculo no topo
    jal  ra, gerar_obstaculo
    sb   a0, 0(s5)          # obstaculos[0] = a0

atualizar_fim:
    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

# ---------------------------------------------------------------
# gerar_obstaculo: usa LCG para decidir se gera obstaculo e onde.
# LCG classico: seed = seed * 1103515245 + 12345
# Retorna em a0: 0-8 (coluna) ou 255 (sem obstaculo).
# Probabilidade ~7/16 de obstaculo, ~9/16 de linha vazia.
# ---------------------------------------------------------------
gerar_obstaculo:
    li   t0, 1103515245
    mul  s1, s1, t0
    li   t0, 12345
    add  s1, s1, t0         # s1 = nova semente

    # Pega bits 16-19 (4 bits) para sortear: srli + andi
    srli t0, s1, 16
    andi t0, t0, 0xF        # t0 in [0..15]

    # Se t0 < 9, eh a coluna do obstaculo; senao, linha vazia (255)
    li   t1, 9
    bge  t0, t1, gerar_vazio
    mv   a0, t0
    jr   ra
gerar_vazio:
    li   a0, 255
    jr   ra

fim_jogo:
    la   a0, msg_fim
    li   a7, 4
    ecall
    li   a7, 10
    ecall
