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
# CARACTERÍSTICAS CLAVE:
# 1. Separación estricta Lógica / Gráficos: La VRAM es de sólo escritura.
# 2. Cero corrupción visual del cursor: borrar_cursor restaura el píxel consultando
#    la matriz lógica correspondiente (nunca pintando azul a ciegas).
# 3. Soporte para Tablero de Ataque (ocultando barcos enemigos no impactados)
#    y Tablero de Defensa (mostrando la flota propia y daños recibidos).
# 4. Preview visual reactivo para la fase de colocación de barcos (Setup).
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
# Entradas estándar:
#   $a0 = Coordenada X (Columna: 0 a 15)
#   $a1 = Coordenada Y (Fila: 0 a 31)
#   $a2 = Color hexadecimal (0x00RRGGBB)
# Soporte de compatibilidad: Si $a0/$a1 están fuera de rango, evalúa $t0/$t1 o cursor.
# Algoritmo de mapeo lineal:
#   Offset = ((Y * 16) + X) * 4 bytes
#   Dirección física = vram_buffer + Offset
# ==============================================================================
dibujar_pixel:
    # 1. Validación de argumentos estándar en $a0 y $a1
    bltz $a0, dp_check_t_regs
    bgt  $a0, 15, dp_check_t_regs
    bltz $a1, dp_check_t_regs
    bgt  $a1, 31, dp_check_t_regs
    move $t0, $a0
    move $t1, $a1
    j    dp_ejecutar

dp_check_t_regs:
    # 2. Compatibilidad hacia atrás: evaluar $t0 y $t1 si los llamadores antiguos no cargaron $a0/$a1
    bltz $t0, dp_check_cursor
    bgt  $t0, 15, dp_check_cursor
    bltz $t1, dp_check_cursor
    bgt  $t1, 31, dp_check_cursor
    j    dp_ejecutar

dp_check_cursor:
    # 3. Fallback de resguardo con la posición actual del cursor
    lw   $t0, cursor_x
    lw   $t1, cursor_y

dp_ejecutar:
    # Cálculo del desplazamiento lineal: ((Y * 16) + X) * 4
    sll  $t2, $t1, 4             # $t2 = Y * 16
    add  $t2, $t2, $t0           # $t2 = (Y * 16) + X
    sll  $t2, $t2, 2             # $t2 = Offset en bytes (palabras de 4 bytes)

    la   $t3, vram_buffer        # Base de VRAM (0x10010000)
    add  $t3, $t3, $t2           # Dirección física en VRAM
    sw   $a2, 0($t3)             # Inyección del color en display
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
    bge  $a1, 16, occ_es_defensa

    # --------------------------------------------------------------------------
    # CASO A: TABLERO DE ATAQUE (Filas 0..15)
    # Regla: Muestra el tablero del RIVAL, pero OCULTA barcos que no han sido
    #        impactados (deben verse como agua azul para no hacer trampa).
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
    # Si es 0 (agua) o 1..4 (barco enemigo intacto), se muestra como agua azul
    lw   $v0, COLOR_AGUA
    jr   $ra

    # --------------------------------------------------------------------------
    # CASO B: TABLERO DE DEFENSA (Filas 16..31)
    # Regla: Muestra el tablero PROPIO con la posición de la flota (Gris),
    #        los impactos recibidos (Rojo) y los disparos fallidos del rival (Blanco).
    # --------------------------------------------------------------------------
occ_es_defensa:
    subi $t4, $a1, 16           # Y local (0..15) dentro del tablero de defensa
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

# ==============================================================================
# SUBRUTINA: restaurar_celda_cursor (alias: borrar_cursor)
# ------------------------------------------------------------------------------
# Propósito: Redibuja la casilla donde está el cursor usando su color lógico real.
#            Garantiza CERO corrupción visual (nunca pinta azul a ciegas).
# ==============================================================================
borrar_cursor:
restaurar_celda_cursor:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    lw   $t0, estado_juego
    beq  $t0, 1, rcc_setup_mode

    # Modo Normal (Batalla): Restaurar píxel individual
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
# Propósito: En fase de colocación, dibuja la proyección visual del barco
#            según su tamaño y orientación antes de que el usuario lo confirme.
#            - Verde (COLOR_PREVIEW_OK): Cabe y no hay colisiones.
#            - Rojo (COLOR_PREVIEW_ERR): Excede bordes o colisiona con otro barco.
# ==============================================================================
renderizar_preview_setup:
    subu $sp, $sp, 28
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)
    sw   $s5, 24($sp)

    lw   $s0, cursor_x
    lw   $s1, cursor_y
    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s2, 0($t2)            # Longitud del barco
    lw   $s3, orientacion       # 0 = Horizontal, 1 = Vertical

    jal  validar_posicion_barco  # Retorna $v0 = 1 (Válido), 0 (Inválido)
    beqz $v0, rps_es_invalido
    lw   $s4, COLOR_PREVIEW_OK
    j    rps_comenzar_pintado

rps_es_invalido:
    lw   $s4, COLOR_PREVIEW_ERR

rps_comenzar_pintado:
    li   $s5, 0

rps_bucle:
    beq  $s5, $s2, rps_fin

    beq  $s3, 0, rps_calc_h
    # Vertical:
    move $a0, $s0
    add  $a1, $s1, $s5
    j    rps_pintar

rps_calc_h:
    # Horizontal:
    add  $a0, $s0, $s5
    move $a1, $s1

rps_pintar:
    move $a2, $s4
    jal  dibujar_pixel
    addi $s5, $s5, 1
    j    rps_bucle

rps_fin:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    lw   $s5, 24($sp)
    addu $sp, $sp, 28
    jr   $ra

# ==============================================================================
# SUBRUTINA: borrar_preview_setup
# ------------------------------------------------------------------------------
# Propósito: Restaura a sus colores originales todas las casillas que fueron
#            cubiertas por el preview visual al mover o rotar el barco.
# ==============================================================================
borrar_preview_setup:
    subu $sp, $sp, 24
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    sw   $s4, 20($sp)

    lw   $s0, cursor_x
    lw   $s1, cursor_y
    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $s2, 0($t2)            # Longitud
    lw   $s3, orientacion       # 0 = H, 1 = V
    li   $s4, 0                 # Contador

bps_bucle:
    beq  $s4, $s2, bps_fin

    beq  $s3, 0, bps_calc_h
    move $a0, $s0
    add  $a1, $s1, $s4
    j    bps_restaurar

bps_calc_h:
    add  $a0, $s0, $s4
    move $a1, $s1

bps_restaurar:
    jal  obtener_color_celda    # Retorna $v0
    move $a2, $v0

    beq  $s3, 0, bps_recalc_h
    move $a0, $s0
    add  $a1, $s1, $s4
    j    bps_do_dibujar

bps_recalc_h:
    add  $a0, $s0, $s4
    move $a1, $s1

bps_do_dibujar:
    jal  dibujar_pixel
    addi $s4, $s4, 1
    j    bps_bucle

bps_fin:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    lw   $s4, 20($sp)
    addu $sp, $sp, 24
    jr   $ra

# ==============================================================================
# SUBRUTINA: validar_posicion_barco
# ------------------------------------------------------------------------------
# Propósito: Verifica si la posición actual (cursor_x, cursor_y) con el barco
#            actual y su orientación cabe dentro del tablero de defensa y no
#            colisiona con barcos previamente fijados.
# Salida:
#   $v0 = 1 si es completamente válida, 0 si hay infracción.
# ==============================================================================
validar_posicion_barco:
    lw   $t0, cursor_x
    lw   $t1, cursor_y          # Rango esperado de defensa: 16..31
    lw   $t2, barco_actual
    sll  $t3, $t2, 2
    la   $t4, flota_tamanos
    add  $t4, $t4, $t3
    lw   $t5, 0($t4)            # Tamaño del barco
    lw   $t6, orientacion       # 0 = H, 1 = V

    # Validar que el inicio esté dentro de la zona de defensa
    bltz $t0, vpb_invalido
    bgt  $t0, 15, vpb_invalido
    blt  $t1, 16, vpb_invalido
    bgt  $t1, 31, vpb_invalido

    # Validar bordes según orientación
    beq  $t6, 0, vpb_val_h

    # Vertical: Y + tamaño <= 32
    add  $t7, $t1, $t5
    bgt  $t7, 32, vpb_invalido
    j    vpb_val_colision

vpb_val_h:
    # Horizontal: X + tamaño <= 16
    add  $t7, $t0, $t5
    bgt  $t7, 16, vpb_invalido

vpb_val_colision:
    # Validar colisión en la matriz lógica correspondiente
    lw   $t8, jugador_setup
    beq  $t8, 1, vpb_tab_j1
    la   $t9, tablero_j2
    j    vpb_col_bucle_init

vpb_tab_j1:
    la   $t9, tablero_j1

vpb_col_bucle_init:
    subi $t1, $t1, 16           # Y local (0..15)
    li   $t7, 0                 # Contador

vpb_col_bucle:
    beq  $t7, $t5, vpb_valido

    beq  $t6, 0, vpb_c_h
    # Vertical:
    move $a0, $t0
    add  $a1, $t1, $t7
    j    vpb_c_check

vpb_c_h:
    # Horizontal:
    add  $a0, $t0, $t7
    move $a1, $t1

vpb_c_check:
    sll  $t4, $a1, 4            # Y_local * 16
    add  $t4, $t4, $a0          # + X_local
    add  $t4, $t9, $t4
    lb   $t3, 0($t4)
    bnez $t3, vpb_invalido       # Si no es 0, celda ocupada

    addi $t7, $t7, 1
    j    vpb_col_bucle

vpb_valido:
    li   $v0, 1
    jr   $ra

vpb_invalido:
    li   $v0, 0
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
