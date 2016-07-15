.data

ask_filename: .asciiz "Please enter a filename:\n"

err_open_msg: .asciiz "Error while opening the file. Please check your filename.\n"
err_size_buff: .asciiz "Invalid size buffer. Check the values you entered.\n"
err_invalid_file: .asciiz "Invalid file extension\n"

filename: .space 105
nwfilename: .space 100
suffix: .asciiz ".lz77"


fdr: .word -1
fdw: .word -1

out_buff: .word 0	# Address output buffer
sizebuff: .word 0	# Size output buffer

in_buff: .space 60 	# input buffer, the size must be a multiple of 3
end_in_buff: .word 0 	# First address out of the in_buff

N: .word 0
F: .word 0 
R: .word 0

bytesR: .word 1







.text

# 
# Program starts here 
# 

main:

	# Get filename #

	la $a0 ask_filename		# ask filename #
	li $v0 4
	syscall

	la $a0 filename		# read filename #
	li $a1 100
	li $v0 8
	syscall

	li $t0 0

	rmv_nwl:				# take out newline at the end #
		lbu $t1, filename($t0)
		addiu $t0, $t0 1
		bnez $t1 rmv_nwl
		beq $t0 $a1 skip
		addiu $t0 $t0 -2
		sb $zero filename($t0)
	skip:


	# Open filename #

	la $a0 filename
	li $a1 0
	li $a2 0
	li $v0 13
	syscall
	sw $v0 fdr

	la $a0 err_open_msg
	li $a1 -1
	bltz $v0 end_with_msg	# Cannot open the file, terminates the program #


create_decompressedfile:

	# Make newname #
	la $a0 filename
	jal string_length

	la $a1 nwfilename
	move $a2 $v0
	jal copy_buff

	la $a0	nwfilename
	move $a1 $a2
	la $a2 suffix
	li $a3 5
	jal remove_suffix

	# Create newfile #

	la $a0 nwfilename
	li $a1 1
	li $a2 1
	li $v0 13
	syscall
	sw $v0 fdw

	# Get headers #

	lw $a0 fdr
	li $a2 4

	la $a1 R
	li $v0 14
	syscall

	la $a1 F
	li $v0 14
	syscall
	
	lw $t0 R
	lw $t1 F
	add $t2 $t0 $t1
	sw $t2 N

	# Bytes R #

	li $t1 0xff
	ble $t0 $t1 allocate_out_buff
	
	li $t1 0xffff
	ble $t0 $t1 R_halfWord

	li $t1 4
	sw $t1 bytesR
	j allocate_out_buff

R_halfWord:
	li $t1 2
	sw $t1 bytesR



	# Allocate output buffer #

allocate_out_buff:
	lw $a0	N
	li $a1 10
	mul $a0 $a0 $a1		#Buffer dimension = N x 10#
	li $v0 9
	syscall
	sw $v0 out_buff
	sw $a0 sizebuff
	
	# Initialize output buffer #

	lw $a0 out_buff
	lw $a1 R
	jal init_nul		# Initialize with R null bytes

	
################################################################################
# Main decompression 
# $a0: address source buffer
# $a1: EOF address (end of buffer if no EOF has been reached)
# #######################

main_decompression:
	lw $s6 F
	lw $s7 R

	lw $s0 out_buff	
	add $s0 $s0 $s7		# $s0: pointer to the output buffer
	la $s1 in_buff 		# $s1: pointer to the reading buffer

	lw $t0 out_buff
	lw $t1 sizebuff
	add $s3 $t0 $t1		# $s3: end of out_buff

	lw $t0 bytesR
	addi $t0 $t0 2
	li $t1 10
	mul $t0 $t0 $t1
	add $s5 $s1 $t0		# $s5: end of in_buff
	sw $s5 end_in_buff

	jal refresh_in_buff
	move $s4 $v0 		# $s4: EOF

	lw $s2 bytesR		# $s2: size of R (bytes)
	
	
	

loop_main_decompression:

	
	# Read triplet #
	move $a0 $s0	# out pointer
	
	li $t1 2
	li $t2 4
	beq $s2 $t1 R_half
	beq $s2 $t2 R_word

	lbu $a1 2($s1)	# offset
	j continue_load_triplet
R_half:
	lhu $a1 2($s1)	# offset
	j continue_load_triplet
R_word:
	ulw $a1 2($s1)	# offset


continue_load_triplet:

	lbu $a2 0($s1)	# length
	lbu $a3 1($s1)	# char
	jal decode_triplet
	
	add $s0 $s0 $a2
	addi $s0 $s0 1
	
	addi $t0 $s2 2
	add $s1 $s1 $t0

	# Test end of out_buff #

	add $t0 $s0 $s6	# $to = $s0 + F
	ble $t0 $s3 check_end_in_buff

	move $a0 $s0	
	jal refresh_out_buff
	move $s0 $v0
	

check_end_in_buff:
	bge $s4 $s5 EOBUFF_check # If no EOF in the buffer
EOF_check:
	bge $s1 $s4 end_decompression
	j loop_main_decompression

EOBUFF_check:
	blt $s1 $s5 continue_decompression	
	jal refresh_in_buff
	move $s4 $v0
	la $s1 in_buff

continue_decompression:
	j loop_main_decompression

