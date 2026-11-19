.text
.globl procesar_disparo

# --- LÓGICA CENTRAL DE REGLAS ---
procesar_disparo:
    # 1. Calcular dirección en memoria del disparo actual
    lw $t0, cursor_x
    lw $t1, cursor_y
    
    # Reutilizamos el algoritmo de motor_grafico.asm
    sll $t2, $t1, 4             # Y * 16
    add $t2, $t2, $t0           # (Y * 16) + X
    sll $t2, $t2, 2             # Offset en bytes
    
    lw $t3, BASE_ATAQUE         # Apuntamos al tablero rival
    add $t3, $t3, $t2           
    
    # 2. Leer qué hay en esa casilla
    lw $t4, 0($t3)              # Cargar color/estado actual de la casilla
    
    # 3. Evaluar colisión (Hit/Miss)
    lw $t5, COLOR_BARCO
    beq $t4, $t5, impacto_critico
    
    # Si no es barco, asumimos agua/fallo
    lw $a2, COLOR_FALLO
    sw $a2, 0($t3)              # Pintar de blanco
    
    # Aquí iría la lógica del contador de fallos (3 max por turno)
    # saltar_a_turno_cpu si fallos == 3
    j fin_procesar

impacto_critico:
    lw $a2, COLOR_IMPACTO
    sw $a2, 0($t3)              # Pintar de rojo
    
    # 4. Llamar al módulo de comodín para ver si hay daño en área
    jal calcular_comodin
    
fin_procesar:
    j bucle_juego               # Retornar al polling del teclado