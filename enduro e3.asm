# Enduro RV32I - Versao Grafica Otimizada (defensiva)
# Kayque Rodrigues (6593272) e Miguel Gil (5196718)
#
# CONFIGURACAO NO RARS:
#   Tools -> Bitmap Display:
#     Unit Width / Height: 8
#     Display Width / Height: 512 / 512
#     Base address: 0x10010000 (static data)
#   Clica "Connect to Program", deixa a janela aberta
#
#   Tools -> Keyboard and Display MMIO Simulator:
#     Clica "Connect to Program" (necessario para input nao-bloqueante)
#     Foca na janela do MMIO Simulator (caixa de texto) ao apertar teclas
#
#   F3 (Assemble), F5 (Run)
#
# Controles (na janela do MMIO Simulator): 'a'=esquerda, 'd'=direita, 'q'=sair
# A pista anda sozinha; o input agora e nao-bloqueante.

.eqv BITMAP_BASE 0x10010000
.eqv LARGURA     64
.eqv ALTURA      64

.eqv COR_GRAMADO  0x00228B22
.eqv COR_PISTA    0x00202020
.eqv COR_BORDA_R  0x00CC0000
.eqv COR_BORDA_W  0x00FFFFFF
.eqv COR_FAIXA    0x00FFFF00
.eqv COR_CARRO    0x00FF0000
.eqv COR_INIMIGO1 0x000088FF
.eqv COR_INIMIGO2 0x00FFAA00
.eqv COR_INIMIGO3 0x0000FF88
.eqv COR_INIMIGO4 0x00FF00FF

.data
.align 2

bitmap_area:   .space 16384

pos_anterior:  .word 30

inimigos:      .word 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
               .word 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF

ini_anterior:  .word 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
               .word 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF

tabela_cores:  .word COR_INIMIGO1, COR_INIMIGO2, COR_INIMIGO3, COR_INIMIGO4

fonte_dig:
    .word 0x7, 0x5, 0x5, 0x5, 0x7
    .word 0x2, 0x3, 0x2, 0x2, 0x7
    .word 0x7, 0x4, 0x7, 0x1, 0x7
    .word 0x7, 0x4, 0x7, 0x4, 0x7
    .word 0x5, 0x5, 0x7, 0x4, 0x4
    .word 0x7, 0x1, 0x7, 0x4, 0x7
    .word 0x7, 0x1, 0x7, 0x5, 0x7
    .word 0x7, 0x4, 0x2, 0x2, 0x2
    .word 0x7, 0x5, 0x7, 0x5, 0x7
    .word 0x7, 0x5, 0x7, 0x4, 0x7

msg_titulo:    .asciz "=== ENDURO RV32I (Grafico) ===\n"
msg_controles: .asciz "Digite na janela do MMIO Simulator: 'a'=esq, 'd'=dir, 'q'=sair\n"
msg_frame:     .asciz "Frame: "
msg_vidas:     .asciz "  Vidas: "
msg_score:     .asciz "  Score: "
msg_colidiu:   .asciz "  *** COLISAO! ***"
msg_nl:        .asciz "\n"
msg_fim:       .asciz "\n=== GAME OVER ===\nScore: "
msg_saida:     .asciz "\n"

.text
.globl main

main:
    li   s0, 30
    li   s1, 12345
    li   s2, 0
    li   s3, 0
    li   s4, 1
    la   s5, inimigos
    li   s6, 3
    li   s7, 0
    li   s8, BITMAP_BASE

    la   a0, msg_titulo
    li   a7, 4
    ecall
    la   a0, msg_controles
    li   a7, 4
    ecall

    jal  ra, pintar_cenario_inicial

    mv   a0, s0
    li   a1, 56
    li   a2, COR_CARRO
    jal  ra, desenhar_carro

game_loop:
    beqz s4, fim_jogo

    jal  ra, ler_input
    jal  ra, processar_tecla

    andi t0, s3, 0x3
    bnez t0, gl_no_scroll
    jal  ra, avancar_pista
    jal  ra, pontuar
gl_no_scroll:

    jal  ra, checar_colisao

    jal  ra, atualizar_inimigos
    jal  ra, atualizar_zebras
    jal  ra, atualizar_jogador

    jal  ra, desenhar_hud_grafico

    li   a0, 80
    li   a7, 32
    ecall

    addi s3, s3, 1
    j    game_loop

pintar_cenario_inicial:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   s9, 4(sp)

    li   s9, 0
pci_y:
    li   t0, ALTURA
    beq  s9, t0, pci_done

    li   t6, 0
