# Lab 3b: Multitasking

In this lab you will continue working on implementing a simple kernel. This time, you will focus on implementing kernel support for multitasking. A real operating system provides functionality to dynamically load programs, create and kill processes, etc. Moreover, under a real operating system each process would typically execute in a virtual memory environment, and thus run isolated from other processes (and the kernel) in the system.

For this lab, all processes and the kernel are statically linked, and the kernel need only to serve the predefined set of (user) processes.

You can compile your program by running `make pipe_ext` in the Terminal and start SyncRim in the extended mode by opening the ext model. You can open an Input/Output Window in SyncRim by pressing Show on the I/O component.

## General info

When a (single-core) computer system executes multiple user processes (tasks), it typically switches between them either depending on their priorities or (as in this lab) in a round-robin fashion. In the latter case, each user process is given a certain time quantum to execute before it is preempted and replaced by another process. This is accomplished by setting up a timer; when the timer fires, a hardware interrupt gives control to the kernel, which switches the user processes.

Each user process is written as if it is the only process running on the system, i.e. it does not know and doesn't need to know about the other processes. This means that it has its own stack (pointed to by `$sp`), its own memory space (pointed to by `$gp`), and its own program counter. Switching from a process A to a process B implies:

- Saving the context of A, i.e, all registers (besides `$k0` and `$k1` which are reserved for the kernel). In our implementation, we will save `$sp`, `$gp` and `PC` in a Process Control Block (PCB) in the kernel space (`.kdata`) and all the other registers will be saved on the process's own stack. `cur_pcb` points to the current PCB entry (in this case process A).
- Updating the `cur_pcb` to point to next entry (in this case PCB entry for process B)

- Restoring the context of B, as stored in PCB B and partially from the stack for process B, and finally resuming execution of process B.

Note: in real MIPS, when an external interrupt preempts an instruction executing in a jump/branch delay slot, a special bit is set in the Status Register (SR) of the co-processor CP0. In our model this is not implemented, instead the Exception Program Counter (EPC) will contain the address to the corresponding jump or branch instruction. (We made this simplification to reduce the complexity of the lab.)

## Assignment

1. Copy the your file `lab3.s` (from lab 3a) to the folder `lab3b`. For lab 3b, you need to change the initialization code to enable interrupts (revert the change made for lab 3a): write `0x0C03` instead of `0x0003` to the Status Register (SR)., register `$12` of the co-processor CP0.

2. Implement the second and the third user processes (`proc2` and `proc3` Process 2 should print the numbers from 0 (ASCII code 48) to 9 (ASCII code 57), process 3 should print the letters from 'a' (ASCII code 97) to 'z' (ASCII code 122) in an endless loop.

3. Extend your implementation of the exception handler. You should now detect both `SYSCALL` (a software interrupt) and external interrupts (`ExtInt`).

   For external interrupts, the exception code in the bits [5:2] of the Exception Cause Register is 0. You should also determine the source of such an interrupt:

   - the bits [15:10] of the Exception Cause Register are set if any of the interrupts Int5 (bit 15) ... Int0 (bit 10) are pending;

   - Int0 is a timer interrupt;

   - Int1 is an input interrupt (registered when you type something in an Input Window).

   If the exception code is neither `SYSCALL` nor `ExtInt`, you should branch to an infinite loop in the kernel code _kernel_loop_.

   Moreover, if the source of an external interrupt is not the timer, you should also branch to _kernel_loop_ (thus typing something in an Input Window should freeze the program). Finally, if the exception code is `SYSCALL` but the service requested by the application is not "output", you should return control to the user process.

4. If a timer interrupt has been registered, you should first clear the timer interrupt (see `int_handler.s` from lab 2) and then switch to the next user process, so that each user process is executed for about 1000 clock cycles. This should be done so that a user process cannot detect that it was interrupted and resumed later, i.e. you should preserve its complete context. You should:

   - update the PCB of the current process (`curpcb` in the kernel space points to it). Each PCB contains a program counter. For the interrupted process, it is available in the Exception Program Counter (EPC), register `$14` of the co-processor CP0); a pointer to the process's private data space (available in `$gp`); and a pointer to the process's own stack (available in `$sp`). PCB's for all user processes are stored in the kernel space `.kdata`.

   - save the contents of the registers `$ra`, `$fp`, `$sX`, `$tX`, `$aX`, `$vX` and `$at` on the own stack of the process. To avoid warnings about accessing the register `$at`, write

   ```mips
           .set noat
           sw $at, ...
           .set at
   ```

   - switch to the next user process, i.e. update `curpcb`;

   - restore all the registers of the (new/to be resumed) user process, including `$ra`, `$gp` and `$sp`.

   - jump back to the address stored in the PCB of the (new/to be resumed) process and execute `RFE` (return from exception) in the jump delay slot.

5. Test your implementation: open a new Output Window and run the program. It should switch between printing letters from 'A' to 'Z', numbers from 0 to 9, and letters from 'a' to 'z', in an endless loop. If you open a new Input Window and type something, the program should jump to the infinite loop in the kernel.

Don't forget to add clear high-level comments to your code.

**For CI to run properly, include the a_pipe_ext.out file from your code in the top dir of the repo.**
