.text
.globl turno_cpu

# --- INTELIGENCIA ARTIFICIAL BÁSICA ---
turno_cpu:
    # Generar coordenada X aleatoria (0 a 15)
    li $v0, 42                  # Syscall 42: Random int con límite superior
    li $a0, 0                   # ID del generador (0 = default)
    li $a1, 16                  # Límite superior (no inclusivo, devuelve 0-15)
    syscall
    move $t0, $a0               # Guardar X aleatorio en $t0
    
    # Generar coordenada Y aleatoria (16 a 31 para apuntar a la DEFENSA)
    li $v0, 42
    li $a1, 16
    syscall
    addi $a0, $a0, 16           # Sumar 16 para que caiga en el tablero inferior
    move $t1, $a0               # Guardar Y aleatorio en $t1
    
    # Calcular dirección física en BASE_DEFENSA
    sll $t2, $t1, 4             
    add $t2, $t2, $t0           
    sll $t2, $t2, 2             
    lw $t3, BASE_DEFENSA        
    add $t3, $t3, $t2           
    
    # Pinta el disparo de la CPU (Rojo si acierta, Blanco si falla)
    lw $t4, 0($t3)              
    lw $t5, COLOR_BARCO
    beq $t4, $t5, cpu_acierta
    
    lw $a2, COLOR_FALLO
    sw $a2, 0($t3)
    j fin_turno_cpu

cpu_acierta:
    lw $a2, COLOR_IMPACTO
    sw $a2, 0($t3)

fin_turno_cpu:
    # Retorna el control al jugador
    jr $ra