pci_x:
    li   t0, LARGURA
    beq  t6, t0, pci_prox

    li   t1, COR_GRAMADO
    li   t0, 16
    blt  t6, t0, pci_pinta
    li   t0, 48
    bge  t6, t0, pci_pinta
    li   t1, COR_PISTA
pci_pinta:
    slli t2, s9, 6
    add  t2, t2, t6
    slli t2, t2, 2
    add  t2, t2, s8
    sw   t1, 0(t2)

    addi t6, t6, 1
    j    pci_x
pci_prox:
    addi s9, s9, 1
    j    pci_y
pci_done:

    lw   s9, 4(sp)
    lw   ra, 0(sp)
    addi sp, sp, 8
    jr   ra

atualizar_zebras:
    addi sp, sp, -4
    sw   s9, 0(sp)

    li   s9, 0
az_loop:
    li   t0, ALTURA
    beq  s9, t0, az_done

    add  t1, s9, s3
    srli t1, t1, 2
    andi t1, t1, 1

    li   t2, COR_BORDA_R
    beqz t1, az_zebra
    li   t2, COR_BORDA_W
az_zebra:

    slli t3, s9, 6
    addi t3, t3, 16
    slli t3, t3, 2
    add  t3, t3, s8
    sw   t2, 0(t3)

    slli t3, s9, 6
    addi t3, t3, 47
    slli t3, t3, 2
    add  t3, t3, s8
    sw   t2, 0(t3)

    li   t4, COR_FAIXA
    beqz t1, az_faixa
    li   t4, COR_PISTA
az_faixa:
    slli t3, s9, 6
    addi t3, t3, 31
    slli t3, t3, 2
    add  t3, t3, s8
    sw   t4, 0(t3)
    slli t3, s9, 6
    addi t3, t3, 32
    slli t3, t3, 2
    add  t3, t3, s8
    sw   t4, 0(t3)

    addi s9, s9, 1
    j    az_loop
az_done:
    lw   s9, 0(sp)
    addi sp, sp, 4
    jr   ra

atualizar_inimigos:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   s9, 4(sp)

    li   s9, 0
ai_loop:
    li   t0, 8
    beq  s9, t0, ai_done

    slli s10, s9, 2

    la   t0, ini_anterior
    add  t0, t0, s10
    lw   t1, 0(t0)
    andi t2, t1, 0xFF
    li   t3, 0xFF
    beq  t2, t3, ai_pinta_novo

    li   t3, 64
    bge  t2, t3, ai_pinta_novo

    slli t4, s9, 3
    addi t4, t4, 1
    mv   a0, t2
    mv   a1, t4
    li   a2, COR_PISTA
    jal  ra, desenhar_carro

ai_pinta_novo:
    la   t0, inimigos
    add  t0, t0, s10
    lw   t1, 0(t0)

    la   t0, ini_anterior
    add  t0, t0, s10
    sw   t1, 0(t0)

    andi t2, t1, 0xFF
    li   t3, 0xFF
    beq  t2, t3, ai_prox

    li   t3, 64
    bge  t2, t3, ai_prox

    srli t3, t1, 8
    andi t3, t3, 0x3
    slli t3, t3, 2
    la   t4, tabela_cores
    add  t4, t4, t3
    lw   t5, 0(t4)

    slli t4, s9, 3
    addi t4, t4, 1
    mv   a0, t2
    mv   a1, t4
    mv   a2, t5
    jal  ra, desenhar_carro

ai_prox:
    addi s9, s9, 1
    j    ai_loop
ai_done:
    lw   s9, 4(sp)
    lw   ra, 0(sp)
    addi sp, sp, 8
    jr   ra

atualizar_jogador:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   t0, pos_anterior
    lw   t1, 0(t0)

    li   t2, 0
    blt  t1, t2, aj_skip_apaga
    li   t2, 60
    bge  t1, t2, aj_skip_apaga

    mv   a0, t1
    li   a1, 56
    jal  ra, apagar_jogador_preservando_faixa

aj_skip_apaga:
    la   t0, pos_anterior
    sw   s0, 0(t0)

    beqz s7, aj_pinta
    andi t0, s7, 1
    bnez t0, aj_done

aj_pinta:
    mv   a0, s0
    li   a1, 56
    li   a2, COR_CARRO
    jal  ra, desenhar_carro

aj_done:
    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

desenhar_carro:
    li   t0, 60
    bge  a0, t0, dc_skip
    li   t0, 58
    bge  a1, t0, dc_skip

    li   t0, 0
