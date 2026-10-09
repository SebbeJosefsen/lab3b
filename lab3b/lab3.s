# First section:  user data,
# each process has its own "private" area.

        .data        
glob1:  .byte   'A'
        .space  999
glob2:  .byte   '0'
        .space  999
glob3:  .byte   'a'
        .space  999

# Second section: user code.
#
# The first instructions initializes IO and Timer.
# The last instruction in main are only used for start
# up, they initialize the first process.

        .text
        .set noreorder
main:
        li    $t0, 0xFFFF0010   # address to Timer registers:
                                # +0: Timer control register
                                # +4: Timer count register
                                # +8: Timer compare register

        li    $t1, 0
        sw    $t1, 4($t0)       # reset counter register

        li    $t1, 63           # count from 0 to 63
        sw    $t1, 8($t0)       # compare register := 63

        li    $t1, 0b101001     # "101001": compare interrupt enable,
                                #           compare reset enable,
                                #           timer start
        sw    $t1, 0($t0)       # control register := "101001"

        li    $t0, 0xFFFF0000   # address to I/O registers:
                                # +0: Input control register
 
        li    $t1, 0b10         # "10": interrupt enable
        sw    $t1, 0($t0)       # control register := "10"

        li    $t0, 0x0C03       # enable HW Interrupt 1 (input):  bit 11
                                # enable HW Interrupt 1 (timer):  bit 10
                                # set user mode:      1 (user):   bit 1
                                # enable interrupts   1 (enable): bit 0

        mtc0  $t0, $12          # CP0 status := 0x0C03

        la    $gp, glob1        # dirty setup for process 1


proc1:  # ++++++++++ first process +++++++++

        # Description: proc1 reads the byte stored at 0($gp),
        # prints it, increments to the next character,
        # saving that back into 0($gp).  After printing 'Z',
        # this process should then start over again with 'A', in
        # an endless loop.  The symbol "glob1" may not be used.
        
        #li    $t0, 0x7FFFFFFF     # Test by overflow (signed)
        #addi  $t0, $t0, 1

        lb    $t2, 0($gp)         # Load the byte stored at 0($gp)
        nop

        move  $a0, $t2            # Copy paste the value in $t2 to $a0
        li    $v0, 0x102          # Specify the kernel service

        #li    $v0, 0x103          # Test with the wrong service code

        syscall                   # Call the kernel

        beq   $t2, 90, eqZ        # Check if equal to Z

        addi  $t2, $t2, 1         # Increment to the next character
        nop
        
        sb    $t2, 0($gp)         # Store the byte at 0($gp)
        
        j     proc1               # Rerun proc1
        nop

eqZ:    
        addi  $t2, $zero, 65      # Reset to A if earlier reached Z
        sb    $t2, 0($gp)         # Store the byte at 0($gp)

        j     proc1               # Rerun proc1
        nop


proc2: # ++++++++++ second process +++++++++

        # Description: almost identical to the code of proc1 above,
        # only 2-3 lines should differ.  Prints '0' through '9' in
        # an endless loop. The symbol "glob2" may not be used.

        lb    $t2, 0($gp)         # Load the byte stored at 0($gp)
        nop

        move  $a0, $t2            # Copy paste the value in $t2 to $a0
        li    $v0, 0x102          # Specify the kernel service
        syscall                   # Invoke the kernel

        beq   $t2, 57, eq9        # Check if equal to 9
        
        addi  $t2, $t2, 1         # Increment to the next character
        nop
        
        sb    $t2, 0($gp)         # Store the byte at 0($gp)
        
        j     proc2               # Rerun proc2
        nop

eq9:    
        addi  $t2, $zero, 48      # Reset to 0 if earlier reached 9
        sb    $t2, 0($gp)         # Store the byte at 0($gp)

        j proc2
        nop


proc3:  # +++++++++ third process ++++++++++

        # Description: almost identical to the code of proc1 above,
        # only 2-3 lines should differ.  Prints 'a' through 'z' in
        # an endless loop. The symbol "glob3" may not be used.

        lb    $t2, 0($gp)         # Load the byte stored at 0($gp)
        nop

        move  $a0, $t2            # Copy paste the value in $t2 to $a0
        li    $v0, 0x102          # Specify the kernel service
        syscall                   # Invoke the kernel

        beq   $t2, 122, eqz       # Check if equal to z
        
        addi  $t2, $t2, 1         # Increment to the next character
        nop
        
        sb    $t2, 0($gp)         # Store the byte at 0($gp)
        
        j     proc3               # Rerun proc3
        nop

eqz:    
        addi  $t2, $zero, 97      # Reset to a if earlier reached z
        sb    $t2, 0($gp)         # Store the byte at 0($gp)

        j proc3
        nop


# Third section: data structures for the kernel:
# Process Control Block (PCB) consists of three words:
# pcb: .word  (next Program Counter for this process)
#      .word  (contents of $gp for this process)
#      .word  (contents of $sp for this process)
# All other context is saved on the process' own stack
# during exception handling and SYSCALL.

        .section .kdata
curpcb: .word  pcb1
pcb1:   .word  0, 0, 0 # $sp set on boot/reset (reload in SyncSim)
pcb2:   .word  proc2, glob2, 0x7fffbf94 
pcb3:   .word  proc3, glob3, 0x7fff7f94

# Fourth section: kernel code.

        .section .ktext , "xa"
        .set noreorder
                     
        mfc0  $k0, $13                  # Get value of $13 and put it in $k0      
        nop
        
        srl   $k0, $k0, 2               # Shift right logical with 2 bits so that we start at the 2 in [5:2]  
        andi  $k0, $k0, 0xF             # Keep only the first 4 (lowest valued) bits so that we only have [5:2]      

                                        # Now $k0 contains the exception code
        
        li    $k1, 0                    # Load immediat 0 (external interrupts)
        beq   $k0, $k1, if_external     # Check to see if it is an external interrupt
        nop

        li    $k1, 8                    # Load immediate 8 (syscall)
        beq   $k0, $k1, if_syscall      # Check to see if there is overflow (syscall)
        nop

        j kernel_loop                   # If not external interrupt or syscall, then we go to kernel_loop
        nop

if_external:
        mfc0  $k0, $13                  # Get value of $13 and put it in $k0      
        nop
        andi  $k0, $k0, 0x0400          # Keep only bit 10 (timer interrupt)
                                        # Int0 inte aktiv (not pending): $k0 = 0x0000 
                                        # Int0 aktiv (pending): $k0 = 0x0400
        beq   $k0, $zero, kernel_loop   # If the bit is not active then kernel_loop
        nop


        # int_handler from lab2	

	# Clear Timer Interrupt
	li      $k0, 0xFFFF0010
	li      $k1, 0b101001
	sw      $k1, 0($k0)


        # Store the entire current process

	#    +----------------------+
	#    |                      |
        #    |     procX's stack    |
        #    |                      |
        #    +----------------------+
        #    |  old return address  | 104($sp) 
        #    +----------------------+
        #    |  old frame pointer   | 100($sp)
        #    +----------------------+           
        #    |          sX          | 96-68($sp)   
        #    +----------------------+           
        #    |          tX          | 64-28($sp)   
        #    +----------------------+           
        #    |          aX          | 24-12($sp)
        #    +----------------------+           
        #    |          vX          | 8-4($sp) 
        #    +----------------------+           
        #    |          at          | 0($sp)  <= $sp points here            	
        #    +----------------------+ 

        addiu $sp, $sp, -108             
        
        sw    $ra, 104($sp)             # Store old return adress
        
        sw    $fp, 100($sp)             # Store old frame pointer
        
        sw    $s0, 96($sp)              # Store $sX
        sw    $s1, 92($sp)
        sw    $s2, 88($sp)
        sw    $s3, 84($sp)
        sw    $s4, 80($sp)
        sw    $s5, 76($sp)
        sw    $s6, 72($sp)
        sw    $s7, 68($sp)

        sw    $t0, 64($sp)              # Store $tX
        sw    $t1, 60($sp)
        sw    $t2, 56($sp)
        sw    $t3, 52($sp)
        sw    $t4, 48($sp)
        sw    $t5, 44($sp)
        sw    $t6, 40($sp)
        sw    $t7, 36($sp)
        sw    $t8, 32($sp)
        sw    $t9, 28($sp)
        
        sw    $a0, 24($sp)              # Store $aX
        sw    $a1, 20($sp)                
        sw    $a2, 16($sp)                
        sw    $a3, 12($sp)                

        sw    $v0, 8($sp)               # Store $vX
        sw    $v1, 4($sp)

        .set  noat                       
        sw    $at, 0($sp)               # Store $at
        .set  at


        # Store into PCBX

        #    +----------------------+
	#    |                      |
        #    |         PCBX         |
        #    |                      |
        #    +----------------------+
        #    |          SP          | 8($k0) 
        #    +----------------------+
        #    |          GP          | 4($k0)
        #    +----------------------+           
        #    |          EPC         | 0($k0)   
        #    +----------------------+        

        lw    $k0, curpcb               # Load the current pcbX
        nop

        mfc0  $k1, $14                  # Get EPC
        nop

        sw    $k1, 0($k0)               # Store EPC in pcbX
        sw    $gp, 4($k0)               # Store GP in pcbX   
        sw    $sp, 8($k0)               # Store SP in pcbX


        la    $k1, pcb1
        beq   $k0, $k1, is_pcb1
        nop

        la    $k1, pcb2
        beq   $k0, $k1, is_pcb2
        nop

        la    $k1, pcb3
        beq   $k0, $k1, is_pcb3
        nop

is_pcb1:
        la    $k1, pcb2
        j     switch_done
        nop

        b     kernel_loop
        nop

is_pcb2:
        la    $k1, pcb3
        j     switch_done
        nop

        b     kernel_loop
        nop

is_pcb3:
        la   $k1, pcb1
        j     switch_done
        nop

        b     kernel_loop
        nop

switch_done:
        sw    $k1, curpcb               # Update curpcb to have the next pcbX

        lw    $k0, 0($k1)               # Load the new pcbX's EPC, 
        lw    $gp, 4($k1)               # GP, 
        lw    $sp, 8($k1)               # and SP


        # Restore values for current pcbX

        lw    $ra, 104($sp)             # Load old return adress
        
        lw    $fp, 100($sp)             # Load old frame pointer
        
        lw    $s0, 96($sp)              # Load $sX
        lw    $s1, 92($sp)
        lw    $s2, 88($sp)
        lw    $s3, 84($sp)
        lw    $s4, 80($sp)
        lw    $s5, 76($sp)
        lw    $s6, 72($sp)
        lw    $s7, 68($sp)

        lw    $t0, 64($sp)              # Load $tX
        lw    $t1, 60($sp)
        lw    $t2, 56($sp)
        lw    $t3, 52($sp)
        lw    $t4, 48($sp)
        lw    $t5, 44($sp)
        lw    $t6, 40($sp)
        lw    $t7, 36($sp)
        lw    $t8, 32($sp)
        lw    $t9, 28($sp)
        
        lw    $a0, 24($sp)              # Load $aX
        lw    $a1, 20($sp)                
        lw    $a2, 16($sp)                
        lw    $a3, 12($sp)                

        lw    $v0, 8($sp)               # Load $vX
        lw    $v1, 4($sp)

        .set  noat                       
        lw    $at, 0($sp)               # Load $at
        .set  at

        addiu $sp, $sp, 108

        jr    $k0
        rfe

if_syscall:
        li    $k1, 0x102                # Load output
        bne   $v0, $k1, kernel_return   # Check if the right service code is used

        li    $k0, 0xFFFF0000           # Load immediate 0xFFFF0000
        sw    $a0, 8($k0)               # Store value in $a0 using the loaded immediate as adress, and with offset 8. 
        nop

kernel_return:
        MFC0  $k0, $14                  # Get value of $14 and put it in $k0
        nop     
        addi  $k0, $k0, 4               # Add 4 to the value above

        jr $k0                          # Return it
        rfe                             # Switch from kernel mode to user mode

kernel_loop: 
        b kernel_loop                   # Branch to kernel_loop
        nop
