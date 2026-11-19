# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: setup_flota.asm (Fase de Colocación de Barcos Manual y CPU)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Gestiona la colocación de la flota reglamentaria (4 barcos: 5, 4, 3, 2 casillas):
#   1. Colocación manual interactiva para Jugador 1 y Jugador 2 (en modo PvP).
#   2. Validación estricta de límites (defensa: 16..31) y colisiones lógicas.
#   3. Despliegue táctico aleatorio sin colisiones de la CPU con syscall 42.
#   4. Transición limpia a Fase de Batalla.
#
# AUDITORÍA DE REGISTROS Y PILA:
# - En fijar_barco y colocar_flota_cpu, todas las variables de bucle, límites y
#   coordenadas residen en registros $s0-$s7, perfectamente salvados y restaurados
#   en la pila ($sp).
# - Al concluir la confirmación, se transiciona con 'j bucle_juego'.
# ==============================================================================

.text
.globl fijar_barco
.globl colocar_flota_cpu
.globl iniciar_batalla
.globl iniciar_fase_batalla

# ==============================================================================
# SUBRUTINA: fijar_barco
# ------------------------------------------------------------------------------
# Propósito: Confirma y plasma el barco actual en la matriz lógica correspondiente
#            y en la VRAM con color gris acorazado (COLOR_BARCO).
# Registros protegidos en stack: $ra, $s0-$s7 (36 bytes).
# ==============================================================================
fijar_barco:
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

    # 1. Validar posición actual (límites espaciales y colisiones en matriz)
    jal  validar_posicion_barco  # Retorna $v0 = 1 (Válido), 0 (Inválido)
    beqz $v0, fb_posicion_invalida

    # 2. Cargar parámetros del barco en registros protegidos $s
    lw   $t0, barco_actual       # Índice (0..3)
    addi $s0, $t0, 1             # $s0 = ID del barco (1=Portaaviones, 2=Acorazado, 3=Submarino, 4=Fragata)

    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s1, 0($t2)             # $s1 = Longitud del barco (5, 4, 3, 2)

    lw   $s2, orientacion        # $s2 = 0 (Horizontal), 1 (Vertical)
    lw   $s3, cursor_x           # $s3 = Coordenada X inicial
    lw   $s4, cursor_y           # $s4 = Coordenada Y inicial (16..31)

    # Determinar matriz lógica según jugador_setup
    lw   $t3, jugador_setup
    beq  $t3, 1, fb_destino_j1
    la   $s5, tablero_j2
    j    fb_destino_ok

fb_destino_j1:
    la   $s5, tablero_j1

fb_destino_ok:
    # 3. Bucle para plasmar el barco en Matriz Lógica y en VRAM (Gris)
    li   $s6, 0                  # $s6 = Contador de celda (0 a longitud-1)

fb_bucle_fijar:
    beq  $s6, $s1, fb_fin_fijar

    beq  $s2, 0, fb_calc_h
    # Vertical:
    move $a0, $s3                # X = cursor_x
    add  $a1, $s4, $s6           # Y = cursor_y + k
    j    fb_escribir

fb_calc_h:
    # Horizontal:
    add  $a0, $s3, $s6           # X = cursor_x + k
    move $a1, $s4                # Y = cursor_y

fb_escribir:
    # A) Escribir en la Matriz Lógica (.data)
    subi $t4, $a1, 16            # Y_local (0..15)
    sll  $t5, $t4, 4             # Y_local * 16
    add  $t5, $t5, $a0           # + X
    add  $t5, $s5, $t5           # Dirección física del byte
    sb   $s0, 0($t5)             # Inyectar ID del barco

    # B) Pintar en VRAM con COLOR_BARCO (Gris acorazado)
    lw   $a2, COLOR_BARCO
    jal  dibujar_pixel

    addi $s6, $s6, 1
    j    fb_bucle_fijar

