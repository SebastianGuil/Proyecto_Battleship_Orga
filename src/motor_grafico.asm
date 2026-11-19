# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: motor_grafico.asm (Controlador VRAM y Renderizado de Tableros)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Este módulo abstrae el acceso al Bitmap Display y garantiza que la VRAM refleje
# fielmente el estado de las matrices lógicas en memoria (.data).
#
# GARANTÍAS DE ROBUSTEZ:
# 1. Registros protegidos en bucles: En renderizado y borrado de previews se usan
#    exclusivamente registros $s0-$s7 (guardados/restaurados en $sp).
# 2. Toda subrutina anidada preserva $ra en el stack ($sp).
# 3. Cero bucles infinitos en bordes: Si una coordenada excede el rango de pantalla,
#    el flujo salta directamente a la etiqueta de incremento del contador, nunca
#    al inicio del bucle.
# 4. dibujar_pixel descarta silenciosamente cualquier coordenada fuera de rango.
# ==============================================================================

.text
.globl dibujar_pixel
.globl fill_rect
.globl limpiar_pantalla_color
.globl obtener_color_celda
.globl restaurar_celda_cursor
.globl borrar_cursor
.globl dibujar_cursor
.globl renderizar_tablero_ataque
.globl renderizar_tablero_defensa
.globl renderizar_pantalla_completa
.globl renderizar_preview_setup
.globl borrar_preview_setup
.globl validar_posicion_barco

# ==============================================================================
# SUBRUTINA: dibujar_pixel
# ------------------------------------------------------------------------------
# Propósito: Escribe un color de 32 bits (0x00RRGGBB) en las coordenadas físicas
#            (X, Y) de la VRAM mapeada.
# Entradas:
#   $a0 = Coordenada X (Columna: 0 a 15)
#   $a1 = Coordenada Y (Fila: 0 a 31)
#   $a2 = Color hexadecimal (0x00RRGGBB)
# Comportamiento: Si X o Y están fuera de rango, retorna inmediatamente (no-op).
# ==============================================================================
dibujar_pixel:
    # 1. Validación estricta de límites de VRAM (16 cols x 32 filas)
    bltz $a0, dp_retorno
    bgt  $a0, 15, dp_retorno
    bltz $a1, dp_retorno
    bgt  $a1, 31, dp_retorno

    # 2. Desplazamiento lineal: ((Y * 16) + X) * 4 bytes
    sll  $t0, $a1, 4             # $t0 = Y * 16
    add  $t0, $t0, $a0           # $t0 = (Y * 16) + X
    sll  $t0, $t0, 2             # $t0 = Offset en bytes (palabras de 4 bytes)

    # 3. Inyección en VRAM
    la   $t1, vram_buffer        # Base de VRAM (0x10010000)
    add  $t1, $t1, $t0           # Dirección física exacta
    sw   $a2, 0($t1)

dp_retorno:
    jr   $ra

# ==============================================================================
# SUBRUTINA: fill_rect
# ------------------------------------------------------------------------------
# Propósito: Rellena un bloque lineal de palabras consecutivas en la VRAM.
# Entradas:
#   $a0 = Dirección física inicial en VRAM
#   $a1 = Cantidad total de píxeles (palabras de 4 bytes)
#   $a2 = Color hexadecimal a inyectar
# ==============================================================================
fill_rect:
    li   $t0, 0                  # Contador de píxeles

fr_bucle:
    beq  $t0, $a1, fr_fin
    sll  $t1, $t0, 2             # offset = contador * 4
    add  $t2, $a0, $t1           # dirección destino
    sw   $a2, 0($t2)             # escribir color
    addi $t0, $t0, 1
    j    fr_bucle

fr_fin:
    jr   $ra

# ==============================================================================
# SUBRUTINA: limpiar_pantalla_color
# ------------------------------------------------------------------------------
# Propósito: Pinta la totalidad de la pantalla (512 píxeles) con un color único.
# Entradas:
#   $a0 = Color hexadecimal (0x00RRGGBB)
# ==============================================================================
limpiar_pantalla_color:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    move $a2, $a0               # Color
    la   $a0, vram_buffer       # Base VRAM
    li   $a1, 512               # 16x32 = 512 píxeles
    jal  fill_rect

    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: obtener_color_celda
