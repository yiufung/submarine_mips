#Name: ZHANG, Yaofeng
#ID: 10587680
#Email: yzhangak@ust.hk
#Lab Section: LA2
#Bonus -- left-movement key:     right-movement key:


#=====================#
# THE SUBMARINES GAME #
#=====================#

#---------- DATA SEGMENT ----------
	.data

ship:	.word 320 90 1 4	# 4 words for 4 properties of the ship: (in this order) top-left corner's x-coordinate, top-left corner's y-coordinate, image index, speed  
shipSize: .word 160 60		# ship image's width and height

submarines:	.word -1:500	# 5 words for each submarine: (in this order) top-left corner's x-coordinate, top-left corner's y-coordinate, image index, speed, Hit point  
submarineSize: .word 80 40	# submarine image's width and height

dolphins:	.word -1:500	# 5 words for each dolphin: (in this order) top-left corner's x-coordinate, top-left corner's y-coordinate, image index, speed, Hit point  
dolphinSize: .word 60 40	# dolphin image's width and height

bombs:	.word -1:30	# 5 words for each bomb: (in this order) top-left corner's x-coordinate, top-left corner's y-coordinate, image index, speed, status  
bombSize: .word 30 30	# bomb image's width and height


msg0:	.asciiz "Enter the number of dolphins (max. limit of 5) you want? "
msg1:	.asciiz "Invalid size!\n"
msg2:	.asciiz "Enter the seed for random number generator? "
msg3:	.asciiz "You have won!"
newline: .asciiz "\n"

title: .asciiz "The Submarines game"
# game image array constructed from a string of semicolon-delimited image files
# array index		0		1	2	3	4		5		6		7		8	9		10			11		12		13
images: .asciiz "background.png;shipR.png;shipL.png;subR.png;subL.png;subDamagedR.png;subDamagedL.png;subDestroyed.png;dolphinR.png;dolphinL.png;dolphinDestroyed.png;simpleBomb.png;remoteBombD.png;remoteBombA.png"


# The following registers are used throughout the program for the specified purposes,
# so using any of them for another purpose must preserve the value of that register first: 

# s0 -- total number of dolphins in a game level
# s1 -- total number of submarines in a game level
# s2 -- current game score
# s3 -- current game level
# s4 -- current number of available simple bombs in a game level
# s5 -- current number of available remote bombs in a game level
# s6 -- starting time of a game iteration

#---------- TEXT SEGMENT ----------
	.text
	


main:
#-------(Start main)------------------------------------------------

	jal setting				# the game setting

	ori $s3, $zero, 1			# level = 1
	ori $s2, $zero, 0			# score = 0

	
	jal createGame				# create the game 

	#----- initialize game objects and information, and create game screen ---
	jal createGameObjects
	jal setGameStateOutput

	jal initgame				# initalize the first game level

	jal updateGameObjects
	jal createGameScreen
	#-------------------------------------------------------------------------
	
main1:
	jal getCurrentTime			# Step 1 of the game loop 
	ori $s6, $v0, 0    			# v1 keeps the iteration starting time

	jal removeDestroyedObjects		# Step 2 of the game loop
	jal processInput			# Step 3 of the game loop
	jal checkBombHits			# Step 4 of the game loop
	jal updateDamagedImages			# Step 5 of the game loop

	jal isLevelUp				# Step 6 of the game loop
	bne $v0, $zero, main2			# the current level is won

	jal moveShipSubmarinesDolphins		# Step 7 of the game loop	
	jal moveBombs				# Step 8 of the game loop

updateScreen:
	jal updateGameObjects			# Step 9 of the game loop
	jal redrawScreen

	ori $a0, $s6, 0				# Step 10 of the game loop
	li $a1, 30
	jal pauseExecution
	j main1
	
main2:	
	li $t0, 10				# the last level is 10
	beq $s3, $t0, main3 			# the last level and hence the whole game is won 
	addi $s3, $s3, 1			# increment level
	li $t0, 5
	div $s3, $t0
	mfhi $t0
	beq $t0, $zero, double_dolphin_num	# level no. is divisible by 5
	addi $s0, $s0, 3			# dolphin_num = dolphin_num + 3
	j main_continue
double_dolphin_num:
	sll $s0, $s0, 1				# dolphin_num = dolphin_num * 2
main_continue:
	addi $s1, $s0, 3			# submarine_num = dolphin_num + 3

	#----- re-initialize game objects and information for next level --------
	jal createGameObjects
	jal setGameStateOutput

	jal initgame				# initialize the next game level
	#-------------------------------------------------------------------------

	j updateScreen

main3: 
	jal setGameoverOutput			# GAME OVER!
	jal redrawScreen   
	j end_main

#-------(End main)--------------------------------------------------
end_main:

# Terminate the program
#----------------------------------------------------------------------
ori $v0, $zero, 10
syscall

# Function: Setting up the game
setting:
#===================================================================

	addi $sp, $sp, -4
	sw $ra, 0($sp)