fb_fin_fijar:
    # 4. Imprimir confirmación en consola Run I/O
    li   $v0, 4
    la   $a0, msg_barco_ok_prefix
    syscall

    sll  $t6, $s0, 2
    la   $t7, tabla_nombres_barcos
    add  $t7, $t7, $t6
    lw   $a0, 0($t7)
    li   $v0, 4
    syscall

    li   $v0, 11
    li   $a0, 10                 # '\n'
    syscall

    # 5. Avanzar barco_actual
    lw   $t0, barco_actual
    addi $t0, $t0, 1
    sw   $t0, barco_actual

    lw   $t1, barcos_restantes
    subi $t1, $t1, 1
    sw   $t1, barcos_restantes

    lw   $t2, max_barcos         # 4 barcos reglamentarios
    blt  $t0, $t2, fb_siguiente_barco

    # --------------------------------------------------------------------------
    # FIN DE COLOCACIÓN (4 BARCOS COMPLETADOS PARA ESTE JUGADOR)
    # --------------------------------------------------------------------------
    lw   $t3, modo_juego
    beq  $t3, 1, fb_evaluar_pvp

    # --- MODO PvCPU: La CPU coloca su flota automáticamente ---
    li   $v0, 4
    la   $a0, msg_cpu_setup
    syscall

    jal  colocar_flota_cpu       # Colocación aleatoria sin colisiones para CPU

    li   $v0, 4
    la   $a0, msg_cpu_setup_ok
    syscall

    # Restaurar pila y pasar a batalla
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
    j    iniciar_fase_batalla

fb_evaluar_pvp:
    # --- MODO PvP: Evaluar si terminó J1 o J2 ---
    lw   $t4, jugador_setup
    beq  $t4, 2, fb_pvp_completo

    # J1 terminó, pasar a J2:
    li   $v0, 4
    la   $a0, msg_transicion_pvp
    syscall

    # Limpiar pantalla delimitando los dos tonos para ocultar los barcos de J1
    jal  limpiar_pantalla_tableros

    # Configurar parámetros para Jugador 2
    li   $t5, 2
    sw   $t5, jugador_setup
    sw   $zero, barco_actual
    li   $t5, 4
    sw   $t5, barcos_restantes
    sw   $zero, orientacion
    sw   $zero, cursor_x
    li   $t5, 16
    sw   $t5, cursor_y

    li   $v0, 4
    la   $a0, msg_setup_j2
    syscall

    li   $v0, 4
    la   $a0, msg_colocando_prefix
    syscall
    li   $v0, 4
    la   $a0, str_barco_1
    syscall
    li   $v0, 11
    li   $a0, 10
    syscall

    jal  dibujar_cursor
    j    fb_retorno

fb_pvp_completo:
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
    j    iniciar_fase_batalla

fb_siguiente_barco:
    # Resetear cursor y orientación para el siguiente barco
    sw   $zero, cursor_x
    li   $t5, 16
    sw   $t5, cursor_y
    sw   $zero, orientacion

    li   $v0, 4
    la   $a0, msg_colocando_prefix
    syscall

    lw   $t0, barco_actual
    addi $t0, $t0, 1             # ID siguiente barco
    sll  $t6, $t0, 2
    la   $t7, tabla_nombres_barcos
    add  $t7, $t7, $t6
    lw   $a0, 0($t7)
    li   $v0, 4
    syscall

    li   $v0, 11
    li   $a0, 10
    syscall

    jal  dibujar_cursor
    j    fb_retorno

fb_posicion_invalida:
    li   $v0, 4
    la   $a0, msg_error_posicion
    syscall
    jal  dibujar_cursor          # Dibuja preview en rojo para señalar error

fb_retorno:
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
# SUBRUTINA: colocar_flota_cpu
# ------------------------------------------------------------------------------
# Propósito: Posiciona los 4 barcos reglamentarios de la CPU en tablero_j2
#            de forma 100% aleatoria y sin colisiones utilizando syscall 42.
# Registros protegidos en stack: $ra, $s0-$s7 (36 bytes).
# ==============================================================================
colocar_flota_cpu:
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

    li   $s0, 0                  # $s0 = Índice de barco CPU (0..3)

cfc_bucle_barcos:
    beq  $s0, 4, cfc_fin_cpu

    # Longitud: flota_tamanos[s0]
    sll  $t0, $s0, 2
    la   $t1, flota_tamanos
    add  $t1, $t1, $t0
    lw   $s1, 0($t1)             # $s1 = Longitud
    addi $s7, $s0, 1             # $s7 = ID de barco (1..4)