# ------------------------------------------------------------------------------
# Propósito: Consulta las matrices lógicas del juego en memoria (.data) y determina
#            el color que DEBE mostrarse en la coordenada (X, Y) según el jugador
#            activo y si la celda pertenece a Ataque (0..15) o Defensa (16..31).
# Entradas:
#   $a0 = Coordenada X (0..15)
#   $a1 = Coordenada Y (0..31)
# Salidas:
#   $v0 = Código de color ARGB correspondiente
# ==============================================================================
obtener_color_celda:
    # 0. Validación de límites: si está fuera de rango, retornar COLOR_AGUA
    bltz $a0, occ_fuera_rango
    bgt  $a0, 15, occ_fuera_rango
    bltz $a1, occ_fuera_rango
    bgt  $a1, 31, occ_fuera_rango

    bge  $a1, 16, occ_es_defensa

    # --------------------------------------------------------------------------
    # CASO A: TABLERO DE ATAQUE (Filas 0..15)
    # --------------------------------------------------------------------------
occ_es_ataque:
    lw   $t0, turno_actual
    beq  $t0, 1, occ_atq_j1     # Si turno es J1, consulta tablero_j2
    la   $t1, tablero_j1        # Si turno es J2, consulta tablero_j1
    j    occ_atq_calc

occ_atq_j1:
    la   $t1, tablero_j2

occ_atq_calc:
    sll  $t2, $a1, 4            # Y * 16
    add  $t2, $t2, $a0          # (Y * 16) + X
    add  $t1, $t1, $t2          # Dirección del byte en matriz lógica
    lb   $t3, 0($t1)            # $t3 = Estado lógico de la casilla

    beq  $t3, 6, occ_col_impacto # 6 = Impacto confirmado -> Rojo
    beq  $t3, 5, occ_col_fallo   # 5 = Disparo al agua -> Blanco
    # Casillas 0 (agua) o 1..4 (barco enemigo intacto) se muestran como agua azul
    lw   $v0, COLOR_AGUA
    jr   $ra

    # --------------------------------------------------------------------------
    # CASO B: TABLERO DE DEFENSA (Filas 16..31)
    # --------------------------------------------------------------------------
occ_es_defensa:
    subi $t4, $a1, 16           # Y local (0..15) dentro de defensa
    lw   $t0, turno_actual

    # En fase de Setup (estado_juego == 1), usamos jugador_setup
    lw   $t2, estado_juego
    bne  $t2, 1, occ_def_turno_normal
    lw   $t0, jugador_setup

occ_def_turno_normal:
    beq  $t0, 1, occ_def_j1
    la   $t1, tablero_j2
    j    occ_def_calc

occ_def_j1:
    la   $t1, tablero_j1

occ_def_calc:
    sll  $t2, $t4, 4            # Y_local * 16
    add  $t2, $t2, $a0          # (Y_local * 16) + X
    add  $t1, $t1, $t2
    lb   $t3, 0($t1)

    beq  $t3, 6, occ_col_impacto # 6 = Impacto en barco propio -> Rojo
    beq  $t3, 5, occ_col_fallo   # 5 = Fallo recibido en agua -> Blanco
    beqz $t3, occ_col_agua      # 0 = Agua virgen -> Azul
    # 1..4 = Barco propio a flote -> Gris
    lw   $v0, COLOR_BARCO
    jr   $ra

occ_col_impacto:
    lw   $v0, COLOR_IMPACTO
    jr   $ra

occ_col_fallo:
    lw   $v0, COLOR_FALLO
    jr   $ra

occ_col_agua:
    lw   $v0, COLOR_AGUA
    jr   $ra

occ_fuera_rango:
    lw   $v0, COLOR_AGUA
    jr   $ra

# ==============================================================================
# SUBRUTINA: restaurar_celda_cursor (alias: borrar_cursor)
# ------------------------------------------------------------------------------
# Propósito: Redibuja la casilla donde está el cursor usando su color lógico real.
#            Garantiza CERO corrupción visual.
# ==============================================================================
borrar_cursor:
restaurar_celda_cursor:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    lw   $t0, estado_juego
    beq  $t0, 1, rcc_setup_mode

    # Modo Batalla: Restaurar píxel individual
    lw   $a0, cursor_x
    lw   $a1, cursor_y
    jal  obtener_color_celda     # $v0 = Color real
    move $a2, $v0
    lw   $a0, cursor_x
    lw   $a1, cursor_y
    jal  dibujar_pixel
    j    rcc_fin

rcc_setup_mode:
    jal  borrar_preview_setup

rcc_fin:
    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: dibujar_cursor
# ------------------------------------------------------------------------------
# Propósito: Dibuja el cursor visual en la coordenada activa (cursor_x, cursor_y).
#            En fase de Setup, dibuja además el preview completo del barco.
# ==============================================================================
dibujar_cursor:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    lw   $t0, estado_juego
    beq  $t0, 1, dc_setup_mode

    # Modo Batalla: Cursor de 1 píxel
    lw   $a0, cursor_x
    lw   $a1, cursor_y
    lw   $a2, COLOR_CURSOR
    jal  dibujar_pixel
    j    dc_fin

dc_setup_mode:
    jal  renderizar_preview_setup

dc_fin:
    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: renderizar_preview_setup
