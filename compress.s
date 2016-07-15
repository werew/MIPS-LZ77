.data

ask_filename: .asciiz "Please enter a filename:\n"
ask_N: .asciiz "Enter the length of the N buffer:\n"
ask_F: .asciiz "Enter the length of the F buffer (F < N and F < 256):\n"	

err_open_msg: .asciiz "Error while opening the file. Please check your filename."
err_size_buff: .asciiz "Invalid size buffer. Check the values you entered."

suffix: .asciiz ".lz77"

filename: .space 100
nwfilename: .space 105

fdr: .word -1
fdw: .word -1

in_buff: .word 0	# Address input buffer
size_in_buff: .word 0	# Size input buffer

out_buff: .space 60	# Output buffer, the size must be a multiple of 3
end_out_buff: .word 0 	# First address out of the out_buff

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

	la $a0 ask_filename	# ask filename #
	li $v0 4
	syscall

	la $a0 filename		# read filename #
	li $a1 100
	li $v0 8
	syscall

	li $t0 0

	rmv_nwl:					# take out newline at the end #
		lbu $t1, filename($t0)
		addiu $t0, $t0 1
		bnez $t1 rmv_nwl
		beq $t0 $a1 skip_rmvnwl
		addiu $t0 $t0 -2
		sb $zero filename($t0)
	skip_rmvnwl:






	# Get N and F values #

	la $a0 ask_N
	li $v0 4
	syscall

	li $v0 5
	syscall
	sw $v0 N

	la $a0 ask_F
	li $v0 4
	syscall

	li $v0 5
	syscall
	sw $v0 F

	lw $t0 N
	sub $v0 $t0 $v0
	sw $v0 R

	# Bytes R #

	li $t0 0xff
	ble $v0 $t0 test_values
	
	li $t0 0xffff
	ble $v0 $t0 R_halfWord

	li $t1 4
	sw $t1 bytesR
	j test_values

R_halfWord:
	li $t1 2
	sw $t1 bytesR


	# Test values R F N #

test_values:
	la $a0 err_size_buff
	li $a1 1
	lw $t1 F
	blez $t0 end_with_msg	# N > 0
	blez $v0 end_with_msg	# R > 0
	blez $t1 end_with_msg	# F > 0
	
	li $t2 255
	bgt $t1 $t2 end_with_msg # F <= 255
	
	 
	# Open filename #
	
	la $a0 filename
	li $a1 0
	li $a2 0
	li $v0 13
	syscall
	sw $v0 fdr

	la $a0 err_open_msg
	li $a1 -1
	bltz $v0 end_with_msg				# Cannot open the file, terminates the program #


create_compressedfile:

	# Make newname #

	la $a0 filename
	jal string_length

	la $a1 nwfilename
	move $a2 $v0
	jal copy_buff

	la $a0 suffix
	add $a1 $a1 $a2
	li $a2 6			# suffix length + null byte
	jal copy_buff


	# Create newfile #

	la $a0 nwfilename
	li $a1 1
	li $a2 1
	li $v0 13
	syscall
	sw $v0 fdw


	# Allocate input buffer #

	lw $a0	N
	li $a1 10
	mul $a0 $a0 $a1		 #Buffer dimension = N x 10#
	li $v0 9
	syscall
	sw $v0 in_buff
	sw $a0 size_in_buff

	
	# Calculate and store the end of the output buffer #
	lw $t1 bytesR
	addi $t1 $t1 2
	li $t2 10
	mul $t1 $t1 $t2

	la $t0 out_buff
	add $t0 $t0 $t1

	sw $t0 end_out_buff	


	############# Start compression ###############
	
	
################################################################################

main_compression:
	
	# Initialize in_buff #

	lw $a0 in_buff
	lw $a1 R
	jal init_nul		# Initialize with R spaces


	# Fill in_buff for the first time #
	
	lw $a0 fdr		# Input file
	lw $a1 in_buff
	lw $t0 R
	add $a1 $a1 $t0		# addr buffer = buff +R
	lw $a2 size_in_buff
	sub $a2 $a2 $t0		# bytes to read = size_in_buff - R 
	
	jal write_intobuff

	# Init registers #

	move $s4 $v0 		# $s4: eventual EOF
	la $s1 out_buff 	# $s1: pointer to the out_buffer
	lw $s3 in_buff
	lw $t0 size_in_buff
	lw $t1 in_buff
	add $s5 $t1 $t0 	# $s5: end of buff address		
	lw $s6 F
	lw $s7 R
	add $s0 $s3 $s7		# $s0: pointer to the source buffer (in_buff + R )


	# Write headers into file ( R F) #

	lw $a0 fdw
	li $a2 4
	
	la $a1 R
	li $v0 15
	syscall

	la $a1 F
	li $v0 15
	syscall

loop_main_compression:

	# Find longest match #
	move $a0 $s0			# $a0 = source buffer
	sub $a1 $a0 $s7			# $a1 = $a0 - R (search buffer)
	move $a2 $s4
	jal find_longest_match
	
	# Store triplet and increment $s0 #
	move $a0 $v0
	move $a1 $v1
	add $s0 $s0 $v1			# increment $s0 of the length
	lb $a2 0($s0)	
	move $a3 $s1
	jal store_triplet
	move $s1 $v0

	add $s0 $s0 1			# for the next loop $s0 += length_match + 1

	bge $s4 $s5 EOBUFF_check	# if no EOF is in the buff check for the end of the buff 

EOF_check:
	bge $s0 $s4 end_compression	
	j loop_main_compression	

EOBUFF_check:
	add $t0 $s0 $s6			# $t0: end of source buffer 
	ble $t0 $s5 continue_compression
	move $a0 $s0
	move $a1 $s5
	jal refresh_buff	
	move $s4 $v0			# update EOF pointer
	add $s0 $s3 $s7