setting1:
	ori $t0, $zero, 5			# Max number of dolphins
	
	la $a0, msg0				# Enter the number of dolphins you want?
	ori $v0, $zero, 4
	syscall
	
	ori $v0, $zero, 5			# cin >> dolphin_num
	syscall
	or $s0, $v0, $zero

	slt $t4, $t0, $s0
	bne $t4, $zero, setting3
	slti $t4, $s0, 1
	bne $t4, $zero, setting3
	addi $s1, $s0, 3			# submarine_num = dolphin_num + 3
	j setting2

setting3:
	la $a0, msg1
	ori $v0, $zero, 4			# Invalid size
	syscall
	j setting1

setting2:
	la $a0, newline
	ori $v0, $zero, 4
	syscall

	la $a0, msg2				# Enter the seed for random number generator?
	ori $v0, $zero, 4
	syscall
	
	ori $v0, $zero, 5			# cin >> seed
	syscall

	ori $a0, $v0, 0				# set the seed of the random number generator
	jal setRandomSeed    

	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

#---------------------------------------------------------------------------------------------------------------------
# Function: initalize to a new level
# Generate random location and speed for submarines and dolphins
# Set the image index of submarines and dolphins according to their own moving direction
# Set the Hit point of the submarines and dolphins
# Set the available number of the bombs
# Initialize the image index and speed of the bombs

initgame: 			
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

# Operations here. 

# init submarines.
        la $s7, submarines # s7 = addr of submarines. 
        ori $t0, $zero, 0 # t0 = 0. loop index i. 
        lw $s1, 8($sp) # num of submarines

init_submarine_loop:
        slt $t1, $t0, $s1
        beq $t1, $zero, end_init_submarine_loop # t1 = 1 <=> i< numOfSubmarines. 

        # init x-coord s1
        ori $a0, $zero, 720 # 720 = 800 - width of submarine
        jal randnum
        ori $s1, $v0, 0

        # init y-coord s2
        ori $a0, $zero, 250 # 250 = the range of the y-coordinate. 
        jal randnum
        addi $s2, $v0, 250

        # init speed s4
        ori $a0, $zero, 6 # init speed 
        jal randomSignChange
        ori $s4, $a0, 0

        # init image_index s3 depending on speed, s4.
        slt $t1, $s4, $zero 
        bne $t1, $zero, set_sub_neg_image # t1 = 1, s4 < 0, submarine's speed is negative. 
        ori $s3, $zero, 3 # s4 > 0, set s3 to moving right. 
        j quit_set_sub_image
  set_sub_neg_image:
        ori $s3, $zero, 4 # s4 < 0, set s3 to moving left. 
  quit_set_sub_image:
        
        # init hit-point s5
        ori $s5, $zero, 10 # s5 = init hit point

        # write s1-s5 to array 
        sw $s1, 0($s7)
        sw $s2, 4($s7)
        sw $s3, 8($s7)
        sw $s4, 12($s7)
        sw $s5, 16($s7)
        
        addi $s7, $s7, 20 # move up 20 bytes for next iteration. 
        addi $t0, $t0, 1 # i+=1
        j init_submarine_loop

end_init_submarine_loop:
# end of init submarines.

# init dolphins. 
        la $s7, dolphins # s7 = addr of dolphins.
        ori $t0, $zero, 0 # t0 = 0. loop index j.
        lw $s0, 4($sp) # num of dolphins

init_dolphin_loop:
        slt $t1, $t0, $s0
        beq $t1, $zero, end_init_dolphin_loop # t1 = 1 <=> j<numOfDolphins

        # init x-coord s1
        ori $a0, $zero, 740 # 740 = 800 - width of dolphin
        jal randnum
        ori $s1, $v0, 0

        # init y-coord s2
        ori $a0, $zero, 250
        jal randnum
        addi $s2, $v0, 250

        # init speed s4
        ori $a0, $zero, 5
        jal randomSignChange
        ori $s4, $a0, 0

        # init image_index s3 depends on speed, s4
        slt $t1, $s4, $zero
        bne $t1, $zero, set_dol_neg_image # t1 = 1, s4 < 0, dolphin's speed is negative.
        ori $s3, $zero, 8 # s4 > 0, dolphin moving right
        j quit_set_dol_image
  set_dol_neg_image:
        ori $s3, $zero, 9 # s4 < 0, dolphin moving left 
  quit_set_dol_image:

        # init hit-point s5
        ori $s5, $zero, 20 # s5 = init hit point

        # write s1-s5 to array
        sw $s1, 0($s7)
        sw $s2, 4($s7)
        sw $s3, 8($s7)
        sw $s4, 12($s7)
        sw $s5, 16($s7)

        addi $s7, $s7, 20 # move up 20 bytes for next iteration.
        addi $t0, $t0, 1 # j+=1
        j init_dolphin_loop

end_init_dolphin_loop:
# end of init dolphins.

# set bomb number.
        lw $s4, 20($sp)
        ori $s4, $zero, 5 # num of simple bombs = 5
        sw $s4, 20($sp) # write it into memory.
        
        lw $s5, 24($sp)
        ori $s5, $zero, 1 # num of remote bombs = 1
        sw $s5, 24($sp) # write it into memory. 
