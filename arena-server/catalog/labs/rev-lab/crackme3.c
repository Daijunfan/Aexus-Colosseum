#include <stdio.h>
int main(void) {
    char b[16] = {0};
    puts("reverseme #3 — symbolic execution is your friend.");
    printf("key> "); fflush(stdout);
    if (!fgets(b, sizeof b, stdin)) return 1;
    int ok = 1;
    for (int i = 0; i < 6; i++) if ((unsigned char)b[i] != (unsigned char)("4rena!"[i] ^ 0x21)) ok = 0;
    if (ok) puts("Correct! AEXUS{patience_is_a_weapon}"); else puts("Nope.");
    return 0;
}
