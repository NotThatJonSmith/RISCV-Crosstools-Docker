CC=/cross/bin/riscv32-unknown-elf-gcc
OUT_DIR=out

$(OUT_DIR)/%: %.c
	${CC} $< -o $@

$(OUT_DIR)/dtbs/%.dtb: device_trees/%.dts
	mkdir -p $(OUT_DIR)/dtbs
	dtc $< -o $@

$(OUT_DIR)/kernels/pk:
	mkdir -p $(OUT_DIR)/kernels
	mkdir -p $(OUT_DIR)/builds/riscv-pk
	cd $(OUT_DIR)/builds/riscv-pk && \
	../../../external/riscv-pk/configure \
		--host=riscv32-unknown-elf \
		--prefix=/cross \
		--enable-32bit && \
	make && \
	cp pk ../../kernels/

$(OUT_DIR)/kernels/vmlinux:
	cd external/linux && \

all: $(OUT_DIR)/kernels/pk $(OUT_DIR)/fib $(OUT_DIR)/hello $(OUT_DIR)/dtbs/board.dtb
