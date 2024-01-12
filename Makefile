CC=/cross/bin/riscv32-unknown-elf-gcc
OUT_DIR=out
export PATH := /cross/bin:${PATH}

$(OUT_DIR)/%: %.c
	${CC} $< -o $@

$(OUT_DIR)/%-disasm.txt: $(OUT_DIR)/%
	/cross/bin/riscv32-unknown-elf-objdump -d $< > $@

$(OUT_DIR)/dtbs/%.dtb: device_trees/%.dts
	mkdir -p $(OUT_DIR)/dtbs
	dtc $< -o $@

$(OUT_DIR)/kernels/pk32:
	mkdir -p $(OUT_DIR)/kernels
	mkdir -p $(OUT_DIR)/builds/riscv-pk-32
	cd $(OUT_DIR)/builds/riscv-pk-32 && \
	../../../external/riscv-pk/configure \
		--host=riscv32-unknown-elf \
		--prefix=/cross \
		--enable-32bit && \
	make && \
	cp pk ../../kernels/pk32

$(OUT_DIR)/kernels/pk64:
	mkdir -p $(OUT_DIR)/kernels
	mkdir -p $(OUT_DIR)/builds/riscv-pk-64
	cd $(OUT_DIR)/builds/riscv-pk-64 && \
	../../../external/riscv-pk/configure \
		--host=riscv64-unknown-elf \
		--prefix=/cross && \
	make && \
	cp pk ../../kernels/pk64

# Also, yes, we're building 32-bit pk but 64-bit linux. For now.
# Should eventually build both PKs.
# TODO dependency on linux-config file
$(OUT_DIR)/kernels/vmlinux: linux-config
	mkdir -p $(OUT_DIR)/kernels
	cp linux-config external/linux/.config
	cd external/linux && $(MAKE) CROSS_COMPILE=/cross/bin/riscv64-linux-gnu- ARCH=riscv
	cp external/linux/vmlinux $(OUT_DIR)/kernels/vmlinux

all: $(OUT_DIR)/kernels/pk32 $(OUT_DIR)/kernels/pk64 $(OUT_DIR)/kernels/vmlinux $(OUT_DIR)/fib $(OUT_DIR)/hello $(OUT_DIR)/dtbs/board.dtb $(OUT_DIR)/hello-disasm.txt
