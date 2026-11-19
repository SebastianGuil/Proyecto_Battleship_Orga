.text
.globl fijar_barco

fijar_barco:
    # 1. Leer tamaño del barco actual
    lw $t0, barco_actual
    sll $t1, $t0, 2             # Multiplicar índice por 4 para offset del arreglo
    la $t2, flota_tamanos
    add $t2, $t2, $t1
    lw $t3, 0($t2)              # $t3 = tamaño del barco (5, 4 o 3)
    
    # 2. Determinar el salto (offset)
    lw $t4, orientacion
    li $t5, 4                   # Asumimos horizontal (salto de 4 bytes)
    beq $t4, 0, iniciar_pintado
    li $t5, 64                  # Si es vertical, el salto es 64 bytes (una fila completa)
    
iniciar_pintado:
    # Aquí $a0 debe tener la dirección de memoria de tu cursor actual
    # y $a1 el color gris del barco
    move $t6, $a0               # Puntero temporal para pintar
    li $t7, 0                   # Contador del bucle
    
bucle_pintar_barco:
    beq $t7, $t3, fin_pintar_barco
    sw $a1, 0($t6)              # Pinta la casilla
    add $t6, $t6, $t5           # Avanza la memoria según el salto (4 o 64)
    addi $t7, $t7, 1
    j bucle_pintar_barco
    
fin_pintar_barco:
   lw $t0, barco_actual
    addi $t0, $t0, 1
    sw $t0, barco_actual
    
    lw $t1, max_barcos
    bne $t0, $t1, continuar_setup
    
    # Si ya pusimos los 3 barcos, pasamos a estado de juego (Estado 2)
    li $t2, 2
    sw $t2, estado_juego
    # Aquí deberías llamar a la rutina que borra la pantalla o prepara los disparos
    
continuar_setup:
    j bucle_juego

iniciar_batalla:
    # Avanzar al Estado 2 (Jugando)
    li $t3, 2
    sw $t3, estado_juego
    
    # Mover el cursor al tablero de ataque (Fila 0, Columna 0)
    li $t3, 0
    sw $t3, cursor_x
    sw $t3, cursor_y
    
    j bucle_juego