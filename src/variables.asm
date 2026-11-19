# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: variables.asm (Módulo Principal y Segmento de Memoria .data)
# ==============================================================================
#
# MAPA DE MEMORIA (.data) - BASE ADDRESS: 0x10010000 (Static Data)
# ------------------------------------------------------------------------------
# 0x10010000 - 0x100107FF : VRAM Buffer de Pantalla (2048 bytes = 512 píxeles)
#   - 0x10010000 - 0x100103FF : Tablero de Ataque (Filas 0..15, 256 píxeles / palabras)
#   - 0x10010400 - 0x100107FF : Tablero de Defensa (Filas 16..31, 256 píxeles / palabras)
# ------------------------------------------------------------------------------
# 0x10010800 - 0x100108FF : Matriz Lógica Jugador 1 (tablero_j1, 256 bytes)
# 0x10010900 - 0x100109FF : Matriz Lógica Jugador 2 / CPU (tablero_j2, 256 bytes)
# ------------------------------------------------------------------------------
# 0x10010A00 en adelante  : Variables de estado, vectores de vidas, paleta y strings
# ==============================================================================

.data
    # ==========================================================================
    # 1. BUFFER DE PANTALLA VRAM (OBLIGATORIAMENTE PRIMERA ETIQUETA EN 0x10010000)
    # ==========================================================================
    # Configuración requerida en MARS Bitmap Display:
    #   - Unit Width in Pixels: 16
    #   - Unit Height in Pixels: 16
    #   - Display Width in Pixels: 256  (16 unidades de ancho)
    #   - Display Height in Pixels: 512 (32 unidades de alto)
    #   - Base Address for Display: 0x10010000 (Static Data)
    # Total píxeles: 16 cols x 32 filas = 512 píxeles. Cada píxel = 4 bytes (word).
    # 512 * 4 = 2048 bytes de VRAM mapeada.
    .globl vram_buffer
vram_buffer:        .space 2048

    # ==========================================================================
    # 2. MATRICES LÓGICAS (SEPARACIÓN ESTRICTA LÓGICA / VRAM)
    # ==========================================================================
    # Cada celda ocupa exactamente 1 byte (16x16 = 256 bytes por tablero).
    # Valores de estado lógico de celda:
    #   0 = Agua virgen (no atacada)
    #   1 = Portaaviones intacto (longitud 5)
    #   2 = Acorazado intacto   (longitud 4)
    #   3 = Submarino intacto   (longitud 3)
    #   4 = Fragata intacta     (longitud 2)
    #   5 = Fallo (disparo al agua)
    #   6 = Impacto (barco alcanzado)
    .globl tablero_j1
    .globl tablero_j2
    .align 2
tablero_j1:         .space 256      # Matriz lógica de Jugador 1 (16x16 bytes)
tablero_j2:         .space 256      # Matriz lógica de Jugador 2 o CPU (16x16 bytes)

    # ==========================================================================
    # 3. PALETA DE COLORES (Formato ARGB / 0x00RRGGBB de 32 bits)
    # ==========================================================================
    .globl COLOR_AGUA
    .globl COLOR_AGUA_ATAQUE
    .globl COLOR_AGUA_DEFENSA
    .globl COLOR_BARCO
    .globl COLOR_IMPACTO
    .globl COLOR_FALLO
    .globl COLOR_CURSOR
    .globl COLOR_PREVIEW_OK
    .globl COLOR_PREVIEW_ERR
    .globl COLOR_FONDO
    .globl COLOR_LINEA_DIV
    .globl COLOR_MENU_PVP
    .globl COLOR_MENU_PVCPU

    .align 2
COLOR_AGUA:         .word 0x001438  # Compatibilidad general
COLOR_AGUA_ATAQUE:  .word 0x001438  # Azul marino oscuro (Tablero Superior: Filas 0..15)
COLOR_AGUA_DEFENSA: .word 0x003B73  # Azul océano más claro (Tablero Inferior: Filas 16..31)
COLOR_BARCO:        .word 0x757575  # Gris Acorazado
COLOR_IMPACTO:      .word 0xD50000  # Rojo Fuego (Impacto)
COLOR_FALLO:        .word 0xEEEEEE  # Blanco Espuma (Agua atacada)
COLOR_CURSOR:       .word 0xFFB300  # Ámbar / Naranja Brillante
COLOR_PREVIEW_OK:   .word 0x00E676  # Verde brillante (Colocación válida)
COLOR_PREVIEW_ERR:  .word 0xFF1744  # Rojo neón (Colisión o fuera de límite)
COLOR_FONDO:        .word 0x0A0E17  # Negro suave de marco
COLOR_LINEA_DIV:    .word 0x00E5FF  # Cian eléctrico (División entre tableros)
COLOR_MENU_PVP:     .word 0x1B5E20  # Verde militar para opción PvP
COLOR_MENU_PVCPU:   .word 0x4A148C  # Púrpura táctico para opción PvCPU

    # ==========================================================================
    # 4. DIRECCIONES DE HARDWARE Y ACCESO A PANTALLA
    # ==========================================================================
    .globl BASE_ATAQUE
    .globl BASE_DEFENSA
    .globl MMIO_STATUS
    .globl MMIO_DATA

    .align 2
