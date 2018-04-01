#######################################################
#
#	IMPLEMENTACION DE EL JUEGO BREAKOUT EN MIPS
#	Para jugar:
# 		- Abrir el Bitmap Display y Keyboard and display 
#			Tools -> Bitmap Display o Keyboard and Display
#		- Bitmap Display: Colocar la pantalla en 32 x 32 (por ejemplo: 16, 8, 512,256) y presionar Connect to Mips
#		- Keyboard: presionar Connet to Mips. Se escirbe en el cuadro de abajo del tool
#
#	Detalles:
#		- 
#
#####################################################
.data
bitmap: .space 4096	#se reserva espacio para el display

posicion_barra: .word 268505012	#aqui se guarda el bit mas a la izquierda de la barra

#colores de la barra
color_barra:.word 0x0054cc 0x003c91 0x002456 0x003c90 0x0054cb

#color de la pelota
color_pelota: .word 0xffb31c

#color del fondo de la patalla
#color_fondo: .word 0x111111
color_fondo: .word 0x0

#colores de los ladrillos
color_ladrillo: .word 0x00ff00 0x00c100 0x008200

#Posicion actual en X y en Y de la bola
pos_x: .word 15
pos_y: .word 30
#direccion actual en X y Y de la bola
dir_x: .word 0
dir_y: .word -1
#posicion en x de la barra. util para delimitar el alcance de la barra
pos_x_barra: .word 13

#inicial: indica si el juego no ha comenzado, con cualquier interrupcion del teclado se empieza el juego
incio: .word 0

#Cantida de ladrillos, al principio son 128 = 32 casillas X 4 filas
cantidad_ladrillos: .word 128

#variabl global que indica la velocidad del juego
T: .word 10
#incremento por defecto sera 100
INCREMENTO: .word 100

#Timer 
timer: .word 0

p: .asciiz "posicion: "

pause: .word 1
####################################
#
.text
#
####################################

inicializacion:
	#habilitamos las interrupciones
	lw $s1, 0xffff0000
	ori $s1, 0x2
	sw $s1, 0xffff0000
	
	mfc0 $s1 $12
	ori $s1, 0x101
	mtc0 $s1, $12
	
	#cargamos los colores de los ladrillos
	la $s1 bitmap
	move $s0 $zero
	la $s2 color_ladrillo
	lw $s3 4($s2)
	lw $s4 8($s2)
	lw $s2 0($s2)
	
	#dibujamos el tablero
	tablero:	
		sw $s2 0($s1)
		sw $s3 4($s1)
		beq $s0 126 demas
		
		sw $s4 8($s1)
		
		addi $s1 $s1 12
		addi $s0 $s0 3
		
		j tablero

	demas: 
		addi $s1 $s1 8
		move $s0 $zero
		lw $s5 color_fondo
		
		#dibujamos una cuadricula mas clara
		#loop:
		#	beq $s0 832 finloop
		#	sw $s5 0($s1)
		#	sw $s5 4($s1)
		#	sw $s5 8($s1)
		#	sw $s5 12($s1)
		#	
		#	addi $s1 $s1 16
			#Usada solo para probar
			addi $s1 $s1 3328
		#	addi $s0 $s0 4
		#	j loop
		finloop:
			#dibujamos la pelota
			addi $s1 $s1 60
			sw $s4 0($s1)
			addi $s1 $s1 68
			
			#cargamos en s2 el color de la barra
			la $s2 color_barra
			
			#dibujamos la barra
			addi $s1 $s1 52
			
			sw $s1 posicion_barra
			
			lw $s3 0($s2)
			sw $s3 0($s1)
			
			lw $s3 4($s2)
			sw $s3 4($s1)
			
			lw $s3 8($s2)
			sw $s3 8($s1)
			
			lw $s3 12($s2)
			sw $s3 12($s1)
			
			lw $s3 16($s2)
			sw $s3 16($s1)
			
			
#########################
#
#	Timer 
#
###

