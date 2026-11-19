.text
# Declaramos las subrutinas como globales por buenas prácticas de enlazado
.globl borrar_cursor
.globl dibujar_pixel

# --- SUBRUTINAS DE RENDERIZADO (BITMAP DISPLAY) ---
borrar_cursor:
    # Como esta subrutina llama a otra (dibujar_pixel), necesitamos proteger 
    # el registro de retorno ($ra) en el Stack para no perder la ruta de vuelta.
    subu $sp, $sp, 4
    sw $ra, 0($sp)
    
    lw $t0, cursor_x
    lw $t1, cursor_y
    lw $a2, COLOR_AGUA        # Cargamos el color negro para "apagar" el pixel
    jal dibujar_pixel
    
    # Recuperamos el registro de retorno de la pila (Pop)
    lw $ra, 0($sp)
    addu $sp, $sp, 4
    jr $ra

dibujar_pixel:
    # Algoritmo de desplazamiento lineal para la VRAM
    # Tablero de 16x16. Fórmula: Offset = ((Y * 16) + X) * 4 bytes
    # Entradas esperadas: $t0 = X, $t1 = Y, $a2 = Color a pintar
    
    sll $t2, $t1, 4             # $t2 = Y * 16 (Shift Left de 4 bits equivale a multiplicar por 16)
    add $t2, $t2, $t0           # $t2 = (Y * 16) + X
    sll $t2, $t2, 2             # $t2 = Offset en bytes (Shift Left de 2 equivale a multiplicar por 4)
    
    lw $t3, BASE_ATAQUE         # Cargar dirección base absoluta de la pantalla
    add $t3, $t3, $t2           # Sumar el offset calculado a la dirección base
    sw $a2, 0($t3)              # Inyectar el código hexadecimal del color en la VRAM
    
    jr $ra                      # Retornar a la instrucción llamadora
    
    .globl fill_rect

# --- PRIMITIVAS GRÁFICAS ---
# Entradas: $a0 = Dirección Base, $a1 = Cantidad de píxeles, $a2 = Color
fill_rect:
    li $t0, 0                   # Inicializar contador de píxeles en 0
bucle_fill:
    beq $t0, $a1, fin_fill      # Si el contador llega al límite, terminar
    sll $t1, $t0, 2             # Multiplicar contador por 4 (bytes por palabra)
    add $t2, $a0, $t1           # Calcular dirección física exacta
    sw $a2, 0($t2)              # Inyectar el color en la VRAM
    addi $t0, $t0, 1            # Incrementar contador
    j bucle_fill
fin_fill:
    jr $ra                      # Retornar al módulo que lo llamó