BASE_ATAQUE:        .word 0x10010000  # VRAM Tablero Ataque (Filas 0..15)
BASE_DEFENSA:       .word 0x10010400  # VRAM Tablero Defensa (Filas 16..31)
MMIO_STATUS:        .word 0xffff0000  # Receiver Control (Bit 0 = tecla lista)
MMIO_DATA:          .word 0xffff0004  # Receiver Data (Código ASCII de tecla)

    # ==========================================================================
    # 5. ESTADO GLOBAL DEL JUEGO Y MÁQUINA DE ESTADOS
    # ==========================================================================
    .globl estado_juego
    .globl modo_juego
    .globl turno_actual
    .globl jugador_setup
    .globl barcos_restantes
    .globl barco_actual
    .globl orientacion
    .globl max_barcos
    .globl cursor_x
    .globl cursor_y
    .globl fallos_turno
    .globl puntaje_j1
    .globl puntaje_j2

    .align 2
estado_juego:       .word 0          # 0 = Menú, 1 = Setup, 2 = Batalla, 3 = Game Over
modo_juego:         .word 0          # 1 = PvP (2 humanos), 2 = PvCPU (Humano vs CPU)
turno_actual:       .word 1          # 1 = Turno de J1, 2 = Turno de J2 / CPU
jugador_setup:      .word 1          # 1 = J1 colocando, 2 = J2 colocando
barco_actual:       .word 0          # Índice del barco que se está colocando (0..3)
barcos_restantes:   .word 4          # Barcos restantes por colocar en la fase activa
orientacion:        .word 0          # 0 = Horizontal (derecha), 1 = Vertical (abajo)
max_barcos:         .word 4          # 4 barcos reglamentarios por jugador
cursor_x:           .word 0          # Coordenada X del cursor (Columnas 0..15)
cursor_y:           .word 16         # Coordenada Y del cursor (Filas 0..31, inicia en 16)
fallos_turno:       .word 0          # Contador de fallos consecutivos en turno actual
puntaje_j1:         .word 0          # Puntos acumulados Jugador 1
puntaje_j2:         .word 0          # Puntos acumulados Jugador 2 / CPU

    # ==========================================================================
    # 6. CONFIGURACIÓN DE LA FLOTA Y CONTADORES DE VIDA
    # ==========================================================================
    .globl flota_tamanos
    .globl vidas_barcos_j1
    .globl vidas_barcos_j2
    .globl total_vidas_j1
    .globl total_vidas_j2
    .globl tabla_nombres_barcos

    .align 2
# Tamaños de los 4 barcos reglamentarios:
# Barco 1 = Portaaviones (5 casillas)
# Barco 2 = Acorazado   (4 casillas)
# Barco 3 = Submarino   (3 casillas)
# Barco 4 = Fragata     (2 casillas)
flota_tamanos:      .word 5, 4, 3, 2

# Contadores de casillas vivas por ID de barco (Índice 0 nulo, 1..4 = IDs):
vidas_barcos_j1:    .word 0, 5, 4, 3, 2
vidas_barcos_j2:    .word 0, 5, 4, 3, 2

# Vidas totales de la flota (5 + 4 + 3 + 2 = 14 impactos para victoria):
total_vidas_j1:     .word 14
total_vidas_j2:     .word 14

    # ==========================================================================
    # 6.1 COLA DE OBJETIVOS DE LA IA CPU (MODO HUNT & TARGET)
    # ==========================================================================
    .globl cola_ia_x
    .globl cola_ia_y
    .globl cola_ia_head
    .globl cola_ia_tail
    .globl cola_ia_count

    .align 2