end_decompression:
	move $a0 $s0	
	jal refresh_out_buff
	
	li $v0 16
	lw $a0 fdr
	syscall
	lw $a0 fdw
	syscall
	
	li $a0 0
	j exit
	
		
###############################################################################
# Decode triplet into buffer
# $a0: pointer to F buffer
# $a1: offset
# $a2: length
# $a3: char
###############################################################################

decode_triplet:
	addi $sp $sp -20
	sw $a3 16($sp)
	sw $a2 12($sp)
	sw $a1  8($sp)
	sw $a0  4($sp)
	sw $ra  0($sp)
	
	sub $a0 $a0 $a1	# a0: source buffer = a3 - offset
	lw $a1 4($sp)
	jal copy_buff
	
	add $a1 $a1 $a2
	sb $a3 0($a1)



	lw $a3 16($sp)
	lw $a2 12($sp)
	lw $a1  8($sp)
	lw $a0  4($sp)
	lw $ra  0($sp)
	add $sp $sp 20
	jr $ra
	
################################################################################
# Refresh in_buff
#####################################
refresh_in_buff:
	lw $a0 fdr
	la $a1 in_buff
	lw $a2 end_in_buff
	sub $a2 $a2 $a1
	j write_intobuff 

################################################################################
# Write the compressed data to the fdw and refresh the buffer returning the new pointer to F
# $a0: pointer to the F buffer
#######################################
# Return
# $v0: New pointer to F
#######################################

refresh_out_buff:
	add $sp $sp -8
	sw $a0 4($sp)
	sw $ra 0($sp)
	
	lw $t0 R
	lw $t1 out_buff
	move $t2 $a0

	lw $a0 fdw		# $a0: output file
	add $a1 $t0 $t1 	# $a1: out_buff + R
	sub $a2 $t2 $a1		# $a2: length
	li $v0 15
	syscall
	
	sub $a0 $t2 $t0		# $a0: pointer buff F - R
	move $a1 $t1		# $a1: out_buff
	move $a2 $t0		# $a2: R
	jal copy_buff

	add $v0 $a1 $a2		# $v0: out_buff + R
	
	lw $a0 4($sp)
	lw $ra 0($sp)
	add $sp $sp 8

	jr $ra

################################################################################
# Writes into fdw the N first bytes of out_buff
# $a0: N
#####

write_into_file:	
	move $t0 $a0
	move $t1 $a1
	move $t2 $a2

	lw $a0 fdw	
	la $a1 out_buff
	move $a2 $t0
	li $v0 15
	syscall

	move $a0 $t0
	move $a1 $t1
	move $a2 $t2
	jr $ra
	
	
################################################################################
# Initialize n bytes with spaces
# $a0 = address, $a1 = n_bytes

init_nul:
	move $t0 $a0
	move $t1 $a1
	li $t2 0x20
loop_initnul:
	blez $t1 end_initnul
	sb $t2 0($t0)
	add $t0 $t0 1	
	add $t1 $t1 -1
	j loop_initnul

end_initnul:
	jr $ra


#################################################################################
# Reads data into buffer from fd
# $a0 = fd 
# $a1 = addr buf
# $a2 = n_char
########
# Return
# $v0: addres end writing (represent EOF if end of file is reached, otherwise $a1+$a2)
##################

write_intobuff:
	li $v0 14
	syscall
	add $v0 $a1 $v0
	jr $ra
	

##################################################################################
# Copies a buffer of certain length in a new address
# $a0: buffer src
# $a1: buffer dest
# $a2: length

copy_buff:
	move $t0 $a0
	move $t1 $a1
	move $t2 $a2

loop_copy_buff:
	beqz $t2 exit_copy_buff
	lb $t3 0($t0)
	sb $t3 0($t1)
	addi $t0 $t0 1
	addi $t1 $t1 1
	addi $t2 $t2 -1
	j  loop_copy_buff

exit_copy_buff:
	jr $ra

##################################################################################
# Remove the suffix 
# $a0: string
# $a1: string length
# $a2: suffix
# $a3: suffix length
remove_suffix:
	move $t0 $a0 
	move $t1 $a1
	move $t2 $a2
	move $t3 $a3

	add $t0 $t0 $t1
	sub $t0 $t0 $t3	# Start suffix
	
	move $t4 $t0		# bkp start suffix

loop_remove_suffix:
	blez $t3 end_remove_suffix

	lbu $t5 0($t0)
	lbu $t6 0($t2)

	bne $t5 $t6 invalid_extension

	add $t0 $t0 1
	add $t2 $t2 1	
	add $t3 $t3 -1

	j loop_remove_suffix

end_remove_suffix:
	sb $zero 0($t4)
	jr $ra

	
invalid_extension:
	li $a1 1
	la $a0 err_invalid_file
	j end_with_msg
	
	


##################################################################################
# Calculate length of a string	
# $a0: string address

string_length:

	move $t0 $a0
	li $v0 0

loop_string_length:

	lb $t1 0($t0)
	addi $t0 $t0 1
	addi $v0 $v0 1
	bnez $t1 loop_string_length
	
	addi $v0 $v0 -1
	jr $ra
	

##################################################################################
# Prints a mdg and terminates the program #
# $a0: msg address
# $a1: exit value

end_with_msg:
	li $v0 4
	syscall

	move $a0 $a1
	j exit




##################################################################################
# Terminates the program with the a specific exit value #
# $a0: exit value {int}

exit:
li $v0 17
syscall 
	

