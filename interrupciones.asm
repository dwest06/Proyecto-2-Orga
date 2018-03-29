# SPIM S20 MIPS simulator.
# The default exception handler for spim.
#
# Copyright (C) 1990-2004 James Larus, larus@cs.wisc.edu.
# ALL RIGHTS RESERVED.
#
# SPIM is distributed under the following conditions:
#
# You may make copies of SPIM for your own use and modify those copies.
#
# All copies of SPIM must retain my name and copyright notice.
#
# You may not sell SPIM or distributed SPIM in conjunction with a commerical
# product or service without the expressed written consent of James Larus.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE.
#

########################################################################
# NOTE: Comments added and expanded by Neal Wagner, April 4, 1999
#       and by Matthew Patitz, October 21, 2008
#   ("Text" below refers to Patterson and Hennessy, _Computer
#    Organization and Design_, Morgan Kaufmann.)
#
# INTERRUPT HANDLING IN MIPS:
# Coprocessor 0 has extra registers useful in handling exceptions
# There are four useful coprocessor 0 registers:
#-------------------------------------------------------------------|
#  REG NAME | NUMBER |   USAGE                                      |
#-------------------------------------------------------------------|
#  BadVAddr |   8    | Memory addr at which addr exception occurred |
#  Status   |  12    | Interrupt mask and enable bits               |
#  Cause    |  13    | Exception type and pending interrupt bits    |
#  EPC      |  14    | Address of instruction that caused exception |
#-----------|--------|----------------------------------------------|
# Details:
#   Status register: has an interrupt mask with a bit for each of
#      five interrupt levels.  If a bit is one, interrupts at that
#      level are allowed.  If a bit is zero, interrupts at that level
#      are disabled.  The low order 6 bits of the Status register
#      implement a three-level stack for the "kernel/user" and
#      "interrupt enable" bits.  The "kernel/user" bit is 0 if the
#      program was running in the kernel when the interrupt occurred
#      and 1 if it was in user mode.  If the "interrupt enable" bit is 1,
#      interrupts are allowed.  If it is 0, they are disabled.  At an
#      interrupt, these six bits are shifted left by two bits.
#   Cause register: The value in bits 2-5 of the Cause register
#      describes the particular type of exception.  The error messages
#      below describe these values.  Thus a 7 in bits 2-5 corresponds
#      to message __e7_ below, or a "bad address in data/stack read".
#
# There are special machine instructions for accessing these
# coprocessor 0 registers:
#      mfc0  Rdest, CPsrc: "move from coprocessor 0" moves data 
#         from the special coprocessor 0 register CPsrc into the
#         general purpose register Rdest.
#      mtc0  Rsrc, CPdest: "move to coprocessor 0" moves data 
#         from the general purpose register Rsrc into the special
#         coprocessor 0 register CPdest.
# (There are also coprocessor load and store instructions.)
#
# ACTIONS BY THE TRAP HANDLER CODE BELOW:
#  Branch to address 0x80000180 and execute handler there:
#  1. Save $a0 and $v0 in s0 and s1 and $at in $k1.
#  2. Move Cause into register $k0.
#  3. Do action such as print an error message.
#  4. Increment EPC value so offending instruction is skipped after
#     return from exception.
#  5. Restore $a0, $v0, and $at.
#  6. Clear the Cause register and re-enable interrupts in the Status
#     register.
#  6. Execute "eret" instruction to return execution to the instruction
#     at EPC.
#
########################################################################

# Define the exception handling code.  This must go first!
	.kdata
