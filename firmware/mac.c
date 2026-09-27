/* SPDX-License-Identifier: Apache-2.0 */

#include "mac.h"

#define MAC_BASE 0x20000000u

enum {
    MAC_CMD = 0x00u,
    MAC_ACTIVATION = 0x04u,
    MAC_WEIGHT = 0x08u,
    MAC_BIAS = 0x0cu,
    MAC_ACCUMULATOR = 0x10u,
    MAC_RESULT = 0x14u,
    MAC_STATUS = 0x18u,
    MAC_CONFIG = 0x1cu,
};

static volatile uint32_t *const mac = (volatile uint32_t *)MAC_BASE;

void mac_clear(void)
{
    mac[MAC_CMD / 4u] = 1u;
}

void mac_set_config(uint8_t relu, uint8_t shift)
{
    mac[MAC_CONFIG / 4u] = ((uint32_t)(shift & 0x1fu) << 1) | (relu != 0u);
}

void mac_set_activation(int8_t activation)
{
    mac[MAC_ACTIVATION / 4u] = (uint32_t)(int32_t)activation;
}

void mac_set_weight(int8_t weight)
{
    mac[MAC_WEIGHT / 4u] = (uint32_t)(int32_t)weight;
}

void mac_load_bias(int32_t bias)
{
    mac[MAC_BIAS / 4u] = (uint32_t)bias;
    mac[MAC_CMD / 4u] = 2u;
}

void mac_accumulate(void)
{
    mac[MAC_CMD / 4u] = 4u;
}

int32_t mac_accumulator(void)
{
    return (int32_t)mac[MAC_ACCUMULATOR / 4u];
}

int8_t mac_result(void)
{
    return (int8_t)mac[MAC_RESULT / 4u];
}

uint32_t mac_status(void)
{
    return mac[MAC_STATUS / 4u];
}
