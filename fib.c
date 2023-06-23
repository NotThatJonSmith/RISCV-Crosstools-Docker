#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

int fib_cache[50] = {0};
int fib(int n) {
    if (n < 2)
        return 1;
    if (n < 50 && fib_cache[n] != 0) {
        return fib_cache[n];
    }
    int f = fib(n-1) + fib(n-2);
    fib_cache[n] = f;
    return f;
}

int main(int argc, char **argv) {
    int n = atoi(argv[1]);
    printf("Fib(%d) = %d\n", n, fib(n));
    exit(0);
}