timer_func:
	#habilitamos el timer
	mfc0 $t0 $12
	ori $t0 0x8000
	mtc0 $t0 $12
	
	# Guardo en $11 los ciclos que debe hacer el timer antes de mandar una interrupcion
	mfc0 $t0 $9
	lw $t1 T
	add $t0 $t1 $t0
	mtc0 $t0 $11

########################
#
#	Randomiza la primera direccion de X y Y
#

#Hacemos syscall del tiempo para que de un numero distinto siempre
li $v0 30 	#se gaurda en $a0 el tiempo
syscall

move $a1 $a0

li $v0 40 	#colocar la semilla 
syscall

li $v0 42
li $a0 1 
li $a1 2
syscall		# se genera un numero random entre 0 y 2
subi $a0 $a0 1 	#movemos el resultado entre -1 y 1

sw $a0 dir_x

generar_dir_y:
	
	li $v0 42
	li $a0 1 
	li $a1 2
	syscall		# se genera un numero random entre 0 y 2
	
	beqz $a0 generar_dir_y #volvemos a generar el numero aleatoriao
	mul $a0 $a0 -1
	sw $a0 dir_y
	
############################################
#	Sonido de inicio
######################

li $v0 33
li $a0 57
li $a1 100
li $a2 8
li $a3 100
syscall

li $a1 200
syscall


#################################################
#
#	Main, aqui el ciclo principal del juego
#	Consta de 4 funciones de actualizacion de la posicion de la bola
#	Registros globaes de acceso rapido:
#		$s7 = direccion de memoria del bitmap
#		$t8 = valor de la interrupcion
###################

la $s7 bitmap

main:	
	#saltar si hay un cambio generado por el timer
	lw $t0 timer
######################################
#Pausa cuando se toca la barra
#pausa: 
#	lw $t1 pause
#	beqz $t1 pausa
#########################################
	beqz $t0 sig
	
	jal borrar_bola
	
	sig:
	
	beq $t8 81 fin 		#cuando se aprieta Q o q
	beq $t8 113 fin
	
	beq $t8 65 move_left 	#Cuando se aprieta A o a
	beq $t8 97 move_left
	
	beq $t8 68 move_right	#Cuando se aprieta D o d
	beq $t8 100 move_right
	
	beq $t8 85 increment	#cuando se aprieta U o u
	beq $t8 117 increment

	beq $t8 76 decrement	#cuando se aprieta L o l
	beq $t8 108 decrement
	
	j main