__m1_:	.asciiz "  Exception "
__m2_:	.asciiz " occurred and ignored\n"
__e0_:	.asciiz "  [Interrupt] "
__e1_:	.asciiz	"  [TLB]"
__e2_:	.asciiz	"  [TLB]"
__e3_:	.asciiz	"  [TLB]"
__e4_:	.asciiz	"  [Address error in inst/data fetch] "
__e5_:	.asciiz	"  [Address error in store] "
__e6_:	.asciiz	"  [Bad instruction address] "
__e7_:	.asciiz	"  [Bad data address] "
__e8_:	.asciiz	"  [Error in syscall] "
__e9_:	.asciiz	"  [Breakpoint] "
__e10_:	.asciiz	"  [Reserved instruction] "
__e11_:	.asciiz	""
__e12_:	.asciiz	"  [Arithmetic overflow] "
__e13_:	.asciiz	"  [Trap] "
__e14_:	.asciiz	""
__e15_:	.asciiz	"  [Floating point] "
__e16_:	.asciiz	""
__e17_:	.asciiz	""
__e18_:	.asciiz	"  [Coproc 2]"
__e19_:	.asciiz	""
__e20_:	.asciiz	""
__e21_:	.asciiz	""
__e22_:	.asciiz	"  [MDMX]"
__e23_:	.asciiz	"  [Watch]"
__e24_:	.asciiz	"  [Machine check]"
__e25_:	.asciiz	""
__e26_:	.asciiz	""
__e27_:	.asciiz	""
__e28_:	.asciiz	""
__e29_:	.asciiz	""
__e30_:	.asciiz	"  [Cache]"
__e31_:	.asciiz	""
__excp:	.word __e0_, __e1_, __e2_, __e3_, __e4_, __e5_, __e6_, __e7_, __e8_, __e9_
	.word __e10_, __e11_, __e12_, __e13_, __e14_, __e15_, __e16_, __e17_, __e18_,
	.word __e19_, __e20_, __e21_, __e22_, __e23_, __e24_, __e25_, __e26_, __e27_,
	.word __e28_, __e29_, __e30_, __e31_
#memoria para guardar registros usados
v0: 	.word 0
a0: 	.word 0
s0:	.word 0
s1:	.word 0


#####################################################
# This is the exception handler code that the processor runs when
# an exception occurs. It only prints some information about the
# exception, but can serve as a model of how to write a handler.
#
# Because we are running in the kernel, we can use $k0/$k1 without
# saving their old values.

# This is the exception vector address for MIPS32:
#.ktext 0x80000180
.ktext 0x80000180

#####################################################
# Save $at, $v0, and $a0
#
.set noat
	move $k1 $at            # Save $at
.set at

	sw $v0 v0               # Not re-entrant and we can't trust $sp
	sw $a0 a0               # But we need to use these registers
	sw $s0 s0
	sw $s1 s1

#####################################################
#	Extract information about de exception and verify if was an interruption
#
	mfc0 $k0 $13            # Get Cause register
	srl $a0 $k0 2           # Extract ExcCode Field
	andi $a0 $a0 0xf
	
	beqz $a0 verify_pc

#####################################################
# Print information about exception
#
	li $v0 4                # syscall 4 (print_str)
	la $a0 __m1_
	syscall

	li $v0 1                # syscall 1 (print_int)
	mfc0 $k0 $13            # Get Cause register
	srl $a0 $k0 2           # Extract ExcCode Field
	andi $a0 $a0 0xf
	syscall

	li $v0 4                # syscall 4 (print_str)
	andi $a0 $k0 0x3c
	lw $a0 __excp($a0)      # $a0 has the index into
	                        # the __excp array (exception
	                        # number * 4)
	nop
	
	syscall

#####################################################
# Bad PC exception requires special checks
#
verify_pc:
	bne $k0 0x18 ok_pc
	nop

	mfc0 $a0 $14            # EPC
	andi $a0 $a0 0x3        # Is EPC word-aligned?
	beq $a0 0 ok_pc
	nop

	li $v0 10               # Exit on really bad PC
	syscall

#####################################################
#  PC is alright to continue
#
ok_pc:

	li $v0 4                # syscall 4 (print_str)
	la $a0 __m2_            # "occurred and ignored" message
	#syscall

	srl $a0 $k0 2           # Extract ExcCode Field
	andi $a0 $a0 0xf
	bne $a0 0 ret           # 0 means exception was an interrupt
	nop

#####################################################
# Interrupt-specific code goes here!
# Don't skip instruction at EPC since it has not executed.
#  -> not implemented
#

interup:

	#deshabilitar las interrupciones
	mfc0 $k0, $12 
	subi $k0, $k0, 1		#apagamos el bit n° 0
	mtc0 $k0, $12
	
	lw $a0, 0xFFFF0004
	li $v0, 11
	syscall
	
	move $s7 $a0
	
	beq $a0 81 fin 		#cuando se aprieta Q o q
	beq $a0 113 fin
	
	beq $a0 65 move_left 	#Cuando se aprieta A o a
	beq $a0 97 move_left
	
	beq $a0 68 move_right	#Cuando se aprieta D o d
	beq $a0 100 move_right
	
	beq $a0 85 increment	#cuando se aprieta U o u
	beq $a0 117 increment

	beq $a0 76 decrement	#cuando se aprieta L o l
	beq $a0 108 decrement
	
	j restore