# end of set bomb number. 

# init bombs.
# init simple bombs
        la $s7, bombs # s7 = addr of dolphins
        ori $t0, $zero, 0 # t0 = 0. loop index k. 
        lw $s4, 20($sp) # s4 = num of simple bombs. 

init_simple_bomb_loop:
        slt $t1, $t0, $s4
        beq $t1, $zero, end_init_simple_bomb_loop

        # init image index
        ori $s3, $zero, -1 # shouldn't be shown at first. 
        # init speed
        ori $t4, $zero, 4 # s4 is used to save num, so use t4 to initialize speed

        # write into array
        sw $s3, 8($s7)
        sw $t4, 12($s7) 

        addi $s7, $s7, 20 # update addr
        addi $t0, $t0, 1 # k+=1
        j init_simple_bomb_loop

end_init_simple_bomb_loop:

# init the remote bomb.
        ori $s3, $zero, -1 # shouldn't be shown at first.  
        ori $t4, $zero, 4
        sw $s3, 8($s7) # s7 has already been updated in the loop. 
        sw $t4, 12($s7)

# end of init bombs.


# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra

#---------------------------------------------------------------------------------------------------------------------
# Function: remove the destroyed submarines and dolphins from the screen

removeDestroyedObjects:				
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

# Operations here. 

# rm destroyed submarines.
        la $s7, submarines # s7 = addr of submarines. 
        ori $t0, $zero, 0 # t0 = 0. loop index i. 
        lw $s1, 8($sp) # num of submarines

rm_destroyed_submarine_loop:
        slt $t1, $t0, $s1
        beq $t1, $zero, end_rm_destroyed_submarine_loop # t1 = 1 <=> i< numOfSubmarines. 

        lw $s5, 16($s7)
        beq $s5, $zero, erase_submarine # hp=0, erase the submarine.
        j quit_check_submarine_hp # nothing happens
  erase_submarine:
        ori $s3, $zero, -1 # set index to -1. 
        sw $s3, 8($s7) # update image index.
  quit_check_submarine_hp:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration. 
        addi $t0, $t0, 1 # i+=1
        j rm_destroyed_submarine_loop 

end_rm_destroyed_submarine_loop:
# end of rm destroyed submarines.

# rm destroyed dolphins. 
        la $s7, dolphins # s7 = addr of dolphins.
        ori $t0, $zero, 0 # t0 = 0. loop index j.
        lw $s0, 4($sp) # num of dolphins

rm_destroyed_dolphin_loop:
        slt $t1, $t0, $s0
        beq $t1, $zero, end_rm_destroyed_dolphin_loop # t1 = 1 <=> j<numOfDolphins

        lw $s5, 16($s7)
        beq $s5, $zero, erase_dolphin # hp=0, erase dolphin
        j quit_check_dolphin_hp
  erase_dolphin:
        ori $s3, $zero, -1
        sw $s3, 8($s7)
  quit_check_dolphin_hp:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration.
        addi $t0, $t0, 1 # j+=1
        j rm_destroyed_dolphin_loop

end_rm_destroyed_dolphin_loop:
# end of rm destroyed dolphins.

# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra

#---------------------------------------------------------------------------------------------------------------------
# Function: check any hits between an Activated bomb and a submarine or dolphin,
# and then handle the hits:
# change the hit submarine or dolphin's Hit point and change the score accordingly
# remove the bomb and add it back to the available ones

checkBombHits:				
#===================================================================

############################
# Please add your code here#
############################


	



	
#----------------------------------------------------------------------------------------------------------------------
# Function: read and handle the user's input

processInput:
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)
	
# Operations here. 

