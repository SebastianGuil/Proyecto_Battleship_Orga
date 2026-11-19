.data
    # --- PALETA DE COLORES ---
    COLOR_AGUA:      .word 0x0000FF  # Azul
    COLOR_BARCO:     .word 0x808080  # Gris
    COLOR_IMPACTO:   .word 0xFF0000  # Rojo
    COLOR_FALLO:     .word 0xFFFFFF  # Blanco
    COLOR_CURSOR:    .word 0xFFA500  # Naranja
    COLOR_FONDO:     .word 0x000000  # Negro

    # --- DIRECCIONES DE MEMORIA (Hardware Mapeado) ---
    BASE_ATAQUE:  .word 0x10040000  
    BASE_DEFENSA: .word 0x10040400   
    MMIO_STATUS:     .word 0xffff0000 # Estado del teclado
    MMIO_DATA:       .word 0xffff0004 # Datos del teclado

    # --- VARIABLES DE ESTADO ---
    cursor_x:        .word 0          # Posición X (Columnas 0-15)
    cursor_y:        .word 16         # Posición Y (Filas 16-31)
    # --- MÁQUINA DE ESTADOS ---
    estado_juego:    .word 0          # 0=Menu, 1=Setup, 2=Jugando
    modo_juego:      .word 0          # 1=PvP, 2=PvCPU
    barcos_restantes:.word 4          # 4 barcos por colocar (Fase Setup)

    # Tamaños de la flota (5, 4 y 3 casillas)
    flota_tamanos:  .word 5, 4, 3  
    barco_actual:   .word 0        # Índice del barco que estamos poniendo (0 a 2)
    orientacion:    .word 0        # 0 = Horizontal (derecha), 1 = Vertical (abajo)
    max_barcos:     .word 3        # Cantidad total de barcos por jugador

.text
.globl main

main:
    # 1. Configuración Inicial del Sistema
    lw $t0, cursor_x
    lw $t1, cursor_y
    
    # 2. Pintar Interfaz de Menú de Arranque
    jal mostrar_menu_visual

bucle_juego:
    # 3. Ceder el control al módulo de entrada (controles)
    j polling_teclado

# --- ENLACE DE MÓDULOS EXTERNOS ---
# IMPORTANTE: Estos archivos deben estar en la misma carpeta que variables.asm
.include "controles.asm"
.include "motor_grafico.asm"
.include "reglas.asm"
.include "ia_cpu.asm"
.include "comodin.asm"
.include "menu.asm"
.include "setup_flota.asm"