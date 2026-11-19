.text
.globl calcular_comodin

# --- MECÁNICA DE DAÑO EN ÁREA (1/7 PROB) ---
calcular_comodin:
    # Proteger el registro de retorno ($ra)
    subu $sp, $sp, 4
    sw $ra, 0($sp)

    # Tirar un dado virtual de 7 caras (0 a 6)
    li $v0, 42
    li $a0, 0
    li $a1, 7
    syscall
    
    # Si el número generado NO es 0, no hay comodín (retorna silenciosamente)
    bne $a0, $zero, fin_comodin
    
    # ¡BINGO! Cayó 0 (1 en 7 de probabilidad). Activando daño en área:
    # Recuperamos la posición actual del impacto
    lw $t0, cursor_x
    lw $t1, cursor_y
    
    # Pinta la casilla de la derecha (X+1)
    addi $t0, $t0, 1
    lw $a2, COLOR_IMPACTO
    jal dibujar_pixel
    
    # Pinta la casilla de abajo (Y+1)
    subi $t0, $t0, 1            # Restaurar X
    addi $t1, $t1, 1            # Bajar 1 fila
    lw $a2, COLOR_IMPACTO
    jal dibujar_pixel
    
fin_comodin:
    # Restaurar la pila y volver a las reglas
    lw $ra, 0($sp)
    addu $sp, $sp, 4
    jr $ra