# q - 113
# e - 101 
# 1 - 49
# 2 - 50

        jal getInput
        beq $v0, $zero, end_process_input # the user hasn't pressed anything. 

        ori $t0, $zero, 113
        beq $v0, $t0, process_q
        ori $t0, $zero, 101
        beq $v0, $t0, process_e
        ori $t0, $zero, 49
        beq $v0, $t0, process_1
        ori $t0, $zero, 50
        beq $v0, $t0, process_2
        j end_process_input

        process_q:
              # quit the game. 
              j end_main
        process_1:
              # drop simple bomb if available
              lw $s4, 20($sp) # get num of available s_bomb
              bgtz $s4, drop_s_bomb # if available simple bombs more than 0, drop
              j end_process_input   # else abort.
            drop_s_bomb:
              la $s7, bombs # s7 = addr of bombs
              ori $t0, $zero, 0 # t0 = 0. loop index i. 
              lw $s4, 20($sp) # s4 = num of simple bombs. 

              # loop to find the first available s_bomb, i.e, image_index = -1 < 0
              drop_s_bomb_loop:
                slt $t1, $t0, $s4
                beq $t1, $zero, end_drop_s_bomb_loop

                lw $s3, 8($s7) # s3 = image index
                bltz $s3, drop_this_s_bomb # s3 < 0, available. jump out of loop and drop this one. 

                addi $s7, $s7, 20 # update addr
                addi $t0, $t0, 1 # k+=1
                j drop_s_bomb_loop
              end_drop_s_bomb_loop:
                j end_process_input

            drop_this_s_bomb:
              # get ship x, y
              la $t0, ship # t0 = addr of ship
              lw $s1, 0($t0)
              lw $s2, 4($t0)
              addi $s1, $s1, 145 # s1 = x-coord of s_bomb
              addi $s2, $s2, 160 # s2 = y-coord of s_bomb
              ori $s3, $zero, 11 # index of s_bomb
              sw $s1, 0($s7) # update x-coord
              sw $s2, 4($s7) # update y-coord
              sw $s3, 8($s7) # update index
              addi $s4, $s4, -1 # available s_bomb - 1
              sw $s4, 20($sp)

              j end_process_input

        process_2:
              # drop remote bomb if available
              lw $s5, 24($sp) # get num of available r_bomb
              bgtz $s5, drop_this_r_bomb # if available remote bombs more than 0, drop
              j end_process_input   # else abort.
            drop_this_r_bomb:
              la $s7, bombs # s7 = addr of bombs
              addi $s7, $s7, 100 # directly move to the last bomb, which set as remote bomb
              # get ship x, y
              la $t0, ship # t0 = addr of ship
              lw $s1, 0($t0)
              lw $s2, 4($t0)
              addi $s1, $s1, 145 # s1 = x-coord of r_bomb
              addi $s2, $s2, 160 # s2 = y-coord of r_bomb
              ori $s3, $zero, 12 # index of r_bomb. set as Disabled. 
              sw $s1, 0($s7) # update x-coord
              sw $s2, 4($s7) # update y-coord
              sw $s3, 8($s7) # update index
              addi $s5, $s5, -1 # available r_bomb - 1
              sw $s5, 24($sp)
              j end_process_input

        process_e:
              # change all remote bombs undersea as activated. 
              lw $s7, bombs
              addi $s7, $s7, 100 # directly move to last bomb. 
              lw $s3, 8($s7)
              ori $t0, $zero, 12
              beq $s3, $t0, activate_r_bomb # if index is 12, it's disabled. Activate it!!
              j end_process_input
            activate_r_bomb:
              ori $s3, $zero, 13
              sw $s3, 8($s7)
              j end_process_input

end_process_input:

# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: move the ship, submarines and dolphins

moveShipSubmarinesDolphins:
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

# Operations here. 

# move ship
        la $s7, ship # s7 = addr of ship
        lw $s1, 0($s7) # s1 = x-coord of ship
        lw $s4, 12($s7) # s4 = speed of ship
        add $s1, $s1, $s4 # move ship
        sw $s1, 0($s7) # update ship location.
        # check out of bound. If so, change the direction of the speed. 
        ori $t1, $zero, 0  # t1 = left bound of ship
        ori $t2, $zero, 640 # t2 = right bound of ship
        blt $s1, $t1, change_ship_speed_right
        bgt $s1, $t2, change_ship_speed_left
        j end_move_ship

      change_ship_speed_left:
        ori $a0, $s4, 0 # set a0 as speed of ship.
        jal randomSignChange
        beq $v0, $s4, change_ship_speed_left # continue change if v0 = s4. 
        ori $s3, $zero, 2 # update index
        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_ship
      change_ship_speed_right:
        ori $a0, $s4, 0 # set a0 as speed of ship.
        jal randomSignChange
        beq $v0, $s4, change_ship_speed_right # continue change if v0 = s4. 
        ori $s3, $zero, 1 # update index
        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_ship

      end_move_ship:
# end of move ship

# move submarines.
        la $s7, submarines # s7 = addr of submarines. 
        ori $t0, $zero, 0 # t0 = 0. loop index i. 
        lw $s1, 8($sp) # num of submarines

move_submarine_loop:
        slt $t1, $t0, $s1
        beq $t1, $zero, end_move_submarine_loop # t1 = 1 <=> i< numOfSubmarines. 

        lw $s1, 0($s7) # s1 = x-coord of submarine
        lw $s4, 12($s7) # s4 = speed of submarine 
        add $s1, $s1, $s4 # move submarine 
        sw $s1, 0($s7) # update ship submarine 

        # check out of bound. If so, change the direction of the speed. 
        ori $t1, $zero, 0  # t1 = left bound of submarine 
        ori $t2, $zero, 720 # t2 = right bound of submarine 
        blt $s1, $t1, change_submarine_speed_right
        bgt $s1, $t2, change_submarine_speed_left
        j end_move_submarine

      change_submarine_speed_left:
        ori $a0, $s4, 0 # set a0 as speed of submarine.
        jal randomSignChange
        beq $v0, $s4, change_submarine_speed_left # continue change if v0 = s4. 
        lw $s3, 8($s7) # get index
        ori $t0, $zero, 4 # index of subL
        bgt $s3, $t0, change_damaged_left # 5 or 6 is index of damaged submarine
        j change_normal_left

          change_damaged_left:
            ori $s3, $zero, 6
            j save_change_submarine_left
          change_normal_left:
            ori $s3, $zero, 4
            j save_change_submarine_left

      save_change_submarine_left:

        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_submarine

      change_submarine_speed_right:
        ori $a0, $s4, 0 # set a0 as speed of submarine.
        jal randomSignChange
        beq $v0, $s4, change_submarine_speed_right # continue change if v0 = s4. 

        lw $s3, 8($s7) # get index
        ori $t0, $zero, 4 # index of subL
        bgt $s3, $t0, change_damaged_right # 5 or 6 is index of damaged submarine
        j change_normal_right

          change_damaged_right:
            ori $s3, $zero, 5
            j save_change_submarine_right
          change_normal_right:
            ori $s3, $zero, 3
            j save_change_submarine_right

      save_change_submarine_right:

        ori $s3, $zero, 3
        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_submarine

      end_move_submarine:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration. 
        addi $t0, $t0, 1 # i+=1
        j move_submarine_loop