#############################################

	#####################################################
	#	Borra la bola del tablero
	#	Registros usados: 
	#		$t0 = pos_x
	#		$t1 = pos_y
	#		$t2 = posicion en la matriz
	#		$t3 = color_fondo
	borrar_bola:
		lw $t0 pos_x
		lw $t1 pos_y
		lw $t3 color_fondo
		#multiplicamos la $t1 x 128
		
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7
		
		#asignamos el color de fondo a la pos de $t2
		sw $t3 0($t2)
		
	#####################################################
	#	Calcula la nueva posicion que debe tomar la bola segun la direccion 
	#	Registros usados: 
	#		$t0 = pos_x o pos_y
	#		$t1 = dir_x o dir_y
	calcular_nueva_pos:
		#actualizamos la pos en x
		lw $t0 pos_x
		lw $t1 dir_x
		add $t0 $t0 $t1
		sw $t0 pos_x
		
		#actualizamos la pos en y
		lw $t0 pos_y
		lw $t1 dir_y
		add $t0 $t0 $t1
		sw $t0 pos_y
		
	#####################################################
	#	Dibuja la bola en la nueva posicion 
	#	Registros usados: 
	#		$t0 = pos_x
	#		$t1 = pos_y
	#		$t2 = posicion en la matriz
	#		$t3 = color_pelota
	dibujar_bola:
		lw $t0 pos_x
		lw $t1 pos_y
		lw $t3 color_pelota
		#multiplicamos la $t1 x 128
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7
		
		#Colocamos el color de la bola en la posicion correspondiente
		sw $t3 0($t2)
	
	#####################################################
	#	Verifica si en algun sentido hay algun choque.
	#	Hay 4 tipos de choques:
	#		- Arriba: puede ser con un ladrillo o techo
	#		- Derecha: puede ser con un ladrillo o techo
	#		- Izquierda: puede ser con un ladrillo o techo
	#		- Abajo: Con la barra o ladrillo
	#
	#	Registros usados: 
	#		$t0 = pos_x
	#		$t1 = pos_y
	#		$t2 = posicion en la matriz
	#		$t3 = color_pelota	
	verificar_choque:
		###################
		#	Verificaciones de ubicacion
		#
		lw $t4 color_fondo
		la $t5 color_ladrillo
		
		##############################
		#	verificacion de arriba
		##########
		lw $t0 pos_x
		lw $t1 pos_y
		
		#restamos 1 a la pos_y para verificar el bloque de arriba|
		subi $t1 $t1 1
		
		#verificamos si es techo
		bltz $t1 a_tech
		
		#multiplicamos la $t1 x 128
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7
		lw $t3 0($t2)
		#arriba
		beq $t3 $t4 fin_arriba
		
		arriba:
			#agarramos cada color posible de ladrillo y verificamos que la posicion
			lw $t6 0($t5)
			beq $t3 $t6 a_lad
			lw $t6 4($t5)
			beq $t3 $t6 a_lad
			lw $t6 8($t5)
			beq $t3 $t6 a_lad

			j a_tech
			#Eliminamos el ladrillo
			a_lad:
				sw $t4 0($t2)	
			
			#techo
			a_tech:
			#cambiamos la direccion de la pelota
			lw $t1 dir_y
			mul $t1 $t1 -1
			sw $t1 dir_y
		
		#sonido 
		li $v0 31
		li $a0 57
		li $a1 100
		li $a2 8
		li $a3 100
		syscall
		fin_arriba:
		
		##################################
		#	verificacion de derecha
		###
		lw $t0 pos_x
		lw $t1 pos_y
		#sumamos 1 a la pos_x para verificar el bloque de la derecha
		addi $t0 $t0 1
		
		#verificamos si no es pared
		bgt $t0 31 d_pared
		
		#multiplicamos la $t1 x 128
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7 
		lw $t3 0($t2)
		#derecha
		beq $t3 $t4 fin_derecha
		
		derecha:
			lw $t6 0($t5)
			beq $t3 $t6 d_lad
			lw $t6 4($t5)
			beq $t3 $t6 d_lad
			lw $t6 8($t5)
			beq $t3 $t6 d_lad
			
			j d_pared
			#ladrillo
			d_lad:
				#Eliminamos el ladrillo
				sw $t4 0($t2)
			
			d_pared:
				#cambiamos la direccion de la pelota
				lw $t0 dir_x
				mul $t0 $t0 -1
				sw $t0 dir_x
		#sonido 
		li $v0 31
		li $a0 57
		li $a1 100
		li $a2 8
		li $a3 100
		syscall
			
		fin_derecha:
		
		#############################
		#	verificacion de abajo
		###
		lw $t0 pos_x
		lw $t1 pos_y
		#sumamos 1 a la pos_y para verificar el bloque de abajo
		addi $t1 $t1 1
		
		#verificamos que se perdio
		bgt $t1 31 fin
		
		#multiplicamos la $t1 x 128
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7
		
		#en t3 se guarda la posicion bajo la bola a verificar
		lw $t3 0($t2)
		#abajo
		beq $t3 $t4 fin_abajo
		
		abajo:
			#verifico primero si es un ladrillo y lo elimino
			lw $t6 0($t5)
			beq $t3 $t6 ab_lad
			lw $t6 4($t5)
			beq $t3 $t6 ab_lad
			lw $t6 8($t5)
			beq $t3 $t6 ab_lad
			
			#ahora verifico si es la barra
			#cambio de $t5 de ladrillo a barra
			la $t5 color_barra
			
			lw $t6 0($t5)
			beq $t3 $t6 b_1
			lw $t6 4($t5)
			beq $t3 $t6 b_2
			lw $t6 8($t5)
			beq $t3 $t6 b_3
			lw $t6 12($t5)
			beq $t3 $t6 b_4
			lw $t6 16($t5)
			beq $t3 $t6 b_5
			
			
			
			#ladrillo
			ab_lad:
			
				#Eliminamos el ladrillo
				sw $t4 0($t2)
				
				#cambiamos la direccion de la pelota
				lw $t1 dir_y
				mul $t1 $t1 -1
				sw $t1 dir_y
				
			#sonido 
			li $v0 31
			li $a0 57
			li $a1 100
			li $a2 8
			li $a3 100
			syscall
				
				j fin_abajo
			b_1:
				li $t0 -1
				li $t1 -1
				sw $t0 dir_x
				sw $t1 dir_y
				
				#sonido 
				li $v0 31
				li $a0 69
				li $a1 100
				li $a2 8
				li $a3 100
				syscall
				
				j fin_abajo			
			b_2:
				li $t0 -1
				li $t1 -2
				sw $t0 dir_x
				sw $t1 dir_y
				
				#sonido 
				li $v0 31
				li $a0 69
				li $a1 100
				li $a2 8
				li $a3 100
				syscall
				
				j fin_abajo			
			
			b_3:
				li $t0 0
				li $t1 -2
				sw $t0 dir_x
				sw $t1 dir_y
				
				#sonido 
				li $v0 31
				li $a0 69
				li $a1 100
				li $a2 8
				li $a3 100
				syscall
				
				j fin_abajo			
			
			b_4:
				li $t0 1
				li $t1 -2
				sw $t0 dir_x
				sw $t1 dir_y
				
				#sonido 
				li $v0 31
				li $a0 69
				li $a1 100
				li $a2 8
				li $a3 100
				syscall
				
				j fin_abajo			
			
			b_5:
				li $t0 1
				li $t1 -1
				sw $t0 dir_x
				sw $t1 dir_y
				
				#sonido 
				li $v0 31
				li $a0 69
				li $a1 100
				li $a2 8
				li $a3 100
				syscall
				
				j fin_abajo			
			
		fin_abajo:
		
		#################################
		#	verificacion de izquierda
		###
		lw $t0 pos_x
		lw $t1 pos_y
		#restamos 1 a la pos_x para verificar el bloque de la izquierda
		subi $t0 $t0 1
		
		#verificamos que no se pared
		bltz $t0 i_pared
		
		#multiplicamos la $t1 x 128
		sll $t1 $t1 7
		sll $t0 $t0 2
		add $t2 $t1 $t0
		add $t2 $t2 $s7 
		lw $t3 0($t2)
		#derecha
		beq $t3 $t4 fin_izquierda
		
		izquierda:
			lw $t6 0($t5)
			beq $t3 $t6 i_lad
			lw $t6 4($t5)
			beq $t3 $t6 i_lad
			lw $t6 8($t5)
			beq $t3 $t6 i_lad
			
			j i_pared
			i_lad:
				#Eliminamos el ladrillo
				sw $t4 0($t2)
			
			i_pared:
				#cambiamos la direccion de la pelota
				lw $t0 dir_x
				mul $t0 $t0 -1
				sw $t0 dir_x
		#sonido 
		li $v0 31
		li $a0 57
		li $a1 100
		li $a2 8
		li $a3 100
		syscall
		
		fin_izquierda:
		
	# Guardo en $11 los ciclos que debe hacer el timer antes de mandar una interrupcion
	mfc0 $t0 $9
	lw $t1 T
	add $t0 $t1 $t0
	mtc0 $t0 $11
	
	lb $s0 timer
	not $s0, $s0
	sb $s0 timer

	jr $ra
	
	