continue_compression:
	j loop_main_compression

end_compression:
	la $t0 out_buff
	sub $a0 $s1 $t0
	jal write_into_file
	
	li $v0 16
	lw $a0 fdr
	syscall
	lw $a0 fdw
	syscall

	li $a0 0
	j exit

	



	
#################################################################################
# Refresh in_buff with new content of fdr copying the data not treated at the beginning
# $a0: pointer to the source buffer
# $a1: end of in_buff
#####################
# Return: see write_intobuff
####################


refresh_buff:
	add $sp $sp -16
	sw $a0 12($sp)
	sw $a1 8($sp)
	sw $a2 4($sp)
	sw $ra 0($sp)
	
	# copies not treated bytes at the beginning of in_buff #

	lw $t0 R
	sub $a0 $a0 $t0  # $a0: address beginning_data =  addr_source_buff - R
	sub $a2 $a1 $a0	 # $a2: length_data = end_of_buff - beginning_data	
	lw $a1 in_buff	 # $a1: address in_buff
	jal copy_buff

	# continue reading fdr #
	
	lw $a0 fdr	# $a0: file descriptor
	add $a1 $a1 $a2	# $a1: address new_data = address in_buff + length previous copy
	lw $t0 size_in_buff
	sub $a2 $t0 $a2	# $a2: n_bytes = buffsize - length previous copy
	jal write_intobuff


	lw $a0 12($sp)
	lw $a1 8($sp)
	lw $a2 4($sp)
	lw $ra 0($sp)
	add $sp $sp 16
	
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
	
	
	
#################################################################################
# Store a triplet in memory
# $a0: offset
# $a1: length
# $a2: char
# $a3: memory address
## Return
# $v0: space stored in bytes
######

store_triplet:
	add $sp $sp -12
	sw $a0 8($sp)	
	sw $a3 4($sp)
	sw $ra 0($sp)

	lw $t0 end_out_buff
	blt $a3 $t0 write_triplet_buf

	la $t1 out_buff	
	sub $a0 $t0 $t1
	jal write_into_file

	lw $a0 8($sp)
	la $a3 out_buff

write_triplet_buf:
	lw $t0 bytesR
	li $t1 2
	li $t2 4
	
	beq $t0 $t1 R_half	
	beq $t0 $t2 R_word

	sb $a0 2($a3)
	j continue_write_triplet
R_half:
	ush $a0 2($a3)
	j continue_write_triplet
R_word:
	usw $a0 2($a3)

continue_write_triplet:

	sb $a1 0($a3)
	sb $a2 1($a3)

	lw $t1 bytesR
	li $t0 2
	add $t0 $t0 $t1
	add $v0 $a3 $t0


	lw $a3 4($sp)
	lw $ra 0($sp)
	add $sp $sp 12	
	jr $ra 

	
##################################################################################
# Find the longest match from a source buffer of length F inside a search buffer starting from a given address and finishing
# as the source buffer starts (address source buffer > address search buffer), the max length of the match is F (global value).
# The match cannot reach the given EOF pointer.
# $a0: address source buffer	description: [$a0]..........[$a0+F]
# $a1: address search buffer	description: [$a1]..........[last element][$a0]
# $a2: EOF to consider
####### 
#  Return
# $v0: positive offset match from $a0, 0 if not found
# $v1: length match, 0 if not found
###########################

find_longest_match:
	add $sp  $sp -32
	sw $a0 28($sp)
	sw $a1 24($sp)
	sw $a2 20($sp)
	sw $s3 16($sp)	
	sw $s2 12($sp)
	sw $s1 8($sp)
	sw $s0 4($sp)
	sw $ra 0($sp)
	
	lb $s0 0($a0)			# s0 = first char
	move $s2 $a0		# s2: match address, $a0 if no match is found
	move $s3 $zero		# s3: match length (0)
	
loop_find_longest_match:
	bge $a1 $a0 end_find_longest_match	# end of search buffer
	lb $s1	0($a1)					# s1 = char from search buffer
	bne $s1 $s0 continue_searching		# no match

	# Match found #
	jal match_length				# calculate match length
	ble $v0 $s3 continue_searching		# if length <= previous match, skip it
	move $s2 $a1				# $s2 = address
	move $s3 $v0				# $s3 = length
	
continue_searching:
	addi $a1 $a1 1					# increment address
	j loop_find_longest_match

end_find_longest_match:
	sub $v0 $a0 $s2
	move $v1 $s3

	lw $a0 28($sp)
	lw $a1 24($sp)
	lw $a2 20($sp)
	lw $s3 16($sp)	
	lw $s2 12($sp)
	lw $s1 8($sp)
	lw $s0 4($sp)
	lw $ra 0($sp)
	add $sp $sp 32

	jr $ra
	
################################################################################
# Calculate the length of a match (max length F)
# $a0: address source buffer
# $a1: address search buffer
# $a2: EOF 
######################
# Return:
# $v0: match length

match_length:
	move $t0 $a0
	move $t1 $a1
	lw $t4 F
	move $v0 $zero

loop_match_length:
	bge $v0 $t4 exit_match_length	# exit: length >= F
	bge $t0 $a2 exit_match_length_EOF	# exit: EOF
	lb $t2 0($t0)
	lb $t3 0($t1)
	bne $t2 $t3 exit_match_length	# exit: unmatched chars
	addi $v0 $v0 1
	addi $t0 $t0 1
	addi $t1 $t1 1
	j loop_match_length

exit_match_length_EOF:
	add $v0 $v0 -1
exit_match_length:
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
	