cfc_reintentar:
    # 1. Orientación aleatoria (0 = H, 1 = V)
    li   $v0, 42
    li   $a0, 0
    li   $a1, 2
    syscall
    move $s2, $a0                # $s2 = Orientación

    # 2. Coordenadas aleatorias dentro de bordes válidos
    beq  $s2, 0, cfc_coord_h

    # --- VERTICAL ---
    # X en 0..15:
    li   $v0, 42
    li   $a0, 0
    li   $a1, 16
    syscall
    move $s3, $a0                # $s3 = X_cpu

    # Y en 0..(16 - longitud): límite = 17 - longitud
    li   $v0, 42
    li   $a0, 0
    li   $t2, 17
    sub  $a1, $t2, $s1
    syscall
    move $s4, $a0                # $s4 = Y_cpu
    j    cfc_verificar_colision

cfc_coord_h:
    # --- HORIZONTAL ---
    # X en 0..(16 - longitud):
    li   $v0, 42
    li   $a0, 0
    li   $t2, 17
    sub  $a1, $t2, $s1
    syscall
    move $s3, $a0                # $s3 = X_cpu

    # Y en 0..15:
    li   $v0, 42
    li   $a0, 0
    li   $a1, 16
    syscall
    move $s4, $a0                # $s4 = Y_cpu

cfc_verificar_colision:
    # 3. Comprobar que ninguna casilla esté ocupada en tablero_j2
    li   $s5, 0                  # Contador (0..longitud-1)
    la   $s6, tablero_j2

cfc_col_loop:
    beq  $s5, $s1, cfc_sin_colision

    beq  $s2, 0, cfc_col_calc_h
    # Vertical:
    move $t4, $s3
    add  $t5, $s4, $s5
    j    cfc_col_leer

cfc_col_calc_h:
    # Horizontal:
    add  $t4, $s3, $s5
    move $t5, $s4

cfc_col_leer:
    sll  $t6, $t5, 4             # Y * 16
    add  $t6, $t6, $t4           # + X
    add  $t6, $s6, $t6           # Dirección en tablero_j2
    lb   $t7, 0($t6)
    bnez $t7, cfc_reintentar     # Si no es 0, hay colisión -> Reintentar

    addi $s5, $s5, 1
    j    cfc_col_loop

cfc_sin_colision:
    # 4. Escribir el barco en tablero_j2
    li   $s5, 0

cfc_escribir_loop:
    beq  $s5, $s1, cfc_barco_listo

    beq  $s2, 0, cfc_esc_calc_h
    move $t4, $s3
    add  $t5, $s4, $s5
    j    cfc_esc_do

cfc_esc_calc_h:
    add  $t4, $s3, $s5
    move $t5, $s4

cfc_esc_do:
    sll  $t6, $t5, 4
    add  $t6, $t6, $t4
    add  $t6, $s6, $t6
    sb   $s7, 0($t6)             # Escribir ID del barco en la celda

    addi $s5, $s5, 1
    j    cfc_escribir_loop

cfc_barco_listo:
    addi $s0, $s0, 1             # Siguiente barco CPU
    j    cfc_bucle_barcos

cfc_fin_cpu:
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
# SUBRUTINA: iniciar_batalla / iniciar_fase_batalla
# ------------------------------------------------------------------------------
# Propósito: Transiciona a la Fase de Batalla (Estado 2):
#            - Inicializa cursor en el Tablero de Ataque (X=0, Y=0).
#            - Configura turno en Jugador 1 y reinicia fallos a 0.
#            - Renderiza pantalla completa (Ataque y Defensa) y dibuja el cursor.
#            - Imprime mensajes de inicio de batalla y turno de ataque en consola.
# ==============================================================================
iniciar_batalla:
iniciar_fase_batalla:
    # 1. Configurar máquina de estados para combate
    li   $t0, 2
    sw   $t0, estado_juego       # Estado 2 = Batalla
    li   $t0, 1
    sw   $t0, turno_actual       # Turno 1 = Jugador 1
    sw   $zero, fallos_turno

    # 2. Reubicar cursor en el Tablero de Ataque (mitad superior: X=0, Y=0)
    sw   $zero, cursor_x
    sw   $zero, cursor_y

    # 3. Renderizar pantalla completa de combate
    jal  renderizar_pantalla_completa
    jal  dibujar_cursor

    # 4. Imprimir banner y turno inicial en consola de MARS
    li   $v0, 4
    la   $a0, msg_batalla_inicio
    syscall

    li   $v0, 4
    la   $a0, msg_turno_j1
    syscall

    # 5. Ceder control al bucle principal de juego
    j    bucle_juego