cola_ia_x:          .space 64        # Buffer circular de objetivos X (hasta 64)
cola_ia_y:          .space 64        # Buffer circular de objetivos Y (hasta 64)
cola_ia_head:       .word 0          # Índice de extracción (desencolar)
cola_ia_tail:       .word 0          # Índice de inserción (encolar)
cola_ia_count:      .word 0          # Cantidad de objetivos pendientes

    # ==========================================================================
    # 7. MENSAJES Y CADENAS DE CONSOLA RUN I/O (Syscall 4)
    # ==========================================================================
    .globl msg_banner
    .globl msg_menu_opciones
    .globl msg_sel_pvp
    .globl msg_sel_pvcpu
    .globl msg_setup_j1
    .globl msg_setup_j2
    .globl msg_prompt_tecla
    .globl msg_error_posicion
    .globl msg_barco_ok_prefix
    .globl msg_colocando_prefix
    .globl msg_cpu_setup
    .globl msg_cpu_setup_ok
    .globl msg_batalla_inicio
    .globl msg_turno_j1
    .globl msg_turno_j2
    .globl msg_transicion_pvp
    .globl msg_rotacion_h
    .globl msg_rotacion_v
    .globl msg_ya_atacada
    .globl msg_impacto
    .globl msg_fallo
    .globl msg_fallo_num
    .globl msg_de_tres
    .globl msg_cambio_turno_pvp
    .globl msg_hundido_banner
    .globl msg_comodin_activado
    .globl msg_cpu_turno_banner
    .globl msg_cpu_disparo_a
    .globl msg_cpu_coma
    .globl msg_cpu_cierra
    .globl msg_cpu_acierto
    .globl msg_cpu_agua
    .globl msg_cpu_hundio_barco
    .globl msg_victoria_j1
    .globl msg_victoria_j2
    .globl msg_victoria_cpu
    .globl msg_game_over
    .globl msg_puntaje_j1_txt
    .globl msg_puntaje_j2_txt
    .globl msg_puntos_sufijo
    .globl msg_repite_disparo
    .globl str_barco_1
    .globl str_barco_2
    .globl str_barco_3
    .globl str_barco_4

str_barco_1:        .asciiz "Portaaviones (5 casillas)"
str_barco_2:        .asciiz "Acorazado (4 casillas)"
str_barco_3:        .asciiz "Submarino (3 casillas)"
str_barco_4:        .asciiz "Fragata (2 casillas)"

    .align 2
tabla_nombres_barcos:
    .word 0, str_barco_1, str_barco_2, str_barco_3, str_barco_4

msg_banner:
    .asciiz "\n========================================================\n       BATTLESHIP MIPS R2000 - MARS 4.5 SIMULATOR       \n         Arquitectura de Computadores e Interfaces      \n========================================================\n"

msg_menu_opciones:
    .asciiz "SELECCIONA MODO DE JUEGO (Presiona en teclado MMIO):\n  [1] Jugador vs Jugador (PvP)\n  [2] Jugador vs Computadora (PvCPU - Hunt & Target)\n--------------------------------------------------------\nEsperando seleccion (1 o 2)...\n"

msg_prompt_tecla:
    .asciiz ">> Tecla detectada en MMIO. Procesando...\n"

msg_sel_pvp:
    .asciiz "\n[MODO SELECCIONADO]: Jugador vs Jugador (PvP)\n"

msg_sel_pvcpu:
    .asciiz "\n[MODO SELECCIONADO]: Jugador vs Computadora (PvCPU)\n"

msg_setup_j1:
    .asciiz "\n========================================================\n           FASE DE COLOCACION: JUGADOR 1                \n========================================================\nUbica tus 4 barcos en el TABLERO DE DEFENSA (filas 16-31).\nControles:\n  [W/A/S/D] Mover cursor\n  [R]       Rotar barco (Horizontal / Vertical)\n  [ENTER/E] Confirmar colocacion del barco\n--------------------------------------------------------\n"

msg_setup_j2:
    .asciiz "\n========================================================\n           FASE DE COLOCACION: JUGADOR 2                \n========================================================\nUbica tus 4 barcos en el TABLERO DE DEFENSA (filas 16-31).\nControles:\n  [W/A/S/D] Mover cursor\n  [R]       Rotar barco (Horizontal / Vertical)\n  [ENTER/E] Confirmar colocacion del barco\n--------------------------------------------------------\n"

msg_error_posicion:
    .asciiz "[ERROR] Posicion invalida o colision con otro barco. Elige otra.\n"

msg_barco_ok_prefix:
    .asciiz "[OK] Barco fijado con exito: "

msg_colocando_prefix:
    .asciiz "Colocando barco: "

msg_cpu_setup:
    .asciiz "\n[CPU] Desplegando flota enemiga de forma tactica y aleatoria...\n"

msg_cpu_setup_ok:
    .asciiz "[CPU] ¡Flota enemiga desplegada con exito!\n"

msg_batalla_inicio:
    .asciiz "\n========================================================\n           ¡COMIENZA LA BATALLA NAVAL!                  \n========================================================\nTablero Superior (0-15) : Zona de Ataque (Disparos)\nTablero Inferior (16-31): Zona de Defensa (Tu Flota)\nControles:\n  [W/A/S/D] Apuntar coordenada\n  [ENTER/E] Disparar misil\n========================================================\n"