end_move_submarine_loop:
# end of move submarines.

# move dolphins. 
        la $s7, dolphins # s7 = addr of dolphins.
        ori $t0, $zero, 0 # t0 = 0. loop index j.
        lw $s0, 4($sp) # num of dolphins

move_dolphin_loop:
        slt $t1, $t0, $s0
        beq $t1, $zero, end_move_dolphin_loop # t1 = 1 <=> j<numOfDolphins

        lw $s1, 0($s7) # s1 = x-coord of dolphin 
        lw $s4, 12($s7) # s4 = speed of dolhpin
        add $s1, $s1, $s4 # move dolphin 
        sw $s1, 0($s7) # update ship dolphin 

        # check out of bound. If so, change the direction of the speed. 
        ori $t1, $zero, 0  # t1 = left bound of dolphin
        ori $t2, $zero, 640 # t2 = right bound of dolphin
        blt $s1, $t1, change_dolphin_speed_right
        bgt $s1, $t2, change_dolphin_speed_left
        j end_move_dolphin

      change_dolphin_speed_left:
        ori $a0, $s4, 0 # set a0 as speed of dolphin.
        jal randomSignChange
        beq $v0, $s4, change_dolphin_speed_left # continue change if v0 = s4. 
        ori $s3, $zero, 9
        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_dolphin
      change_dolphin_speed_right:
        ori $a0, $s4, 0 # set a0 as speed of dolphin.
        jal randomSignChange
        beq $v0, $s4, change_dolphin_speed_right # continue change if v0 = s4. 
        ori $s3, $zero, 8
        ori $s4, $v0, 0 # set s4 as the new reverse speed. 
        sw $s3, 8($s7)
        sw $s4, 12($s7) # save new speed
        j end_move_dolphin

      end_move_dolphin:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration.
        addi $t0, $t0, 1 # j+=1
        j move_dolphin_loop

end_move_dolphin_loop:
# end of move dolphins.

# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra


#----------------------------------------------------------------------------------------------------------------------
# Function: move the bombs, and then remove those under the
# game screen and add them back to the available ones. 

moveBombs:
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

# Operations here. 

# move simple bombs.
        la $s7, bombs # s7 = addr of bombs 
        ori $t0, $zero, 0 # t0 = 0. loop index k. 
        lw $s4, 20($sp) # s4 = num of simple bombs. 

move_s_bomb_loop:
        slt $t1, $t0, $s4
        beq $t1, $zero, end_move_s_bomb_loop

        lw $s3, 8($s7) # s3 = index
        bgtz $s3, move_s_bomb # s3 > 0, bomb exists move. else, next loop. 
        j end_check_s_bomb_bound # same as jump to next iteration. 

      move_s_bomb:
        lw $t4, 12($s7) # t4 = speed
        lw $s2, 4($s7) # s2 = y-coord
        add $s2, $s2, $t4 # update y-coord
        sw $s2, 4($s7) # write

        # check out of bound. 
        ori $t1, $zero, 630 # 630 = screen height + bomb_height
        bgt $s2, $t1, rm_s_bomb_from_screen # y-coord > 630, out of bound
        j end_check_s_bomb_bound
  rm_s_bomb_from_screen:
        ori $s3, $zero, -1
        sw $s3, 8($s7) # update image index
        lw $s4, 20($sp) # s4 = available s bombs.
        addi $s4, $s4, 1 # add 1 back. 
        sw $s4, 20($sp) # write 
  end_check_s_bomb_bound:

        addi $s7, $s7, 20 # update addr
        addi $t0, $t0, 1 # k+=1
        j move_s_bomb_loop

end_move_s_bomb_loop:

# end of move simple bombs

# move remote bomb
        la $s7, bombs
        addi $s7, $s7, 100
        lw $s3, 8($s7) # s3 = index
        bgtz $s3, move_r_bomb # s3 > 0, r_bomb exists, move. else abort. 
        j end_check_r_bomb_bound # same as abort. 

      move_r_bomb:
        lw $t4, 12($s7) # t4 = speed
        lw $s2, 4($s7) # s2 = y-coord
        add $s2, $s2, $t4 # update y-coord
        sw $s2, 4($s7) # write

        ori $t1, $zero, 630 # 630 = screen height + bomb_height
        bgt $s2, $t1, rm_r_bomb_from_screen # y-coord >= 630, out of bound
        j end_check_r_bomb_bound
  rm_r_bomb_from_screen:
        ori $s3, $zero, -1
        sw $s3, 8($s7) # update image index
        lw $s5, 20($sp) # s4 = available s bombs.
        addi $s5, $s5, 1 # add 1 back. 
        sw $s5, 20($sp) # write 
  end_check_r_bomb_bound:

# end of move remote bomb

# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: update the image index of any damaged or destroyed submarines and dolphins

updateDamagedImages:
#===================================================================

# Push. 
	addi $sp, $sp, -36
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s4, 20($sp)
	sw $s5, 24($sp)
	sw $s6, 28($sp)
	sw $s7, 32($sp)

# Operations here. 

# update submarines.
        la $s7, submarines # s7 = addr of submarines. 
        ori $t0, $zero, 0 # t0 = 0. loop index i. 
        lw $s1, 8($sp) # num of submarines

update_submarine_loop:
        slt $t1, $t0, $s1
        beq $t1, $zero, end_update_submarine_loop # t1 = 1 <=> i< numOfSubmarines. 

        lw $s5, 16($s7)
        beq $s5, $zero, update_destroyed_submarine # hp=0, update destroyed image. 
        ori $t1, $zero, 5 # hp of a damaged submarine
        beq $s5, $t1, update_damaged_submarine # hp=5, update damaged.
        j end_update_submarine

  update_destroyed_submarine:
        ori $s3, $zero, 7 # update image
        sw $s3, 8($s7) # write
        j end_update_submarine

  update_damaged_submarine:
        lw $s4, 12($s7) # load speed. 
        slt $t1, $s4, $zero
        bne $t1, $zero, update_damaged_submarine_left # t1 = 1, speed < 0, Left
        j update_damaged_submarine_right
    update_damaged_submarine_left:
        ori $s3, $zero, 6 # update image
        sw $s3, 8($s7) # write
        j end_update_submarine
    update_damaged_submarine_right:
        ori $s3, $zero, 5 # update image
        sw $s3, 8($s7) # write
        j end_update_submarine

  end_update_submarine:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration. 
        addi $t0, $t0, 1 # i+=1
        j update_submarine_loop

end_update_submarine_loop:
# end of update submarines.

# update dolphins. 
        la $s7, dolphins # s7 = addr of dolphins.
        ori $t0, $zero, 0 # t0 = 0. loop index j.
        lw $s0, 4($sp) # num of dolphins

update_dolphin_loop:
        slt $t1, $t0, $s0
        beq $t1, $zero, end_update_dolphin_loop # t1 = 1 <=> j<numOfDolphins

        lw $s5, 16($s7)
        beq $s5, $zero, update_destroyed_dolphin # hp=0, dolphin destroyed
        j end_update_dolphin
  update_destroyed_dolphin:
        ori $s3, $zero, 10 # update image
        sw $s3, 8($s7) # write
        j end_update_dolphin

  end_update_dolphin:

        addi $s7, $s7, 20 # move up 20 bytes for next iteration.
        addi $t0, $t0, 1 # j+=1
        j update_dolphin_loop

end_update_dolphin_loop:
# end of update dolphins.

# Pop. 
        lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s4, 20($sp)
	lw $s5, 24($sp)
	lw $s6, 28($sp)
	lw $s7, 32($sp)
	addi $sp, $sp, 36

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: check if a new level is reached (when all the submarines have been removed)	
# return $v0: 0 -- false, 1 -- true

isLevelUp:
#===================================================================

	ori $v0, $zero, 1

	# check if a submarine is still not removed	
	la $t6, submarines
	li $t7, 0
level_submarine_loop:
	lw $t5, 8($t6)
	slti $t5, $t5, 0
	bne $t5, $zero, level_submarine_loop_continue	# skip removed submarines
	ori $v0, $zero, 0	# submarine has not been removed yet
	jr $ra

level_submarine_loop_continue:	
	addi $t7, $t7, 1 
	addi $t6, $t6, 20
	bne $t7, $s1, level_submarine_loop

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: check whether two rectangles (say A and B) intersect each other
# return $v0: 0 -- false, 1 -- true
# a0 = x-coordinate of the top-left corner of rectangle A
# a1 = y-coordinate of the top-left corner of rectangle A
# a2 = width of rectangle A
# a3 = height of rectangle A
# t0 = x-coordinate of the top-left corner of rectangle B
# t1 = y-coordinate of the top-left corner of rectangle B
# t2 = width of rectangle B
# t3 = height of rectangle B

