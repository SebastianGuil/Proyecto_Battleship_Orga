# ==============================================================================
# PROYECTO: BATTLESHIP (BATALLA NAVAL) - ARQUITECTURA MIPS R2000
# SIMULADOR: MARS 4.5
# ARCHIVO: controles.asm (Controlador MMIO de Alto Rendimiento - Cero Deadlocks)
# ==============================================================================
#
# DESCRIPCIÓN TÉCNICA:
# Manejo de eventos de teclado mediante Memory-Mapped I/O (MMIO):
#   - Receiver Control: 0xffff0000 (Bit 0 = 1 si hay tecla pendiente)
#   - Receiver Data:    0xffff0004 (Código ASCII de la tecla)
#
# GARANTÍAS ESTRICTAS CONTRA DEADLOCKS DE JAVA SWING EN MARS 4.5:
# 1. CERO SYSCALL 32: Se eliminó totalmente syscall 32 (Thread.sleep en Java).
#    El debounce es un lazo simple de conteo en registros (addi 5000), 100% nativo.
# 2. CERO SYSCALL 4 AL MOVER/ROTAR: No se imprimen mensajes en consola durante WASD
#    o R para evitar saturar el Event Dispatch Thread (EDT) de Swing.
# 3. ACTUALIZACIÓN DELTA ESTRICTA: Solo se redibujan las celdas del barco (2..5 px).
#    Si el cursor ya está en un borde, se aborta inmediatamente sin tocar la VRAM.
# 4. CLAMPING PREVENTIVO Y AUTO-AJUSTE EN ROTACIÓN.
# ==============================================================================

.text
.globl polling_teclado
.globl mover_w
.globl mover_s
.globl mover_a
.globl mover_d
.globl rotar_r
.globl rotar_barco
.globl confirmar
.globl fin_mov

# ==============================================================================
# SUBRUTINA: polling_teclado
# ------------------------------------------------------------------------------
# Propósito: Sondeo ultra ligero de MMIO. Si no hay tecla o está en el borde,
#            retorna instantáneamente a bucle_juego.
# ==============================================================================
polling_teclado:
    # 1. Retardo anti-rebote puramente aritmético (Cero syscall 32, sin deadlock)
    li   $t0, 5000
pt_debounce:
    addi $t0, $t0, -1
    bgtz $t0, pt_debounce

    # 2. Comprobar Receiver Control (0xffff0000, bit 0)
    lw   $t0, MMIO_STATUS
    lw   $t1, 0($t0)
    andi $t1, $t1, 1
    beq  $t1, $zero, pt_salir    # Si no hay tecla lista, continuar el ciclo

    # 3. Leer Receiver Data (0xffff0004) UNA SOLA VEZ (limpia el bit 0 de hardware)
    lw   $t0, MMIO_DATA
    lw   $t2, 0($t0)

    # 4. Normalizar mayúsculas a minúsculas ('A'-'Z' -> 'a'-'z')
    blt  $t2, 65, pt_enrutar
    bgt  $t2, 90, pt_enrutar
    addi $t2, $t2, 32

pt_enrutar:
    beq  $t2, 119, mover_w      # 'w' -> Arriba
    beq  $t2, 115, mover_s      # 's' -> Abajo
    beq  $t2, 97,  mover_a      # 'a' -> Izquierda
    beq  $t2, 100, mover_d      # 'd' -> Derecha
    beq  $t2, 114, rotar_r      # 'r' -> Rotar barco
    beq  $t2, 10,  confirmar    # Enter
    beq  $t2, 101, confirmar    # 'e'
    beq  $t2, 49,  seleccion_1  # '1'
    beq  $t2, 50,  seleccion_2  # '2'

pt_salir:
    j    bucle_juego

# ==============================================================================
# MOVIMIENTO CON CLAMPING PREVENTIVO (CERO REDIBUJADOS EN BORDES)
# ==============================================================================

mover_w: # --- ARRIBA ---
    lw   $t4, estado_juego
    beqz $t4, pt_salir          # En menú ignorar movimiento
    beq  $t4, 1, mw_setup

    # Modo Batalla (Estado 2): Tablero de Ataque (Y: 0..15)
    lw   $t1, cursor_y
    blez $t1, pt_salir          # Si ya está en Y=0, retorno inmediato sin repintar
    jal  borrar_cursor
    lw   $t1, cursor_y
    subi $t1, $t1, 1
    sw   $t1, cursor_y
    jal  dibujar_cursor
    j    bucle_juego

mw_setup:
    # Modo Setup (Estado 1): Tope superior es fila 16 (Defensa)
    lw   $t1, cursor_y
    ble  $t1, 16, pt_salir      # Si ya está en fila 16, retorno inmediato
    jal  borrar_cursor
    lw   $t1, cursor_y
    subi $t1, $t1, 1
    sw   $t1, cursor_y
    jal  dibujar_cursor
    j    bucle_juego


