/* Host-only adapter for exercising the actual firmware parser from Swift. */
#include <stdio.h>
#include "lighting_protocol.h"
int main(void) {
    KPHLighting state;
    uint8_t input[32], output[32];
    size_t length;
    kph_lighting_init(&state);
    while ((length = fread(input, 1, sizeof input, stdin)) != 0) {
        if (length != sizeof input) return 2;
        putchar(kph_lighting_apply(&state, input, sizeof input));
        kph_lighting_report(&state, output);
        if (fwrite(output, 1, sizeof output, stdout) != sizeof output) return 3;
    }
    return ferror(stdin) ? 4 : 0;
}
