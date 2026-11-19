.text
# Declaramos la rutina principal como global
.globl polling_teclado

# --- POLLING DE TECLADO (MMIO) ---
polling_teclado:
    # Retardo (Sleep) de 60ms para evitar rebotes de lectura (Debouncing por software)
    li $v0, 32
    li $a0, 60
    syscall

    # Leer registro de estado del teclado
    lw $t0, MMIO_STATUS
    lw $t1, 0($t0)
    andi $t1, $t1, 1            # Máscara AND para evaluar el LSB (1 = tecla presionada)
    beq $t1, $zero, bucle_juego # Si es 0, volver al bucle principal en variables.asm

    # Si hay tecla, leer el registro de datos
    lw $t0, MMIO_DATA
    lw $t2, 0($t0)              # $t2 contiene el código ASCII de la tecla pulsada

    # Enrutamiento (Switch-case) para las teclas de control
    beq $t2, 119, mover_w       # 'w' -> ASCII 119 (Arriba)
    beq $t2, 115, mover_s       # 's' -> ASCII 115 (Abajo)
    beq $t2, 97,  mover_a       # 'a' -> ASCII 97  (Izquierda)
    beq $t2, 100, mover_d       # 'd' -> ASCII 100 (Derecha)
    beq $t2, 114, rotar_r       # 'r' -> ASCII 114 (Rotar)
    beq $t2, 10,  confirmar     # 'Enter' -> ASCII 10 (Fijar barco)
    beq $t2, 49, seleccion_1    # '1' -> ASCII 49
    beq $t2, 50, seleccion_2    # '2' -> ASCII 50
    beq $t2, 114, rotar_barco      # Si presiona 'r', cambiar orientación

    j bucle_juego               # Ignorar cualquier otra tecla no mapeada

# --- RUTINAS DE MOVIMIENTO Y LIMITACIÓN ESPACIAL ---
mover_w:
    jal borrar_cursor
    lw $t1, cursor_y
    ble $t1, 16, fin_mov        # Límite superior del tablero de defensa (Fila 16)
    subi $t1, $t1, 1
    sw $t1, cursor_y
    j fin_mov

mover_s:
    jal borrar_cursor
    lw $t1, cursor_y
    bge $t1, 31, fin_mov        # Límite inferior del tablero de defensa (Fila 31)
    addi $t1, $t1, 1
    sw $t1, cursor_y
    j fin_mov

mover_a:
    jal borrar_cursor
    lw $t0, cursor_x
    ble $t0, 0, fin_mov         # Límite izquierdo (Columna 0)
    subi $t0, $t0, 1
    sw $t0, cursor_x
    j fin_mov

mover_d:
    jal borrar_cursor
    lw $t0, cursor_x
    bge $t0, 15, fin_mov        # Límite derecho (Columna 15)
    addi $t0, $t0, 1
    sw $t0, cursor_x
    j fin_mov

rotar_r:
    # Operación XOR matemática para alternar estado de orientación (0 a 1, o 1 a 0)
    lw $t3, orientacion
    xori $t3, $t3, 1
    sw $t3, orientacion
    j bucle_juego

confirmar:
    lw $t4, estado_juego
    beq $t4, 0, procesar_seleccion_menu
    beq $t4, 1, fijar_barco
    beq $t4, 2, procesar_disparo
    j bucle_juego

fin_mov:
    # Actualizar la posición gráfica del cursor en la nueva coordenada
    lw $a2, COLOR_CURSOR
    jal dibujar_pixel
    j bucle_juego

rotar_barco:
    lw $t3, orientacion
    xori $t3, $t3, 1           # Hace un XOR con 1 (Cambia 0 a 1, o 1 a 0)
    sw $t3, orientacion
    j bucle_juego