msg_turno_j1:
    .asciiz "\n>>> TURNO DE ATAQUE: JUGADOR 1 <<<\n"

msg_turno_j2:
    .asciiz "\n>>> TURNO DE ATAQUE: JUGADOR 2 <<<\n"

msg_transicion_pvp:
    .asciiz "\n--------------------------------------------------------\nJugador 1 ha terminado de colocar su flota.\nPasa el turno a Jugador 2. Pantalla despejada.\n--------------------------------------------------------\n"

msg_rotacion_h:
    .asciiz "Orientacion: [HORIZONTAL]\n"

msg_rotacion_v:
    .asciiz "Orientacion: [VERTICAL]\n"

msg_ya_atacada:
    .asciiz "[AVISO] Casilla ya atacada previamente. Elige otra coordenada.\n"

msg_impacto:
    .asciiz "¡¡¡IMPACTO CONFIRMADO!!! (+1 punto)\n"

msg_fallo:
    .asciiz "Agua... Disparo fallido.\n"

msg_fallo_num:
    .asciiz "Fallo consecutivo: "

msg_de_tres:
    .asciiz " de 3.\n"

msg_cambio_turno_pvp:
    .asciiz "\n========================================================\n3 fallos consecutivos alcanzados. ¡CAMBIO DE TURNO!\n========================================================\n"

msg_hundido_banner:
    .asciiz "\n********************************************************\n*** ¡¡¡BARCO HUNDIDO!!! (+5 puntos extra)             ***\n********************************************************\n"

msg_comodin_activado:
    .asciiz "\n>>> ¡¡¡COMODIN MISTERIOSO ACTIVADO!!! ATAQUE EN AREA <<<\n"

msg_cpu_turno_banner:
    .asciiz "\n>>> TURNO DE LA COMPUTADORA (CPU) <<<\n"

msg_cpu_disparo_a:
    .asciiz "[CPU] Disparo a casilla ("

msg_cpu_coma:
    .asciiz ", "

msg_cpu_cierra:
    .asciiz "): "

msg_cpu_acierto:
    .asciiz "¡IMPACTO EN TU FLOTA!\n"

msg_cpu_agua:
    .asciiz "Agua.\n"

msg_cpu_hundio_barco:
    .asciiz "\n[CPU] ¡¡¡La computadora ha hundido uno de tus barcos!!!\n"

msg_repite_disparo:
    .asciiz "¡Impacto certero! Repites turno de disparo.\n"

msg_victoria_j1:
    .asciiz "\n========================================================\n           ¡¡¡VICTORIA PARA EL JUGADOR 1!!!             \n========================================================\n"

msg_victoria_j2:
    .asciiz "\n========================================================\n           ¡¡¡VICTORIA PARA EL JUGADOR 2!!!             \n========================================================\n"

msg_victoria_cpu:
    .asciiz "\n========================================================\n              ¡¡¡LA CPU HA GANADO!!!                    \n========================================================\n"

msg_game_over:
    .asciiz "                      GAME OVER                         \n========================================================\n"

msg_puntaje_j1_txt:
    .asciiz "PUNTUACION FINAL:\n  Jugador 1: "

msg_puntaje_j2_txt:
    .asciiz " puntos\n  Jugador 2 / CPU: "

msg_puntos_sufijo:
    .asciiz " puntos\n========================================================\n"


# ==============================================================================
# SECCIÓN DE CÓDIGO (.text) Y PUNTO DE ENTRADA PRINCIPAL
# ==============================================================================
.text
.globl main
.globl bucle_juego

main:
    # --------------------------------------------------------------------------
    # 1. Inicialización del Stack Pointer ($sp)
    # --------------------------------------------------------------------------
    # MARS inicializa $sp en 0x7ffffffc por defecto, aseguramos alineación.
    
    # --------------------------------------------------------------------------
    # 2. Inicializar sistema y mostrar Menú
    # --------------------------------------------------------------------------
    jal mostrar_menu

bucle_juego:
    # --------------------------------------------------------------------------
    # 3. Bucle principal impulsado por eventos (MMIO Keyboard Polling)
    # --------------------------------------------------------------------------
    j polling_teclado

# ==============================================================================
# ENLACE MODULAR DE COMPONENTES (.include)
# ==============================================================================
# Los módulos se enlazan en orden jerárquico respetando las dependencias:
.include "motor_grafico.asm"
.include "menu.asm"
.include "controles.asm"
.include "setup_flota.asm"
.include "reglas.asm"
.include "ia_cpu.asm"
.include "comodin.asm"
