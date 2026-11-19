.text
.globl procesar_seleccion_menu
.globl mostrar_menu_visual

mostrar_menu_visual:
    # Proteger registro de retorno por anidamiento de saltos
    subu $sp, $sp, 4
    sw $ra, 0($sp)
    
    # 1. Pintar Zona PvP (Arriba - Verde)
    lw $a0, BASE_ATAQUE
    li $a1, 256                 # 16x16 = 256 píxeles
    li $a2, 0x00FF00            # Verde
    jal fill_rect
    
    # 2. Pintar Zona PvCPU (Abajo - Morado)
    lw $a0, BASE_DEFENSA
    li $a1, 256
    li $a2, 0x800080            # Morado
    jal fill_rect
    
    lw $ra, 0($sp)
    addu $sp, $sp, 4
    jr $ra

procesar_seleccion_menu:
    j bucle_juego               # Ignora el "Enter" si aún está en el menú

# --- RUTINAS DE SELECCIÓN ---
seleccion_1:
    lw $t4, estado_juego
    bne $t4, 0, fin_mov         # Validar estado
    li $t3, 1
    sw $t3, modo_juego          # Fija PvP
    j arrancar_setup

seleccion_2:
    lw $t4, estado_juego
    bne $t4, 0, fin_mov
    li $t3, 2
    sw $t3, modo_juego          # Fija PvCPU
    j arrancar_setup

arrancar_setup:
    # Avanzar máquina de estados
    li $t3, 1
    sw $t3, estado_juego
    
    # Pintar AMBOS tableros de Azul Océano (512 píxeles en total)
    lw $a0, BASE_ATAQUE
    li $a1, 512
    lw $a2, COLOR_AGUA
    
    # Proteger en pila antes de saltar a fill_rect
    subu $sp, $sp, 4
    sw $ra, 0($sp)
    jal fill_rect
    lw $ra, 0($sp)
    addu $sp, $sp, 4
    
    # Actualizar primer fotograma del cursor
    lw $a2, COLOR_CURSOR
    jal dibujar_pixel
    j bucle_juego