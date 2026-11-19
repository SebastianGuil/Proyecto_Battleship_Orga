# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: ia_cpu.asm (Inteligencia Artificial Táctica - Hunt & Target)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Implementa el algoritmo táctico Hunt & Target para la computadora (CPU):
# 1. Modo Caza (Hunt): Genera coordenadas aleatorias válidas (0..15 en X e Y)
#    con syscall 42 sin repetir casillas ya atacadas previamente.
# 2. Modo Objetivo (Target): Al acertar un impacto en un barco del jugador,
#    calcula las 4 casillas adyacentes válidas (Norte, Sur, Este, Oeste) y las
#    inserta en una cola FIFO en memoria. En sus siguientes turnos, prioriza
#    dichas casillas hasta hundir el barco o agotar los candidatos.
# 3. Regla de Impacto: Al acertar, la CPU repite turno hasta fallar o ganar.
# ==============================================================================

.text
.globl turno_cpu
.globl encolar_objetivo_ia

# ==============================================================================
# SUBRUTINA: turno_cpu
# ------------------------------------------------------------------------------
# Propósito: Ejecuta el turno de ataque de la computadora contra tablero_j1.
# Registros protegidos en stack: $ra, $s0-$s7 (36 bytes).
# ==============================================================================
turno_cpu:
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

cpu_bucle_tiros:
    # Retardo aritmético de simulación de "pensamiento" (Cero syscall 32)
    li   $t0, 30000
cpu_retardo:
    addi $t0, $t0, -1
    bgtz $t0, cpu_retardo

    # 1. Determinar si operamos en Modo Target (cola > 0) o Modo Hunt (cola == 0)
    lw   $t1, cola_ia_count
    bgtz $t1, cpu_modo_target

    # ==========================================================================
    # A) MODO HUNT (Caza Aleatoria sin Repetición)
    # ==========================================================================
cpu_modo_hunt:
    # Generar coordenada X aleatoria (0..15)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 16
    syscall
    move $s0, $a0                # $s0 = X_cpu

    # Generar coordenada Y aleatoria (0..15)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 16
    syscall
    move $s1, $a0                # $s1 = Y_cpu

    # Comprobar en tablero_j1 si ya fue atacada (estado 5 o 6)
    sll  $t2, $s1, 4
    add  $t2, $t2, $s0
    la   $t3, tablero_j1
    add  $t3, $t3, $t2
    lb   $s2, 0($t3)             # Estado actual de la casilla

    beq  $s2, 5, cpu_modo_hunt   # Ya disparada (fallo previo) -> Reintentar
    beq  $s2, 6, cpu_modo_hunt   # Ya disparada (impacto previo) -> Reintentar

    j    cpu_ejecutar_disparo

    # ==========================================================================
    # B) MODO TARGET (Extracción de la Cola de Objetivos Adyacentes)
    # ==========================================================================
cpu_modo_target:
    lw   $t4, cola_ia_head
    sll  $t5, $t4, 2             # Offset en palabras

    la   $t6, cola_ia_x
    add  $t6, $t6, $t5
    lw   $s0, 0($t6)             # X objetivo

    la   $t7, cola_ia_y
    add  $t7, $t7, $t5
    lw   $s1, 0($t7)             # Y objetivo

    # Avanzar puntero circular de cabeza: head = (head + 1) & 63
    addi $t4, $t4, 1
    andi $t4, $t4, 63
    sw   $t4, cola_ia_head

    lw   $t1, cola_ia_count
    subi $t1, $t1, 1
    sw   $t1, cola_ia_count

    # Verificar si la casilla extraída ya fue atacada previamente
    sll  $t2, $s1, 4
    add  $t2, $t2, $s0
    la   $t3, tablero_j1
    add  $t3, $t3, $t2
    lb   $s2, 0($t3)

    # Si ya fue atacada, seguir vaciando la cola
    beq  $s2, 5, cpu_reintentar_target
    beq  $s2, 6, cpu_reintentar_target

    j    cpu_ejecutar_disparo

cpu_reintentar_target:
    lw   $t1, cola_ia_count
    bgtz $t1, cpu_modo_target
    j    cpu_modo_hunt           # Si la cola se agotó, volver a cazar

    # ==========================================================================
    # C) EJECUCIÓN DEL DISPARO DE LA CPU
    # ==========================================================================
cpu_ejecutar_disparo:
    # Notificar coordenadas en consola Run I/O
    li   $v0, 4
    la   $a0, msg_cpu_disparo_a
    syscall

    li   $v0, 1
    move $a0, $s0
    syscall

    li   $v0, 4
    la   $a0, msg_cpu_coma
    syscall

    li   $v0, 1
    move $a0, $s1
    syscall

    li   $v0, 4
    la   $a0, msg_cpu_cierra
    syscall

    # Evaluar resultado del disparo en tablero_j1
    sll  $t2, $s1, 4
    add  $t2, $t2, $s0
    la   $t3, tablero_j1
    add  $s3, $t3, $t2           # $s3 = Dirección del byte
    lb   $s2, 0($s3)             # $s2 = Valor lógico de la celda

    beqz $s2, cpu_es_fallo       # 0 = Agua -> Fallo

    # --------------------------------------------------------------------------
    # IMPACTO DE LA CPU EN UN BARCO DEL JUGADOR 1 (Valor 1..4)
    # --------------------------------------------------------------------------
    # Se canaliza mediante la subrutina unificada aplicar_impacto_en_matriz
    # para garantizar actualización de vidas, sonidos, +5 al hundir y victoria.
cpu_es_impacto:
    move $a0, $s0                # X (0..15)
    move $a1, $s1                # Y (0..15)
    move $a2, $s2                # ID barco (1..4)
    li   $a3, 2                  # Atacante = 2 (CPU)
    jal  aplicar_impacto_en_matriz

    # 6. ENCOLAR CASILLAS ADYACENTES (Modo Target para siguientes turnos)
    # Norte: (X, Y - 1)
    blez $s1, cpu_chk_sur
    move $a0, $s0
    subi $a1, $s1, 1
    jal  encolar_si_virgen

cpu_chk_sur:
    # Sur: (X, Y + 1)
    bge  $s1, 15, cpu_chk_este
    move $a0, $s0
    addi $a1, $s1, 1
    jal  encolar_si_virgen

cpu_chk_este:
    # Este: (X + 1, Y)
    bge  $s0, 15, cpu_chk_oeste
    addi $a0, $s0, 1
    move $a1, $s1
    jal  encolar_si_virgen

cpu_chk_oeste:
    # Oeste: (X - 1, Y)
    blez $s0, cpu_repite_turno
    subi $a0, $s0, 1
    move $a1, $s1
    jal  encolar_si_virgen

cpu_repite_turno:
    # La CPU acierta y repite turno de disparo
    j    cpu_bucle_tiros

    # --------------------------------------------------------------------------
    # FALLO DE LA CPU (El disparo cayó en agua virgen)
    # --------------------------------------------------------------------------
cpu_es_fallo:
    # 1. Reproducir sonido de salpicadura de agua
    jal  sonido_disparo_fallo

    # 2. Marcar estado 5 en matriz lógica
    li   $t4, 5
    sb   $t4, 0($s3)

    # 3. Pintar en VRAM: Tablero de Defensa de J1 con blanco (Filas 16..31)
    move $a0, $s0
    addi $a1, $s1, 16            # Y física en pantalla
    lw   $a2, COLOR_FALLO
    jal  dibujar_pixel

    li   $v0, 4
    la   $a0, msg_cpu_agua
    syscall

    # Cede el turno al jugador humano
    j    cpu_fin

cpu_fin:
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
# SUBRUTINA: encolar_si_virgen
# ------------------------------------------------------------------------------
# Entradas: $a0 = X, $a1 = Y
# Evalúa si la casilla no ha sido atacada (estado != 5 y != 6) y la encola.
# ==============================================================================
encolar_si_virgen:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    # Consultar celda en tablero_j1
    sll  $t0, $a1, 4
    add  $t0, $t0, $a0
    la   $t1, tablero_j1
    add  $t1, $t1, $t0
    lb   $t2, 0($t1)

    beq  $t2, 5, esv_fin
    beq  $t2, 6, esv_fin

    # Casilla virgen: encolar
    jal  encolar_objetivo_ia

esv_fin:
    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: encolar_objetivo_ia
# ------------------------------------------------------------------------------
# Entradas: $a0 = X, $a1 = Y
# Inserta un par de coordenadas (X, Y) en la cola circular cola_ia.
# ==============================================================================
encolar_objetivo_ia:
    lw   $t0, cola_ia_count
    bge  $t0, 64, eoi_fin        # Cola llena, descartar

    lw   $t1, cola_ia_tail
    sll  $t2, $t1, 2             # Offset en palabras

    la   $t3, cola_ia_x
    add  $t3, $t3, $t2
    sw   $a0, 0($t3)             # Guardar X

    la   $t4, cola_ia_y
    add  $t4, $t4, $t2
    sw   $a1, 0($t4)             # Guardar Y

    addi $t1, $t1, 1
    andi $t1, $t1, 63            # Puntero circular (0..63)
    sw   $t1, cola_ia_tail

    addi $t0, $t0, 1
    sw   $t0, cola_ia_count

eoi_fin:
    jr   $ra
