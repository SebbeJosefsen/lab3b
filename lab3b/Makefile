FILE = lab3.s
MIPS_ELF := $(shell command -v mips-elf-as 2> /dev/null)
MIPS_LINUX_GNU := $(shell command -v mips-linux-gnu-as 2> /dev/null)
SDE := $(shell command -v sde-as 2> /dev/null)

pipe_ext:
ifdef SDE
	@echo "compiling using sde-"
	$(eval toolchain := sde)
else
ifdef MIPS_ELF
	@echo "compiling using mips-elf-"
	$(eval toolchain := mips-elf)
else
ifdef MIPS_LINUX_GNU
	@echo "compiling using mips-linux-gnu-"
	$(eval toolchain := mips-linux-gnu)
else
	$(error No toolchain detected, try following the course setup guide.)
endif
endif
endif
	$(toolchain)-as -march=r3k -O0 $(FILE) -o test.o
	$(toolchain)-ld -T linker_script test.o -o a_pipe_ext.out
	$(toolchain)-objdump -h -z -s -d -t a_pipe_ext.out > mips_ext_program.objdump
	rm test.o