dc_y:
    li   t1, 6
    beq  t0, t1, dc_done
    li   t2, 0
dc_x:
    li   t3, 4
    beq  t2, t3, dc_prox

    add  t4, a0, t2
    add  t5, a1, t0
    slli t6, t5, 6
    add  t6, t6, t4
    slli t6, t6, 2
    add  t6, t6, s8
    sw   a2, 0(t6)

    addi t2, t2, 1
    j    dc_x
dc_prox:
    addi t0, t0, 1
    j    dc_y
dc_done:
dc_skip:
    jr   ra

apagar_jogador_preservando_faixa:
    li   t0, 60
    bge  a0, t0, ajpf_skip
    li   t0, 58
    bge  a1, t0, ajpf_skip

    li   t0, 0
ajpf_y:
    li   t1, 6
    beq  t0, t1, ajpf_done
    li   t2, 0
ajpf_x:
    li   t3, 4
    beq  t2, t3, ajpf_prox

    add  t4, a0, t2
    li   t5, 31
    beq  t4, t5, ajpf_pula
    li   t5, 32
    beq  t4, t5, ajpf_pula

    add  t5, a1, t0
    slli t6, t5, 6
    add  t6, t6, t4
    slli t6, t6, 2
    add  t6, t6, s8
    li   t5, COR_PISTA
    sw   t5, 0(t6)
ajpf_pula:
    addi t2, t2, 1
    j    ajpf_x
ajpf_prox:
    addi t0, t0, 1
    j    ajpf_y
ajpf_done:
ajpf_skip:
    jr   ra

desenhar_digito:
    li   t0, 10
    bgeu a2, t0, dd_done

    li   t0, 20
    mul  t0, a2, t0
    la   t1, fonte_dig
    add  t1, t1, t0

    li   t2, 0
dd_row:
    li   t3, 5
    bge  t2, t3, dd_done

    lw   t4, 0(t1)
    addi t1, t1, 4

    li   t5, 0
dd_col:
    li   t6, 3
    bge  t5, t6, dd_rnext

    srl  t6, t4, t5
    andi t6, t6, 1
    beqz t6, dd_skip

    add  t6, a1, t2
    slli t6, t6, 6
    add  t6, t6, a0
    add  t6, t6, t5
    slli t6, t6, 2
    add  t6, t6, s8
    sw   a3, 0(t6)
dd_skip:
    addi t5, t5, 1
    j    dd_col
dd_rnext:
    addi t2, t2, 1
    j    dd_row
dd_done:
    jr   ra

desenhar_hud_grafico:
    addi sp, sp, -16
    sw   ra, 0(sp)
    sw   s9, 4(sp)
    sw   s10, 8(sp)
    sw   s11, 12(sp)

    li   s9, 0
dhg_cy:
    li   t0, 8
    bge  s9, t0, dhg_vidas

    li   s10, 0
dhg_cx:
    li   t0, 16
    bge  s10, t0, dhg_cynext

    slli t1, s9, 6
    add  t2, t1, s10
    slli t2, t2, 2
    add  t2, t2, s8
    li   t3, COR_GRAMADO
    sw   t3, 0(t2)
    addi t4, s10, 48
    add  t2, t1, t4
    slli t2, t2, 2
    add  t2, t2, s8
    sw   t3, 0(t2)

    addi s10, s10, 1
    j    dhg_cx
dhg_cynext:
    addi s9, s9, 1
    j    dhg_cy

dhg_vidas:
    li   s9, 0
dhg_vloop:
    bge  s9, s6, dhg_score
    li   t0, 5
    bge  s9, t0, dhg_score

    li   t0, 3
    mul  t0, s9, t0
    addi s10, t0, 2

    li   s11, 0
dhg_vy:
    li   t0, 3
    bge  s11, t0, dhg_vnext
    li   t1, 0
dhg_vx:
    li   t0, 2
    bge  t1, t0, dhg_vynext

    addi t2, s11, 2
    slli t2, t2, 6
    add  t3, s10, t1
    add  t2, t2, t3
    slli t2, t2, 2
    add  t2, t2, s8
    li   t4, COR_CARRO
    sw   t4, 0(t2)

    addi t1, t1, 1
    j    dhg_vx
dhg_vynext:
    addi s11, s11, 1
    j    dhg_vy
dhg_vnext:
    addi s9, s9, 1
    j    dhg_vloop

dhg_score:
    mv   s9, s2
    li   s10, 60
    li   s11, 0

dhg_sloop:
    li   t0, 4
    bge  s11, t0, dhg_done

    li   t0, 10
    rem  a2, s9, t0
    div  s9, s9, t0

    mv   a0, s10
    li   a1, 2
    li   a3, COR_BORDA_W
    jal  ra, desenhar_digito

    addi s10, s10, -4
    addi s11, s11, 1

    bnez s9, dhg_sloop

dhg_done:
    lw   s11, 12(sp)
    lw   s10, 8(sp)
    lw   s9, 4(sp)
    lw   ra, 0(sp)
    addi sp, sp, 16
    jr   ra

hud_texto:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   a0, msg_frame
    li   a7, 4
    ecall
    mv   a0, s3
    li   a7, 1
    ecall

    la   a0, msg_vidas
    li   a7, 4
    ecall
    mv   a0, s6
    li   a7, 1
    ecall

    la   a0, msg_score
    li   a7, 4
    ecall
    mv   a0, s2
    li   a7, 1
    ecall

    beqz s7, hud_sf
    la   a0, msg_colidiu
    li   a7, 4
    ecall
hud_sf:
    la   a0, msg_nl
    li   a7, 4
    ecall

    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

ler_input:
    li   t0, 0xFFFF0000
    lw   t1, 0(t0)
    andi t1, t1, 1
    beqz t1, li_none
    lw   a0, 4(t0)
    jr   ra
li_none:
    li   a0, 0
    jr   ra

processar_tecla:
    li   t0, 'a'
    beq  a0, t0, pt_esq
    li   t0, 'd'
    beq  a0, t0, pt_dir
    li   t0, 'q'
    beq  a0, t0, pt_sair
    jr   ra

pt_esq:
    li   t0, 18
    ble  s0, t0, pt_fim
    addi s0, s0, -2
    j    pt_fim

pt_dir:
    li   t0, 42
    bge  s0, t0, pt_fim
    addi s0, s0, 2
    j    pt_fim

pt_sair:
    li   s4, 0

pt_fim:
    jr   ra

avancar_pista:
    addi sp, sp, -4
    sw   ra, 0(sp)

    li   t0, 7
ap_roll:
    beqz t0, ap_done
    addi t1, t0, -1
    slli t2, t1, 2
    add  t2, s5, t2
    lw   t3, 0(t2)
    slli t2, t0, 2
    add  t2, s5, t2
    sw   t3, 0(t2)
    addi t0, t0, -1
    j    ap_roll
ap_done:

    jal  ra, gerar_inimigo
    sw   a0, 0(s5)

    lw   ra, 0(sp)
    addi sp, sp, 4
    jr   ra

gerar_inimigo:
    li   t0, 1103515245
    mul  s1, s1, t0
    li   t0, 12345
    add  s1, s1, t0

    srli t0, s1, 16
    andi t1, t0, 1
    beqz t1, gi_vazio

    srli t2, t0, 1
    andi t2, t2, 0xF
    li   t3, 10
    rem  t2, t2, t3

    li   t3, 5
    bge  t2, t3, gi_dir
    slli t2, t2, 1
    addi t2, t2, 18
    j    gi_ok
gi_dir:
    addi t2, t2, -5
    slli t2, t2, 1
    addi t2, t2, 34
gi_ok:

    srli t3, t0, 5
    andi t3, t3, 0x3
    slli t3, t3, 8
    or   a0, t2, t3
    jr   ra

gi_vazio:
    li   a0, 0xFFFFFFFF
    jr   ra

checar_colisao:
    beqz s7, cc_check
    addi s7, s7, -1
    jr   ra

cc_check:
    li   t0, 28
    add  t0, s5, t0
    lw   t1, 0(t0)
    andi t2, t1, 0xFF
    li   t3, 0xFF
    beq  t2, t3, cc_fim

    sub  t3, s0, t2
    bge  t3, zero, cc_abs
    sub  t3, zero, t3
cc_abs:
    li   t4, 5
    bge  t3, t4, cc_fim

    addi s6, s6, -1
    li   s7, 8

    bnez s6, cc_fim
    li   s4, 0

cc_fim:
    jr   ra

pontuar:
    bnez s7, pt2_fim
    addi s2, s2, 1
pt2_fim:
    jr   ra

fim_jogo:
    la   a0, msg_fim
    li   a7, 4
    ecall
    mv   a0, s2
    li   a7, 1
    ecall
    la   a0, msg_saida
    li   a7, 4
    ecall

    li   a7, 10
    ecall