isIntersected:
#===================================================================

	addi $sp, $sp, -24
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $s2, 12($sp)
	sw $s3, 16($sp)
	sw $s7, 20($sp)

	add $s0, $a0, $a2
	addi $s0, $s0, -1	# subtract 1 because the pixel after the last one was incorrectly added above 
	add $s1, $a1, $a3
	addi $s1, $s1, -1
	add $s2, $t0, $t2
	addi $s2, $s2, -1
	add $s3, $t1, $t3
	addi $s3, $s3, -1

	li $v0, 1	# first assume they intersect
	slt $s7, $s0, $t0		# A's right x < B's left x 
	bne $s7, $zero, no_intersect
	slt $s7, $s2, $a0		# A's left x > B's right x
	bne $s7, $zero, no_intersect

	slt $s7, $s1, $t1		# A's bottom y < B's top y 
	bne $s7, $zero, no_intersect
	slt $s7, $s3, $a1		# A's top y > B's bottom y
	bne $s7, $zero, no_intersect
	j check_intersect_end

no_intersect:
	li $v0, 0

check_intersect_end:

	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	lw $s2, 12($sp)
	lw $s3, 16($sp)
	lw $s7, 20($sp)
	addi $sp, $sp, 24

	jr $ra

#---------------------------------------------------------------------------------------------------------------------
# Function: update the game screen objects according to the game data structures in MIPS code here

updateGameObjects:				
#===================================================================


	li $v0, 100

	# update game state numbers	
	li $a0, 14

	li $a1, 0	# Score number
	ori $a2, $s2, 0	
	syscall
	
	li $a1, 1	# level number
	ori $a2, $s3, 0	
	syscall

	li $a1, 2	# simple bomb available number
	ori $a2, $s4, 0	
	syscall

	li $a1, 3	# remote bomb available number
	ori $a2, $s5, 0	
	syscall



	# update ship
	li $a1, 4

	la $t0, ship
	lw $a2, 0($t0)
	lw $a3, 4($t0)
		
	li $a0, 12	# ship location			
	syscall
	
	li $a0, 11	# ship image index
	lw $a2, 8($t0)	
	syscall



	# update submarines
	li $a1, 5

	la $t6, submarines
	li $t7, 0
draw_submarine_loop:
	lw $a2, ($t6)
	lw $a3, 4($t6)
	li $a0, 12	# location	
	syscall

	li $a0, 11	# image index
	lw $a2, 8($t6)	
	syscall

draw_submarine_loop_continue:
	addi $a1, $a1, 1	
	addi $t7, $t7, 1 
	addi $t6, $t6, 20
	bne $t7, $s1, draw_submarine_loop


	
	# update dolphins
	la $t6, dolphins
	li $t7, 0
draw_dolphin_loop:
	lw $a2, ($t6)
	lw $a3, 4($t6)
	li $a0, 12	# location	
	syscall

	li $a0, 11	# image index
	lw $a2, 8($t6)	
	syscall

draw_dolphin_loop_continue:
	addi $a1, $a1, 1	
	addi $t7, $t7, 1 
	addi $t6, $t6, 20
	bne $t7, $s0, draw_dolphin_loop
		

	# update bombs
	la $t6, bombs
	li $s7, 6
	li $t7, 0
draw_bomb_loop:
	lw $a2, ($t6)
	lw $a3, 4($t6)
	li $a0, 12	# location	
	syscall

	li $a0, 11	# image index
	lw $a2, 8($t6)	
	syscall

draw_bomb_loop_continue:
	addi $a1, $a1, 1	
	addi $t7, $t7, 1 
	addi $t6, $t6, 20
	bne $t7, $s7, draw_bomb_loop
	
	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: get input character from keyboard, which is stored using Memory-Mapped Input Output (MMIO)
# return $v0: ASCII value of input character if input is available; otherwise the value zero

getInput:
#===================================================================
	addi $v0, $zero, 0

	lui $a0, 0xffff
	lw $a1, 0($a0)
	andi $a1,$a1,1
	beq $a1, $zero, noInput
	lw $v0, 4($a0)

noInput:	
	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: randomly change the sign (from positive to negative or vice versa) of $a0, and return the result in $a0
# $a0 = an integer
randomSignChange:
#===================================================================
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	
	addi $sp, $sp, -4	# preserve the original integer
	sw $a0, 0($sp)	

	li $a0, 2
	jal randnum

	lw $a0, 0($sp)		# restore the original integer
	addi $sp, $sp, 4

	beq $v0, $zero, no_sign_change
	li $a1, -1
	mult $a1, $a0
	mflo $a0

no_sign_change:
	
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: set the seed of the random number generator to $a0
# $a0 = the seed number
setRandomSeed:
#===================================================================
	ori $a1, $a0, 0		
	li $v0, 40    
	li $a0, 1
	syscall

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: generate a random number between 0 and ($a0 - 1) inclusively, and return it in $v0
# $a0 = range
randnum:
#===================================================================

	li $v0, 42
	ori $a1, $a0, 0
	li $a0, 1 
	syscall
	ori $v0, $a0, 0

	jr $ra

#----------------------------------------------------------------------------------------------------------------------
# Function: set the location, color and font of drawing the game state's output objects in the game screen
setGameStateOutput:				
#===================================================================

		
	li $v0, 100

	# score number's location
	li $a1, 0
	li $a0, 12
	li $a2, 154
	li $a3, 35				
	syscall

	# font (size 20, plain)
	li $a0, 16
	li $a2, 20
	li $a3, 0
	li $t0, 0				
	syscall

	# color
	li $a0, 15
	li $a2, 0x00404040   # dark gray				
	syscall


	# level number's location
	li $a1, 1
	li $a0, 12
	li $a2, 154
	li $a3, 69				
	syscall

	# font (size 20, plain)
	li $a0, 16
	li $a2, 20
	li $a3, 0
	li $t0, 0				
	syscall

	# color
	li $a0, 15
	li $a2, 0x00404040   # dark gray				
	syscall

	
	# Simple bomb available number's location
	li $a1, 2
	li $a0, 12
	li $a2, 487
	li $a3, 45				
	syscall

	# font (size 26, plain)
	li $a0, 16
	li $a2, 26
	li $a3, 0
	li $t0, 0				
	syscall

	# color
	li $a0, 15
	li $a2, 0x00ff00ff   # purple				
	syscall

	# Remote bomb available number's location
	li $a1, 3
	li $a0, 12
	li $a2, 638
	li $a3, 45				
	syscall

	# font (size 26, plain)
	li $a0, 16
	li $a2, 26
	li $a3, 0
	li $t0, 0				
	syscall

	# color
	li $a0, 15
	li $a2, 0x00ff00ff   # purple				
	syscall

	jr $ra
	
#----------------------------------------------------------------------------------------------------------------------
# Function: set the location, font and color of drawing the game-over string object (drawn once the game is over) in the game screen
setGameoverOutput:				
#===================================================================


	li $v0, 100	# gameover string
	addi $a1, $s0, 11	# 11 for 4 game states, 6 bombs, 1 ship 
	add $a1, $a1, $s1 

	li $a0, 13	# set object to game-over string
	la $a2, msg3				
	syscall
	
	# location
	li $a0, 12
	li $a2, 100
	li $a3, 250				
	syscall

	# font (size 40, bold, italic)
	li $a0, 16
	li $a2, 80
	li $a3, 1
	li $t0, 1				
	syscall


	# color
	li $a0, 15
	li $a2, 0x00ffff00   # yellow				
	syscall

	jr $ra
	
#----------------------------------------------------------------------------------------------------------------------
## Function: create a new game (the first step in the game creation)
createGame:
#===================================================================
	li $v0, 100	

	li $a0, 1
	li $a1, 800 
	li $a2, 600
	la $a3, title
	syscall

	#set game image array
	li $a0, 3
	la $a1, images
	syscall

	li $a0, 5
	li $a1, 0   #set background image index to 0
	syscall
 
	jr $ra
#----------------------------------------------------------------------------------------------------------------------
## Function: create the game screen objects
createGameObjects:
#===================================================================

	li $v0, 100	
	li $a0, 2
	addi $a1, $zero, 4   	# 4 game state outputs
	addi $a1, $a1, 1	# 1 ship
	add $a1, $a1, $s1	# s1 submarines 
	add $a1, $a1, $s0	# s0 dolphins
	addi $a1, $a1, 6   	# 6 bombs
	addi $a1, $a1, 1	# gameover output 
	syscall
 
	jr $ra
#----------------------------------------------------------------------------------------------------------------------
## Function: create and show the game screen
createGameScreen:
#===================================================================

	li $v0, 100   
	li $a0, 4
	syscall
	 
	jr $ra
#----------------------------------------------------------------------------------------------------------------------
## Function: redraw the game screen with the updated game screen objects
redrawScreen:
#===================================================================
	li $v0, 100   
	li $a0, 6
	syscall

	jr $ra
#----------------------------------------------------------------------------------------------------------------------
## Function: get the current time (in milliseconds from a fixed point of some years ago, which may be different in different program execution).    
# return $v0 = current time 
getCurrentTime:
#===================================================================
	li $v0, 30
	syscall				# this syscall also changes the value of $a1
	andi $v0, $a0, 0x3fffffff  	# truncated to milliseconds from some years ago

	jr $ra
#----------------------------------------------------------------------------------------------------------------------
## Function: pause execution for X milliseconds from the specified time T (some moment ago). If the current time is not less than (T + X), pause for only 1ms.    
# $a0 = specified time T (returned from a previous calll of getCurrentTime)
# $a1 = X amount of time to pause in milliseconds 
pauseExecution:
#===================================================================
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	add $a3, $a0, $a1

	jal getCurrentTime
	sub $a0, $a3, $v0

	slt $a3, $zero, $a0
	bne $a3, $zero, positive_pause_time
	li $a0, 1     # pause for at least 1ms

positive_pause_time:

	li $v0, 32	 
	syscall

	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
#----------------------------------------------------------------------------------------------------------------------
