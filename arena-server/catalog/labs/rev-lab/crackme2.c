#include <stdio.h>
int main(void) {
    char b[32] = {0};
    puts("reverseme #2 — the binary is stripped, symbols are gone.");
    printf("key> "); fflush(stdout);
    if (!fgets(b, sizeof b, stdin)) return 1;
    unsigned h = 7;
    for (int i = 0; i < 8 && b[i]; i++) h = (h * 33u) ^ (unsigned char)b[i];
    if (h == 0x9d3f1a77u) puts("Correct! AEXUS{angr_loves_constraints}");
    else puts("Nope.");
    return 0;
}
