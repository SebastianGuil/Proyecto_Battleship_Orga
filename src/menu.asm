# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: menu.asm (Menú de Inicio, Selección de Modo y Setup Inicial)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Gestiona el arranque del juego, la presentación en consola de MARS (Run I/O)
# y la representación visual en el Bitmap Display del menú selector de modo.
# Al recibir la selección (tecla '1' para PvP o '2' para PvCPU), inicializa
# las estructuras lógicas de memoria (.data) y transiciona al estado de Setup.
# ==============================================================================

.text
.globl mostrar_menu
.globl mostrar_menu_visual
.globl mostrar_menu_consola
.globl procesar_seleccion_menu
.globl seleccion_1
.globl seleccion_2
.globl arrancar_setup
.globl limpiar_matrices_logicas

# ==============================================================================
# SUBRUTINA: mostrar_menu
# ------------------------------------------------------------------------------
# Propósito: Muestra el banner y opciones en la consola e inicializa el display.
# ==============================================================================
mostrar_menu:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    jal  mostrar_menu_consola
    jal  mostrar_menu_visual

    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: mostrar_menu_consola
# ------------------------------------------------------------------------------
# Propósito: Imprime en la consola Run I/O de MARS los textos informativos.
# ==============================================================================
mostrar_menu_consola:
    subu $sp, $sp, 4
    sw   $ra, 0($sp)

    # Imprimir Banner Principal
    li   $v0, 4
    la   $a0, msg_banner
    syscall

    # Imprimir Opciones del Menú
    li   $v0, 4
    la   $a0, msg_menu_opciones
    syscall

    lw   $ra, 0($sp)
    addu $sp, $sp, 4
    jr   $ra

# ==============================================================================
# SUBRUTINA: mostrar_menu_visual
# ------------------------------------------------------------------------------
# Propósito: Dibuja en la VRAM una interfaz gráfica dividida:
#            - Mitad superior (Filas 0..15): Verde militar representativo de PvP.
#            - Mitad inferior (Filas 16..31): Púrpura táctico para PvCPU.
#            - Línea divisoria central con acento visual.
# ==============================================================================
mostrar_menu_visual:
    subu $sp, $sp, 8
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)

    # 1. Zona Superior (Ataque / Opción 1 - PvP): 256 píxeles
    la   $a0, vram_buffer
    li   $a1, 256
    lw   $a2, COLOR_MENU_PVP
    jal  fill_rect

    # 2. Zona Inferior (Defensa / Opción 2 - PvCPU): 256 píxeles
    la   $a0, vram_buffer
    addi $a0, $a0, 1024         # 256 píxeles * 4 bytes = 1024 bytes de desplazamiento
    li   $a1, 256
    lw   $a2, COLOR_MENU_PVCPU
    jal  fill_rect

    # 3. Línea Divisoria decorativa (Fila 15, columnas 0..15 con COLOR_LINEA_DIV)
    # Se utiliza $s0 como contador protegido para que dibujar_pixel no lo corrompa
    li   $s0, 0                 # Columna X = 0..15
mmv_linea:
    bgt  $s0, 15, mmv_fin_linea
    move $a0, $s0
    li   $a1, 15
    lw   $a2, COLOR_LINEA_DIV
    jal  dibujar_pixel
    addi $s0, $s0, 1
    j    mmv_linea

mmv_fin_linea:
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    addu $sp, $sp, 8
    jr   $ra

# ==============================================================================
# SUBRUTINA: seleccion_1 (Modo PvP: Humano vs Humano)
# ------------------------------------------------------------------------------
# Disparada al pulsar tecla '1' (ASCII 49) desde controles.asm
# ==============================================================================
seleccion_1:
    lw   $t0, estado_juego
    bnez $t0, sel_ignorar       # Solo actúa si estamos en Estado 0 (Menú)

    # Fijar modo PvP
    li   $t1, 1
    sw   $t1, modo_juego

    # Imprimir en consola
    li   $v0, 4
    la   $a0, msg_sel_pvp
    syscall

    j    arrancar_setup

# ==============================================================================
# SUBRUTINA: seleccion_2 (Modo PvCPU: Humano vs CPU)
# ------------------------------------------------------------------------------
# Disparada al pulsar tecla '2' (ASCII 50) desde controles.asm
# ==============================================================================
seleccion_2:
    lw   $t0, estado_juego
    bnez $t0, sel_ignorar       # Solo actúa si estamos en Estado 0 (Menú)

    # Fijar modo PvCPU
    li   $t1, 2
    sw   $t1, modo_juego

    # Imprimir en consola
    li   $v0, 4
    la   $a0, msg_sel_pvcpu
    syscall

    j    arrancar_setup

