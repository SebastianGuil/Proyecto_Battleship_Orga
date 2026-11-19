# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: comodin.asm (Mecánica de Daño en Área - Probabilidad 1 en 7)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Al ejecutar un disparo certero, se tira un dado virtual de 7 caras (0 a 6).
# Si el resultado es 0 (probabilidad 1/7), se activa el Comodín Misterioso:
#   - Aplica un ataque expansivo en Cruz (Norte, Sur, Este, Oeste).
#   - Respeta estrictamente los bordes del tablero (0..15 en X e Y).
#   - Ignora casillas ya atacadas previamente (estados 5 y 6).
#   - Aplica impactos reales (+1 pto, reducción de vidas, hundimientos +5 ptos)
#     y fallos reales (marca 5 y blanco) sobre la matriz lógica del rival.
# ==============================================================================

.text
.globl calcular_comodin

# ==============================================================================
# SUBRUTINA: calcular_comodin
# ------------------------------------------------------------------------------
# Registros protegidos en stack: $ra, $s0-$s7 (36 bytes).
# ==============================================================================
calcular_comodin:
    subu $sp, $sp, 36
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)
    sw   $s6, 28($sp)
    sw   $s7, 32($sp)

    # 1. Tirar probabilidad 1 en 7 usando syscall 42 (Límite no inclusivo 7 -> 0..6)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 7
    syscall

    # Si el número generado no es 0, no hay comodín en este turno
    bnez $a0, cc_salir

    # ==========================================================================
    # ¡COMODÍN ACTIVADO! (Salió 0: 1 en 7 de probabilidad)
    # ==========================================================================
    li   $v0, 4
    la   $a0, msg_comodin_activado
    syscall

    lw   $s0, cursor_x           # X central del impacto (0..15)
    lw   $s1, cursor_y           # Y central del impacto (0..15)
    lw   $s2, turno_actual       # Atacante (1 o 2)

    # Determinar matriz lógica del objetivo
    beq  $s2, 1, cc_tab_j2
    la   $s3, tablero_j1
    j    cc_aplicar_cruz

cc_tab_j2:
    la   $s3, tablero_j2

cc_aplicar_cruz:
    # --------------------------------------------------------------------------
    # 1. DIRECCIÓN NORTE: (X, Y - 1)
    # --------------------------------------------------------------------------
    move $s4, $s0
    subi $s5, $s1, 1
    jal  evaluar_casilla_comodin

    # --------------------------------------------------------------------------
    # 2. DIRECCIÓN SUR: (X, Y + 1)
    # --------------------------------------------------------------------------
    move $s4, $s0
    addi $s5, $s1, 1
    jal  evaluar_casilla_comodin

    # --------------------------------------------------------------------------
    # 3. DIRECCIÓN ESTE: (X + 1, Y)
    # --------------------------------------------------------------------------
    addi $s4, $s0, 1
    move $s5, $s1
    jal  evaluar_casilla_comodin

    # --------------------------------------------------------------------------
    # 4. DIRECCIÓN OESTE: (X - 1, Y)
    # --------------------------------------------------------------------------
    subi $s4, $s0, 1
    move $s5, $s1
    jal  evaluar_casilla_comodin

cc_salir:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    lw   $s6, 28($sp)
    lw   $s7, 32($sp)
    addu $sp, $sp, 36
    jr   $ra

# ==============================================================================
# SUBRUTINA INTERNA: evaluar_casilla_comodin
# ------------------------------------------------------------------------------
# Entradas:
#   $s4 = X_evaluada
#   $s5 = Y_evaluada
#   $s2 = Atacante (1 o 2)
#   $s3 = Puntero a matriz lógica del rival
# ==============================================================================
evaluar_casilla_comodin:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    # 1. Validar bordes estrictos (0..15 en X, 0..15 en Y)
    bltz $s4, ecc_fin
    bgt  $s4, 15, ecc_fin
    bltz $s5, ecc_fin
    bgt  $s5, 15, ecc_fin

    # 2. Leer estado de la casilla en la matriz lógica
    sll  $t0, $s5, 4             # Y * 16
    add  $t0, $t0, $s4           # + X
    add  $t1, $s3, $t0           # Dirección en matriz lógica
    lb   $t2, 0($t1)             # $t2 = Estado actual

    # 3. Si ya estaba atacada (5 o 6), ignorar
    beq  $t2, 5, ecc_fin
    beq  $t2, 6, ecc_fin

    # 4. Evaluar si es impacto de barco (1..4) o agua (0)
    beqz $t2, ecc_es_agua

    # --- BARCO ALCANZADO POR COMODÍN ---
    move $a0, $s4                # X
    move $a1, $s5                # Y
    move $a2, $t2                # ID barco (1..4)
    move $a3, $s2                # Atacante (1 o 2)
    jal  aplicar_impacto_en_matriz
    j    ecc_fin

ecc_es_agua:
    # --- AGUA ALCANZADA POR COMODÍN ---
    li   $t3, 5
    sb   $t3, 0($t1)             # Marcar estado 5 (Fallo) en matriz

    move $a0, $s4
    move $a1, $s5
    lw   $a2, COLOR_FALLO
    jal  dibujar_pixel           # Pintar blanco en VRAM

ecc_fin:
    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra
