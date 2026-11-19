# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: reglas.asm (Motor de Reglas de Combate, Turnos, Puntuación y Fin)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Centraliza la lógica de combate de la Fase de Batalla (Estado 2):
# 1. Prohibición de disparos a casillas ya atacadas (estados 5 y 6).
# 2. Subrutina unificada aplicar_impacto_en_matriz:
#    - Todo impacto (humano, comodín o CPU) se procesa por esta función.
#    - Resta vida a vidas_barcos_jX[id] y a total_vidas_jX.
#    - Detecta hundimiento (vida == 0), otorga +5 puntos extra y reproduce sonido.
#    - Evalúa inmediatamente si total_vidas_jX <= 0 para declarar fin de juego.
# 3. Regla de turnos:
#    - Impacto: El atacante repite turno.
#    - Fallo en PvCPU: Cede el turno inmediatamente a la CPU.
#    - Fallo en PvP: Hasta 3 fallos consecutivos antes de rotar jugador y refrescar VRAM.
# 4. Declaración de fin de juego con anuncio de ganador, GAME OVER y puntajes.
# ==============================================================================

.text
.globl procesar_disparo
.globl aplicar_impacto_en_matriz
.globl cambiar_turno_pvp
.globl declarar_fin_juego

# ==============================================================================
# SUBRUTINA: procesar_disparo
# ------------------------------------------------------------------------------
# Invocada al presionar Enter o 'E' en el Tablero de Ataque (cursor_x, cursor_y).
# Registros protegidos en stack: $ra, $s0-$s7 (36 bytes).
# ==============================================================================
procesar_disparo:
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

    lw   $s0, cursor_x           # X del disparo (0..15)
    lw   $s1, cursor_y           # Y del disparo (0..15 en Ataque)
    lw   $s2, turno_actual       # 1 = J1, 2 = J2

    # 1. Determinar matriz lógica del rival a atacar
    beq  $s2, 1, pd_atacar_j2
    la   $s3, tablero_j1         # Atacado es J1
    j    pd_leer_celda

pd_atacar_j2:
    la   $s3, tablero_j2         # Atacado es J2

pd_leer_celda:
    sll  $t0, $s1, 4             # Y * 16
    add  $t0, $t0, $s0           # + X
    add  $s4, $s3, $t0           # Dirección del byte en matriz
    lb   $s5, 0($s4)             # $s5 = Estado actual

    # 2. Validar casilla virgen
    beq  $s5, 5, pd_ya_atacada
    beq  $s5, 6, pd_ya_atacada

    # 3. Evaluar Impacto vs Fallo
    beqz $s5, pd_es_fallo

    # ==========================================================================
    # CASO: ¡IMPACTO CERTERO! (Barco enemigo alcanzado)
    # ==========================================================================
pd_es_impacto:
    move $a0, $s0                # X
    move $a1, $s1                # Y
    move $a2, $s5                # ID barco (1..4)
    move $a3, $s2                # Atacante (1 o 2)
    jal  aplicar_impacto_en_matriz

    # En impacto certero, el jugador repite turno
    sw   $zero, fallos_turno

    li   $v0, 4
    la   $a0, msg_repite_disparo
    syscall

    # Tirada del Comodín Misterioso (1 en 7)
    jal  calcular_comodin

    j    pd_salir

    # ==========================================================================
    # CASO: ¡FALLO! (El misil cayó en agua)
    # ==========================================================================
pd_es_fallo:
    # 1. Reproducir sonido de salpicadura de agua
    jal  sonido_disparo_fallo

    # 2. Marcar celda en matriz lógica con estado 5 (Fallo)
    li   $t1, 5
    sb   $t1, 0($s4)

    # 3. Pintar en VRAM con COLOR_FALLO (Blanco)
    move $a0, $s0
    move $a1, $s1
    lw   $a2, COLOR_FALLO
    jal  dibujar_pixel

    li   $v0, 4
    la   $a0, msg_fallo
    syscall

    # 4. Enrutamiento de turnos según modo de juego
    lw   $t2, modo_juego
    beq  $t2, 2, pd_fallo_pvcpu

    # --- MODO PvP: Hasta 3 fallos consecutivos ---
    lw   $t3, fallos_turno
    addi $t3, $t3, 1
    sw   $t3, fallos_turno

    blt  $t3, 3, pd_pvp_continua

    # Al alcanzar 3 fallos consecutivos: alternar turno
    jal  cambiar_turno_pvp
    j    pd_salir

pd_pvp_continua:
    li   $v0, 4
    la   $a0, msg_fallo_num
    syscall
    li   $v0, 1
    lw   $a0, fallos_turno
    syscall
    li   $v0, 4
    la   $a0, msg_de_tres
    syscall
    j    pd_salir

pd_fallo_pvcpu:
    # --- MODO PvCPU: El fallo cede el turno a la CPU ---
    li   $t3, 2
    sw   $t3, turno_actual
    sw   $zero, fallos_turno

    li   $v0, 4
    la   $a0, msg_cpu_turno_banner
    syscall

    # Ejecutar algoritmo Hunt & Target de la CPU
    jal  turno_cpu

    # Si el juego continúa tras el turno de la CPU, devolver control a J1
    lw   $t4, estado_juego
    beq  $t4, 3, pd_salir
    li   $t5, 1
    sw   $t5, turno_actual
    sw   $zero, fallos_turno

    li   $v0, 4
    la   $a0, msg_turno_j1
    syscall
    j    pd_salir

pd_ya_atacada:
    li   $v0, 4
    la   $a0, msg_ya_atacada
    syscall

pd_salir:
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
    j    bucle_juego

# ==============================================================================
# SUBRUTINA UNIFICADA: aplicar_impacto_en_matriz
# ------------------------------------------------------------------------------
# Propósito: Canaliza TODO impacto (humano, comodín o CPU) para garantizar
#            consistencia absoluta en puntajes, vidas, sonidos y fin de juego.
# Entradas:
#   $a0 = Coordenada X (0..15)
#   $a1 = Coordenada Y (0..15 en Ataque para J1/J2)
#   $a2 = ID del barco golpeado (1..4)
#   $a3 = Jugador atacante (1 = J1, 2 = J2 o CPU)
# ==============================================================================
aplicar_impacto_en_matriz:
    subu $sp, $sp, 24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)

    move $s0, $a0                # X
    move $s1, $a1                # Y
    move $s2, $a2                # ID barco (1..4)
    move $s3, $a3                # Atacante (1 o 2)

    # 1. Marcar celda en matriz lógica con 6 (Impacto)
    beq  $s3, 1, aim_tab_j2
    la   $s4, tablero_j1         # Atacado es J1
    j    aim_escribir_byte

aim_tab_j2:
    la   $s4, tablero_j2         # Atacado es J2

aim_escribir_byte:
    sll  $t0, $s1, 4
    add  $t0, $t0, $s0
    add  $t0, $s4, $t0
    li   $t1, 6
    sb   $t1, 0($t0)             # Estado 6 = Impacto

    # 2. Pintar en VRAM con COLOR_IMPACTO (Rojo)
    # Si quien atacó fue la CPU en modo PvCPU, la coordenada física es en Defensa (16 + Y)
    lw   $t8, modo_juego
    beq  $t8, 2, aim_eval_cpu_vram
    # Modo normal (J1 o J2 atacando en zona de ataque superior):
    move $a0, $s0
    move $a1, $s1
    j    aim_do_vram

aim_eval_cpu_vram:
    beq  $s3, 2, aim_cpu_defensa
    move $a0, $s0
    move $a1, $s1
    j    aim_do_vram

aim_cpu_defensa:
    move $a0, $s0
    addi $a1, $s1, 16            # Fila de defensa de J1 en pantalla

aim_do_vram:
    lw   $a2, COLOR_IMPACTO
    jal  dibujar_pixel

    # 3. Reproducir sonido de impacto
    jal  sonido_impacto

    # 4. Sumar +1 punto al atacante
    beq  $s3, 1, aim_inc_j1
    lw   $t2, puntaje_j2
    addi $t2, $t2, 1
    sw   $t2, puntaje_j2
    j    aim_decrementar_vidas

aim_inc_j1:
    lw   $t2, puntaje_j1
    addi $t2, $t2, 1
    sw   $t2, puntaje_j1

aim_decrementar_vidas:
    # 5. Restar 1 vida al barco específico y 1 a total_vidas del bando defensor
    sll  $t3, $s2, 2             # ID * 4
    beq  $s3, 1, aim_vidas_defensor_j2

    # Defensor es J1:
    la   $t4, vidas_barcos_j1
    add  $t4, $t4, $t3
    lw   $t5, 0($t4)
    subi $t5, $t5, 1
    sw   $t5, 0($t4)             # Vida restante del barco

    lw   $t6, total_vidas_j1
    subi $t6, $t6, 1
    sw   $t6, total_vidas_j1
    j    aim_notificar

aim_vidas_defensor_j2:
    # Defensor es J2/CPU:
    la   $t4, vidas_barcos_j2
    add  $t4, $t4, $t3
    lw   $t5, 0($t4)
    subi $t5, $t5, 1
    sw   $t5, 0($t4)

    lw   $t6, total_vidas_j2
    subi $t6, $t6, 1
    sw   $t6, total_vidas_j2

aim_notificar:
    li   $v0, 4
    la   $a0, msg_impacto
    syscall

    # 6. Evaluar si el barco fue HUNDIDO (vida restante <= 0)
    bgtz $t5, aim_check_victoria_global

    # ¡BARCO HUNDIDO!
    jal  sonido_hundido

    li   $v0, 4
    la   $a0, msg_hundido_banner
    syscall

    # Imprimir nombre del barco hundido
    sll  $t7, $s2, 2
    la   $t8, tabla_nombres_barcos
    add  $t8, $t8, $t7
    lw   $a0, 0($t8)
    li   $v0, 4
    syscall
    li   $v0, 11
    li   $a0, 10
    syscall

    # Sumar +5 puntos extra al atacante
    beq  $s3, 1, aim_bonus_j1
    lw   $t2, puntaje_j2
    addi $t2, $t2, 5
    sw   $t2, puntaje_j2
    j    aim_check_victoria_global

aim_bonus_j1:
    lw   $t2, puntaje_j1
    addi $t2, $t2, 5
    sw   $t2, puntaje_j1

aim_check_victoria_global:
    # 7. Comprobación estricta de fin de juego (total_vidas <= 0)
    beq  $s3, 1, aim_vic_j2
    # Defensor es J1:
    lw   $t6, total_vidas_j1
    blez $t6, declarar_fin_juego
    j    aim_fin

aim_vic_j2:
    # Defensor es J2:
    lw   $t6, total_vidas_j2
    blez $t6, declarar_fin_juego

aim_fin:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addu $sp, $sp, 24
    jr   $ra

# ==============================================================================
# SUBRUTINA: cambiar_turno_pvp
# ------------------------------------------------------------------------------
# Alterna el turno en PvP tras 3 fallos consecutivos y refresca la pantalla.
# ==============================================================================
cambiar_turno_pvp:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    li   $v0, 4
    la   $a0, msg_cambio_turno_pvp
    syscall

    lw   $t0, turno_actual
    beq  $t0, 1, ctp_a_j2
    li   $t1, 1
    sw   $t1, turno_actual
    j    ctp_refresh

ctp_a_j2:
    li   $t1, 2
    sw   $t1, turno_actual

ctp_refresh:
    sw   $zero, fallos_turno

    # Renderizar pantalla completa adaptada al nuevo jugador activo
    jal  renderizar_pantalla_completa

    # Ubicar cursor en (0, 0)
    sw   $zero, cursor_x
    sw   $zero, cursor_y
    jal  dibujar_cursor

    # Anunciar nuevo turno
    lw   $t0, turno_actual
    li   $v0, 4
    beq  $t0, 1, ctp_msg_j1
    la   $a0, msg_turno_j2
    syscall
    j    ctp_salir

ctp_msg_j1:
    la   $a0, msg_turno_j1
    syscall

ctp_salir:
    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: declarar_fin_juego
# ------------------------------------------------------------------------------
# Propósito: Anuncia la victoria, GAME OVER, puntajes y finaliza MARS con syscall 10.
# ==============================================================================
declarar_fin_juego:
    li   $t0, 3
    sw   $t0, estado_juego       # Estado 3 = Game Over

    # Reproducir fanfarria de victoria
    jal  sonido_victoria

    lw   $t1, total_vidas_j2
    blez $t1, dfj_gana_j1        # Si total_vidas_j2 <= 0, ganó J1

    # Si total_vidas_j1 <= 0, ganó el rival (J2 o CPU)
    lw   $t2, modo_juego
    beq  $t2, 2, dfj_gana_cpu
    li   $v0, 4
    la   $a0, msg_victoria_j2
    syscall
    j    dfj_puntajes

dfj_gana_cpu:
    li   $v0, 4
    la   $a0, msg_victoria_cpu
    syscall
    j    dfj_puntajes

dfj_gana_j1:
    li   $v0, 4
    la   $a0, msg_victoria_j1
    syscall

dfj_puntajes:
    li   $v0, 4
    la   $a0, msg_game_over
    syscall

    li   $v0, 4
    la   $a0, msg_puntaje_j1_txt
    syscall

    li   $v0, 1
    lw   $a0, puntaje_j1
    syscall

    li   $v0, 4
    la   $a0, msg_puntaje_j2_txt
    syscall

    li   $v0, 1
    lw   $a0, puntaje_j2
    syscall

    li   $v0, 4
    la   $a0, msg_puntos_sufijo
    syscall

    # Detener la simulación de MARS limpiamente
    li   $v0, 10
    syscall