sel_ignorar:
    j    bucle_juego

# ==============================================================================
# SUBRUTINA: procesar_seleccion_menu
# ------------------------------------------------------------------------------
# Manejador al presionar Enter estando en el Menú de inicio.
# ==============================================================================
procesar_seleccion_menu:
    # Si aún está en el menú, ignora Enter y vuelve al bucle
    j    bucle_juego

# ==============================================================================
# SUBRUTINA: arrancar_setup
# ------------------------------------------------------------------------------
# Propósito: Realiza la transición completa desde el Menú hacia la fase de Setup:
#            1. Cambia estado_juego a 1 (Setup).
#            2. Limpia matrices lógicas tablero_j1 y tablero_j2 en .data (todos ceros).
#            3. Inicializa vidas de los barcos y puntajes en 0.
#            4. Limpia la VRAM pintando todo el océano (COLOR_AGUA).
#            5. Posiciona el cursor en el tablero de defensa (X=0, Y=16).
#            6. Imprime instrucciones en consola de MARS y dibuja el cursor/preview.
# ==============================================================================
arrancar_setup:
    # 1. Configurar variables de máquina de estados
    li   $t0, 1
    sw   $t0, estado_juego      # Estado 1: Setup
    sw   $t0, jugador_setup     # Inicia Jugador 1
    sw   $t0, turno_actual      # Turno inicial: Jugador 1
    sw   $zero, barco_actual    # Barco índice 0: Portaaviones (5)
    sw   $zero, orientacion     # 0 = Horizontal
    li   $t0, 4
    sw   $t0, barcos_restantes  # 4 barcos restantes
    sw   $zero, puntaje_j1
    sw   $zero, puntaje_j2
    sw   $zero, fallos_turno

    # Reinicializar vidas de barcos a valores reglamentarios (5, 4, 3, 2)
    li   $t0, 5
    sw   $t0, vidas_barcos_j1 + 4
    sw   $t0, vidas_barcos_j2 + 4
    li   $t0, 4
    sw   $t0, vidas_barcos_j1 + 8
    sw   $t0, vidas_barcos_j2 + 8
    li   $t0, 3
    sw   $t0, vidas_barcos_j1 + 12
    sw   $t0, vidas_barcos_j2 + 12
    li   $t0, 2
    sw   $t0, vidas_barcos_j1 + 16
    sw   $t0, vidas_barcos_j2 + 16

    # Reinicializar vidas totales (5 + 4 + 3 + 2 = 14)
    li   $t0, 14
    sw   $t0, total_vidas_j1
    sw   $t0, total_vidas_j2

    # Reinicializar cola de la IA
    sw   $zero, cola_ia_head
    sw   $zero, cola_ia_tail
    sw   $zero, cola_ia_count

    # 2. Limpiar matrices lógicas en memoria (.data)
    jal  limpiar_matrices_logicas

    # 3. Limpiar pantalla completa con delimitación de tonos (Ataque y Defensa)
    jal  limpiar_pantalla_tableros

    # 4. Establecer posición inicial del cursor en Defensa (X=0, Y=16)
    li   $t0, 0
    sw   $t0, cursor_x
    li   $t0, 16
    sw   $t0, cursor_y

    # 5. Imprimir instrucciones para el Jugador 1
    li   $v0, 4
    la   $a0, msg_setup_j1
    syscall

    # Imprimir primer barco a colocar
    li   $v0, 4
    la   $a0, str_barco_1
    syscall
    li   $v0, 11
    li   $a0, 10                # '\n'
    syscall

    # 6. Dibujar el primer fotograma del cursor / preview
    jal  dibujar_cursor

    # 7. Regresar al bucle principal de control
    j    bucle_juego

# ==============================================================================
# SUBRUTINA: limpiar_matrices_logicas
# ------------------------------------------------------------------------------
# Propósito: Rellena con byte 0 (Agua vacía) los 256 bytes de tablero_j1 y
#            los 256 bytes de tablero_j2.
# ==============================================================================
limpiar_matrices_logicas:
    la   $t0, tablero_j1
    la   $t1, tablero_j2
    li   $t2, 0                 # Contador (0 a 255)

lml_bucle:
    beq  $t2, 256, lml_fin
    add  $t3, $t0, $t2
    sb   $zero, 0($t3)          # Poner en 0 celda de tablero_j1
    add  $t3, $t1, $t2
    sb   $zero, 0($t3)          # Poner en 0 celda de tablero_j2
    addi $t2, $t2, 1
    j    lml_bucle

lml_fin:
    jr   $ra