move_left:
	lw $s0, posicion_barra
	subi $s0 $s0 4
	
	#verificar si esta chocando con la pared izquierda
	#
	# beq s0 (posicion de la pared) restore
	#
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
	
	#actualizar la posicion_barra
	sw $s0 posicion_barra
	
	j restore
	
move_right:
	lw $s0 posicion_barra
	addi $s0 $s0 4
	#verificamos si esta chocando con la pared derecha
	#
	# beq $s0 (posicion de la pared) restore
	#
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
	
	#actualizamos la posicion_barra
	lw $s0 posicion_barra
	add $s0 $s0 4
	sw $s0 posicion_barra
	
	j restore
	
increment:
	lw $s0 T
	lw $s1 INCREMENTO
	add $s0 $s0 $s1
	sw $s0 T
	
	j restore
	
decrement:
	lw $s0 T
	lw $s1 INCREMENTO
	sub $s0 $s0 $s1
	#preguntar si la rapidez es negtiva
	sw $s0 T
	
	j restore
	

#####################################################
# Return from (non-interrupt) exception. Skip offending
# instruction at EPC to avoid infinite loop.
#
ret:

	mfc0 $k0 $14            # Get EPC register value
	addiu $k0 $k0 4         # Skip faulting instruction by skipping
	                        # forward by one instruction
                          # (Need to handle delayed branch case here)
	mtc0 $k0 $14            # Reset the EPC register
	
#####################################################
# Restore registers and reset procesor state
#
restore:
	lw $v0 v0               # Restore $v0 and $a0
	lw $a0 a0
	lw $s0 s0
	lw $s1 s1

	.set noat
	move $at $k1            # Restore $at
	.set at

	mtc0 $0 $13             # Clear Cause register

	mfc0 $k0 $12            # Set Status register
	ori  $k0 0x1            # Interrupts enabled
	mtc0 $k0 $12


#####################################################
# Return from exception on MIPS32
#
	eret

# End of exception handling
#####################################################


#####################################################
#####################################################
# Standard startup code.  Invoke the routine "main" with arguments:
#	main(argc, argv, envp)
#
#	.text
#	.globl __start
#__start:
#	lw $a0 0($sp)		# argc
#	addiu $a1 $sp 4		# argv
#	addiu $a2 $a1 4		# envp
#	sll $v0 $a0 2
#	addu $a2 $a2 $v0
#	jal main
#	nop

#	li $v0 10
#	syscall			# syscall 10 (exit)

#	.globl __eoth
#__eoth:

.data
bitmap: .space 4096	#se reserva espacio para el display

posicion_barra: .word 268505012	#aqui se guarda el bit mas a la izquierda de la barra

#colores de la barra
color_barra:.word 0x0054cc 0x003c91 0x002456 0x003c91 0x0054cc

#color de la pelota
color_pelota: .word 0xffb31c

#color del fondo de la patalla
color_fondo: .word 0x111111

#colores de los ladrillos
color_ladrillo: .word 0x00ff00 0x00c100 0x008200

#Posicion actual en X y en Y de la bola
pos_x: .word 0
pos_y: .word 0

#inicial: indica si el juego no ha comenzado, con cualquier interrupcion del teclado se empieza el juego
incio: .word 0

#variabl global que indica la velocidad del juego
T: .word 10
#incremento
INCREMENTO: .word 100

p: .asciiz "algo fino para imprimir"
q: .asciiz "temine en fin"
pas: .asciiz "pase por el trap"

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
		loop:
			beq $s0 832 finloop
			sw $s5 0($s1)
			sw $s5 4($s1)
			sw $s5 8($s1)
			sw $s5 12($s1)
			
			addi $s1 $s1 16
			addi $s0 $s0 4
			
			j loop
		finloop:
			#dibujamos la pelota
			addi $s1 $s1 60
			sw $s4 0($s1)
			addi $s1 $s1 68
			
			#cargamos en s2 el color de la barra
			la $s2 color_barra
			
			#dibujamos la barra
			addi $s1 $s1 52
			
			li $v0 1
			move $a0 $s1
			syscall
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


main:
	beq $s7, 32 , excep
	beq $s7, 113 , excep
	
	
	j main


excep:
	li $v0 4
	la $a0 pas
	teqi $s7, 32
	
fin:
	
	li $v0, 10
	syscall	