###############################################
#
#	Funciones que se ejecutan cuando ocurre una interrupcion
#	- Barra: Mueve la barra cuando se aprienta a o d
#		move left: mueve a la izquierda
#		mve rigth: mueve a la derecha
#	- 
#
#
#######################################

move_left:
	lw $s0, posicion_barra
	subi $s0 $s0 4
	
	move $t8 $zero #pongo en t8 0 para que no se vuelva a meter
	
	##########################
	#	PRUEBA
	#########################
	li $v0 1
	move $a0 $t8
	syscall
	li $v0 11
	li $a0 10
	syscall
	#########################
	
	#verificar si esta chocando con la pared izquierda
	lw $s1 pos_x_barra
	subi $s1 $s1 1
	
	
	##########################
	#	PRUEBA
	#########################
	li $v0 4
	la $a0 p
	syscall
	li $v0 1
	move $a0 $s1
	syscall
	li $v0 11
	li $a0 10
	syscall
	##########################
	
	ble $s1 -1 main
	
	li $a0 65
	syscall
	
	#si no, encender el siguiente bit mas a la izquierda y apagar el mas hacia la derecha
	la $s1 color_barra
	
	lw $s2 0($s1)
	sw $s2 0($s0)
	
	lw $s2 4($s1)
	sw $s2 4($s0)
	
	lw $s2 8($s1)
	sw $s2 8($s0)
	
	lw $s2 12($s1)
	sw $s2 12($s0)
	
	lw $s2 16($s1)
	sw $s2 16($s0)
	
	li $s1 0x000000 	#el pedazo a eliminar le asignamos de color del fondo
	sw $s1 20($s0)
	
	#Actualizamos la posicion de la barra en x
	lw $s1 pos_x_barra
	subi $s1 $s1 1
	sw $s1 pos_x_barra
	
	#actualizar la posicion_barra
	sw $s0 posicion_barra
	
	
	j main
	