# ------------------------------------------------------------------------------
# Propósito: Dibuja la silueta del barco en fase de colocación.
#            Usa ÚNICAMENTE registros $s0-$s7 para proteger contadores y límites.
# Registros usados:
#   $s0 = cursor_x
#   $s1 = cursor_y
#   $s2 = tamaño del barco
#   $s3 = orientación (0=H, 1=V)
#   $s4 = contador de casilla
#   $s5 = coordenada X de la celda
#   $s6 = coordenada Y de la celda
#   $s7 = color de preview (Verde OK / Rojo ERR)
# ==============================================================================
renderizar_preview_setup:
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

    lw   $s0, cursor_x
    lw   $s1, cursor_y

    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s2, 0($t2)             # Longitud del barco (5, 4, 3, 2)
    lw   $s3, orientacion        # 0 = Horizontal, 1 = Vertical

    # 1. Validar posición (límites y colisión)
    jal  validar_posicion_barco  # Retorna $v0 = 1 (Válido), 0 (Inválido)
    beqz $v0, rps_es_invalido
    lw   $s7, COLOR_PREVIEW_OK   # Verde
    j    rps_comenzar_pintado

rps_es_invalido:
    lw   $s7, COLOR_PREVIEW_ERR  # Rojo

rps_comenzar_pintado:
    li   $s4, 0                  # Contador de celdas pintadas

rps_bucle:
    beq  $s4, $s2, rps_fin

    beq  $s3, 0, rps_calc_h
    # Vertical:
    move $s5, $s0
    add  $s6, $s1, $s4
    j    rps_dibujar_celda

rps_calc_h:
    # Horizontal:
    add  $s5, $s0, $s4
    move $s6, $s1

rps_dibujar_celda:
    # CERO bucles infinitos: si cae fuera de límites, salta al incremento de contador
    bltz $s5, rps_siguiente_celda
    bgt  $s5, 15, rps_siguiente_celda
    bltz $s6, rps_siguiente_celda
    bgt  $s6, 31, rps_siguiente_celda

    move $a0, $s5
    move $a1, $s6
    move $a2, $s7
    jal  dibujar_pixel

rps_siguiente_celda:
    addi $s4, $s4, 1            # Incremento obligatorio del contador
    j    rps_bucle

rps_fin:
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
# SUBRUTINA: borrar_preview_setup
# ------------------------------------------------------------------------------
# Propósito: Restaura a sus colores originales todas las casillas del preview.
#            Usa ÚNICAMENTE registros $s0-$s7 para garantizar estabilidad total.
# ==============================================================================
borrar_preview_setup:
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

    lw   $s0, cursor_x
    lw   $s1, cursor_y

    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s2, 0($t2)             # Longitud
    lw   $s3, orientacion        # 0 = H, 1 = V
    li   $s4, 0                  # Contador

bps_bucle:
    beq  $s4, $s2, bps_fin

    beq  $s3, 0, bps_calc_h
    # Vertical:
    move $s5, $s0
    add  $s6, $s1, $s4
    j    bps_restaurar_celda

bps_calc_h:
    # Horizontal:
    add  $s5, $s0, $s4
    move $s6, $s1

bps_restaurar_celda:
    # CERO bucles infinitos: si cae fuera, avanzar al incremento de contador
    bltz $s5, bps_siguiente_celda
    bgt  $s5, 15, bps_siguiente_celda
    bltz $s6, bps_siguiente_celda
    bgt  $s6, 31, bps_siguiente_celda

    # 1. Obtener color lógico real
    move $a0, $s5
    move $a1, $s6
    jal  obtener_color_celda    # Retorna $v0
    move $s7, $v0

    # 2. Restaurar píxel en VRAM
    move $a0, $s5
    move $a1, $s6
    move $a2, $s7
    jal  dibujar_pixel

bps_siguiente_celda:
    addi $s4, $s4, 1            # Incremento obligatorio del contador
    j    bps_bucle

bps_fin:
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
# SUBRUTINA: validar_posicion_barco
# ------------------------------------------------------------------------------
# Propósito: Evalúa si el barco en la posición (cursor_x, cursor_y) cabe en
#            la zona de defensa (16..31) y no colisiona con otro barco.
# Salida:
#   $v0 = 1 si es válida, 0 si infringe límites o hay colisión.
# Registros protegidos en stack: $s0-$s4 (20 bytes). Cero fugas de pila.
# ==============================================================================
validar_posicion_barco:
    subu $sp, $sp, 20
    sw   $s0, 0($sp)
    sw   $s1, 4($sp)
    sw   $s2, 8($sp)
    sw   $s3, 12($sp)
    sw   $s4, 16($sp)

    lw   $s0, cursor_x
    lw   $s1, cursor_y

    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s2, 0($t2)             # Longitud del barco
    lw   $s3, orientacion        # 0 = H, 1 = V

    # 1. Validar que el inicio esté dentro de defensa (X: 0..15, Y: 16..31)
    bltz $s0, vpb_invalido
    bgt  $s0, 15, vpb_invalido
    blt  $s1, 16, vpb_invalido
    bgt  $s1, 31, vpb_invalido

    # 2. Validar bordes según orientación
    beq  $s3, 0, vpb_val_h

    # Vertical: Y + longitud <= 32
    add  $t3, $s1, $s2
    bgt  $t3, 32, vpb_invalido
    j    vpb_val_colision

vpb_val_h:
    # Horizontal: X + longitud <= 16
    add  $t3, $s0, $s2
    bgt  $t3, 16, vpb_invalido

vpb_val_colision:
    # 3. Validar colisión en la matriz lógica correspondiente
    lw   $t4, jugador_setup
    beq  $t4, 1, vpb_tab_j1
    la   $t5, tablero_j2
    j    vpb_col_init

vpb_tab_j1:
    la   $t5, tablero_j1

vpb_col_init:
    subi $t6, $s1, 16           # Y_local (0..15)
    li   $s4, 0                 # Contador

vpb_col_bucle:
    beq  $s4, $s2, vpb_valido

    beq  $s3, 0, vpb_c_h
    # Vertical:
    move $t7, $s0               # X
    add  $t8, $t6, $s4          # Y_local
    j    vpb_c_eval

vpb_c_h:
    # Horizontal:
    add  $t7, $s0, $s4          # X
    move $t8, $t6               # Y_local

vpb_c_eval:
    sll  $t9, $t8, 4            # Y_local * 16
    add  $t9, $t9, $t7          # + X
    add  $t9, $t5, $t9          # Dirección física en matriz lógica
    lb   $t0, 0($t9)
    bnez $t0, vpb_invalido      # Si la celda != 0, hay colisión

    addi $s4, $s4, 1
    j    vpb_col_bucle

vpb_valido:
    li   $v0, 1
    j    vpb_fin

vpb_invalido:
    li   $v0, 0

vpb_fin:
    lw   $s0, 0($sp)
    lw   $s1, 4($sp)
    lw   $s2, 8($sp)
    lw   $s3, 12($sp)
    lw   $s4, 16($sp)
    addu $sp, $sp, 20
    jr   $ra

# ==============================================================================
# SUBRUTINA: renderizar_tablero_ataque
# ------------------------------------------------------------------------------
# Propósito: Redibuja completamente las 256 celdas de la mitad superior (filas 0..15).
# ==============================================================================
renderizar_tablero_ataque:
    subu $sp, $sp, 16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    li   $s1, 0                 # Y = 0

rta_bucle_y:
    bgt  $s1, 15, rta_fin
    li   $s0, 0                 # X = 0

rta_bucle_x:
    bgt  $s0, 15, rta_inc_y
    move $a0, $s0
    move $a1, $s1
    jal  obtener_color_celda    # Retorna $v0
    move $a2, $v0
    move $a0, $s0
    move $a1, $s1
    jal  dibujar_pixel
    addi $s0, $s0, 1
    j    rta_bucle_x

rta_inc_y:
    addi $s1, $s1, 1
    j    rta_bucle_y

rta_fin:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addu $sp, $sp, 16
    jr   $ra

# ==============================================================================
# SUBRUTINA: renderizar_tablero_defensa
# ------------------------------------------------------------------------------
# Propósito: Redibuja completamente las 256 celdas de la mitad inferior (filas 16..31).
# ==============================================================================
renderizar_tablero_defensa:
    subu $sp, $sp, 16
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)

    li   $s1, 16                # Y = 16

rtd_bucle_y:
    bgt  $s1, 31, rtd_fin
    li   $s0, 0                 # X = 0

rtd_bucle_x:
    bgt  $s0, 15, rtd_inc_y
    move $a0, $s0
    move $a1, $s1
    jal  obtener_color_celda    # Retorna $v0
    move $a2, $v0
    move $a0, $s0
    move $a1, $s1
    jal  dibujar_pixel
    addi $s0, $s0, 1
    j    rtd_bucle_x

rtd_inc_y:
    addi $s1, $s1, 1
    j    rtd_bucle_y

rtd_fin:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    addu $sp, $sp, 16
    jr   $ra

# ==============================================================================
# SUBRUTINA: renderizar_pantalla_completa
# ------------------------------------------------------------------------------
# Propósito: Redibuja ambos tableros (Ataque y Defensa) en su totalidad.
# ==============================================================================
renderizar_pantalla_completa:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    jal  renderizar_tablero_ataque
    jal  renderizar_tablero_defensa

    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra
