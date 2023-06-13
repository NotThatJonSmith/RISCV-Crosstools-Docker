
CC=${CROSS_TOOLS_PREFIX}gcc

%: %.c
	${CC} $< -o $@

all: fib return_zero