move_right:
	lw $s0 posicion_barra
	addi $s0 $s0 4

	move $t8 $zero  #pongo en t8 0 para qe no se vuelva a repetir
	
	##########################
	#	PRUEBA
	#########################
	li $v0 1
	move $a0 $t8
	syscall
	li $v0 11
	li $a0 10
	syscall
	###########################

	#verificamos si esta chocando con la pared derecha
	lw $s1 pos_x_barra
	addi $s1 $s1 5
	##########################
	#	PRUEBA
	#########################
	li $v0 4
	la $a0 p
	syscall
	li $v0 1
	move $a0 $s1
	syscall
	li $v0 11
	li $a0 10
	syscall
	##########################
	bgt $s1 31 main
	
	li $a0 65
	syscall
	
	#si no, encendemos el siguiente bit mas a la derecha y apagar el mas hacia la izquierda
	la $s1 color_barra
	lw $s2 0($s1)
	sw $s2 0($s0)
	
	lw $s2 4($s1)
	sw $s2 4($s0)
	
	lw $s2 8($s1)
	sw $s2 8($s0)
	
	lw $s2 12($s1)
	sw $s2 12($s0)
	
	lw $s2 16($s1)
	sw $s2 16($s0)
	
	li $s1 0x000000	#el pedazo a eliminar le asignamos de color del fondo
	sw $s1 -4($s0)
	
	#Actualizamos la posicion de la barra en x
	lw $s1 pos_x_barra
	addi $s1 $s1 1
	sw $s1 pos_x_barra
	
	#actualizamos la posicion_barra
	lw $s0 posicion_barra
	add $s0 $s0 4
	sw $s0 posicion_barra
	

	
	j main
	
increment:
	lw $s0 T
	lw $s1 INCREMENTO
	add $s0 $s0 $s1
	sw $s0 T
	
	move $t8 $zero
	
	j main
	
decrement:
	lw $s0 T
	lw $s1 INCREMENTO
	sub $s0 $s0 $s1
	#preguntar si la rapidez es negtiva
	sw $s0 T
	
	move $t8 $zero
	
	j main
	

fin:	
	#dibujar G O
	#sonido 
	li $v0 33
	li $a0 60
	li $a1 100
	li $a2 8
	li $a3 100
	syscall	
	
	li $a0 55
	syscall
	
	li $a0 48
	li $a1 300
	syscall
	
	li $v0, 10
	syscall	
	
#############################################
#	Incluimos el manejador de excepciones
#
.include "manejador_interrupciones.asm"
###################################
