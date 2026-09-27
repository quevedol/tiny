/* SPDX-License-Identifier: Apache-2.0 */

#include <stdint.h>

#include "mac.h"

#define SML_STATUS_ADDR 0x20000200u
#define SML_SIGNATURE   0x534d4c31u
#define SML_FAILURE     0xbad00000u
#define UART_DATA_ADDR  0x20000100u
#define UART_STATE_ADDR 0x20000104u

static volatile uint32_t scratch_a;
static volatile uint32_t scratch_b;

/* Volatile prevents GCC from folding this immutable test vector into .rodata:
 * start.S must copy the compact model from Flash to PSRAM. */
struct tinyml_smoke_model {
    int8_t input[4];
    int8_t weights[3][4];
    int32_t biases[3];
};

static volatile struct tinyml_smoke_model tinyml_smoke = {
    .input = {12, -6, 8, 3},
    .weights = {
        {3, -2, 1, 4},
        {-4, 2, 5, -3},
        {2, 3, 4, -1},
    },
    .biases = {-4, 3, 4},
};


static void uart_putc(uint8_t value)
{
    volatile uint32_t *const data =
        (volatile uint32_t *)UART_DATA_ADDR;
    volatile uint32_t *const state =
        (volatile uint32_t *)UART_STATE_ADDR;

    while ((*state & 1u) == 0u) {
    }
    *data = value;
}

static uint32_t tinyml_smoke_inference(void)
{
    uint32_t failure = 0u;
    uint32_t output;

    for (output = 0u; output < 3u; ++output) {
        const int8_t expected = (output == 0u) ? 32 :
                                (output == 1u) ? 0 : 19;
        uint32_t input_index;

        mac_load_bias(tinyml_smoke.biases[output]);
        mac_set_config(1u, 1u);
        for (input_index = 0u; input_index < 4u; ++input_index) {
            mac_set_activation(tinyml_smoke.input[input_index]);
            mac_set_weight(tinyml_smoke.weights[output][input_index]);
            mac_accumulate();
        }

        if (mac_result() != expected)
            failure |= 1u << (10u + output);
        if ((mac_status() & 2u) != 0u)
            failure |= 1u << (13u + output);
    }

    return failure;
}

int main(void)
{
    volatile uint32_t *const status =
        (volatile uint32_t *)SML_STATUS_ADDR;

    uint32_t failure = 0;

    scratch_a = 17u;
    scratch_b = 5u;

    const uint32_t a = scratch_a;
    const uint32_t b = scratch_b;

    if (a + b != 22u)
        failure |= 1u << 0;
    if (a - b != 12u)
        failure |= 1u << 1;
    if ((a ^ b) != 20u)
        failure |= 1u << 2;
    if ((a << 2) != 68u)
        failure |= 1u << 3;
    if (a <= b)
        failure |= 1u << 4;

    mac_clear();
    mac_set_config(0u, 0u);
    mac_set_activation(3);
    mac_set_weight(4);
    mac_accumulate();
    mac_set_activation(-2);
    mac_set_weight(5);
    mac_accumulate();

    if (mac_accumulator() != 2)
        failure |= 1u << 5;
    if (mac_result() != 2)
        failure |= 1u << 6;
    if ((mac_status() & 1u) == 0u)
        failure |= 1u << 7;

    mac_load_bias(1024);
    mac_set_config(0u, 4u);
    if (mac_result() != 64)
        failure |= 1u << 8;

    mac_load_bias(-32);
    mac_set_config(1u, 0u);
    if (mac_result() != 0)
        failure |= 1u << 9;

    failure |= tinyml_smoke_inference();

    if (failure == 0u) {
        static const char message[] = "SML1\n";
        const char *cursor = message;
        while (*cursor != '\0')
            uart_putc((uint8_t)*cursor++);
        *status = SML_SIGNATURE;
    } else {
        *status = SML_FAILURE | failure;
    }

    for (;;) {
        __asm__ volatile ("" ::: "memory");
    }
}