mover_s: # --- ABAJO ---
    lw   $t4, estado_juego
    beqz $t4, pt_salir
    beq  $t4, 1, ms_setup

    # Modo Batalla (Estado 2): Tope inferior es fila 15
    lw   $t1, cursor_y
    bge  $t1, 15, pt_salir
    jal  borrar_cursor
    lw   $t1, cursor_y
    addi $t1, $t1, 1
    sw   $t1, cursor_y
    jal  dibujar_cursor
    j    bucle_juego

ms_setup:
    # Modo Setup (Estado 1): Límite depende de orientación y tamaño
    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $t5, 0($t2)            # Longitud del barco
    lw   $t3, orientacion       # 0 = H, 1 = V

    li   $t6, 31                # Max Y horizontal = 31
    beqz $t3, ms_eval_y
    li   $t6, 32
    sub  $t6, $t6, $t5          # Max Y vertical = 32 - longitud

ms_eval_y:
    lw   $t1, cursor_y
    bge  $t1, $t6, pt_salir     # Si ya está en el límite inferior, retorno inmediato
    jal  borrar_cursor
    lw   $t1, cursor_y
    addi $t1, $t1, 1
    sw   $t1, cursor_y
    jal  dibujar_cursor
    j    bucle_juego


mover_a: # --- IZQUIERDA ---
    lw   $t4, estado_juego
    beqz $t4, pt_salir

    lw   $t0, cursor_x
    blez $t0, pt_salir          # Tope izquierdo absoluto: Columna 0
    jal  borrar_cursor
    lw   $t0, cursor_x
    subi $t0, $t0, 1
    sw   $t0, cursor_x
    jal  dibujar_cursor
    j    bucle_juego


mover_d: # --- DERECHA ---
    lw   $t4, estado_juego
    beqz $t4, pt_salir
    beq  $t4, 1, md_setup

    # Modo Batalla (Estado 2): Tope derecho es columna 15
    lw   $t0, cursor_x
    bge  $t0, 15, pt_salir
    jal  borrar_cursor
    lw   $t0, cursor_x
    addi $t0, $t0, 1
    sw   $t0, cursor_x
    jal  dibujar_cursor
    j    bucle_juego

md_setup:
    # Modo Setup (Estado 1): Si es Horizontal, X máximo = 16 - tamaño
    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $t5, 0($t2)            # Longitud del barco
    lw   $t3, orientacion       # 0 = H, 1 = V

    li   $t6, 15                # Max X vertical = 15
    bnez $t3, md_eval_x
    li   $t6, 16
    sub  $t6, $t6, $t5          # Max X horizontal = 16 - longitud

md_eval_x:
    lw   $t0, cursor_x
    bge  $t0, $t6, pt_salir     # Si ya está en el límite derecho, retorno inmediato
    jal  borrar_cursor
    lw   $t0, cursor_x
    addi $t0, $t0, 1
    sw   $t0, cursor_x
    jal  dibujar_cursor
    j    bucle_juego


# ==============================================================================
# SUBRUTINA: rotar_r / rotar_barco (Silencioso - Cero syscall 4 - Auto-Clamping)
# ==============================================================================
rotar_barco:
rotar_r:
    lw   $t4, estado_juego
    bne  $t4, 1, pt_salir       # Solo permitido en fase de Setup

    # 1. Borrar silueta actual
    jal  borrar_preview_setup

    # 2. Alternar orientación (0 = Horizontal <-> 1 = Vertical)
    lw   $t3, orientacion
    xori $t3, $t3, 1
    sw   $t3, orientacion

    # 3. Leer tamaño del barco actual para auto-clamping
    lw   $t0, barco_actual
    sll  $t1, $t0, 2
    la   $t2, flota_tamanos
    add  $t2, $t2, $t1
    lw   $t5, 0($t2)            # Longitud del barco

    # 4. Ajustar coordenadas hacia adentro si la rotación se sale del tablero
    beqz $t3, rot_clamp_h

    # --- Ahora es VERTICAL ---
    li   $t6, 32
    sub  $t6, $t6, $t5          # max_y = 32 - longitud
    lw   $t7, cursor_y
    ble  $t7, $t6, rot_redibujar
    sw   $t6, cursor_y          # Clamping vertical automático
    j    rot_redibujar

rot_clamp_h:
    # --- Ahora es HORIZONTAL ---
    li   $t6, 16
    sub  $t6, $t6, $t5          # max_x = 16 - longitud
    lw   $t7, cursor_x
    ble  $t7, $t6, rot_redibujar
    sw   $t6, cursor_x          # Clamping horizontal automático

rot_redibujar:
    # 5. Dibujar preview actualizado (Sin imprimir por consola para evitar lag)
    jal  dibujar_cursor
    j    bucle_juego


# ==============================================================================
# SUBRUTINA: confirmar
# ==============================================================================
confirmar:
    lw   $t4, estado_juego
    beq  $t4, 0, procesar_seleccion_menu
    beq  $t4, 1, fijar_barco
    beq  $t4, 2, procesar_disparo
    j    bucle_juego

# ==============================================================================
# SUBRUTINA: fin_mov
# ==============================================================================
fin_mov:
    jal  dibujar_cursor
    j    bucle_juego
