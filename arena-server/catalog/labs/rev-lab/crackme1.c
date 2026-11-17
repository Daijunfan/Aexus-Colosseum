#include <stdio.h>
#include <string.h>
int main(void) {
    char b[64];
    puts("Welcome to Aexus Colosseum reverseme #1");
    printf("key> "); fflush(stdout);
    if (!fgets(b, sizeof b, stdin)) return 1;
    b[strcspn(b, "\n")] = 0;
    unsigned x = 0x41;
    for (size_t i = 0; i < strlen(b); i++) x = (x * 131 + (unsigned char)b[i]) & 0xffffffff;
    if (x == 0x6f4b2d31u) puts("Correct! The first flag is: AEXUS{static_analysis_first}");
    else puts("Nope.");
    return 0;
}
