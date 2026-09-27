/* SPDX-License-Identifier: Apache-2.0 */

#ifndef SERV_TINYML_MAC_H
#define SERV_TINYML_MAC_H

#include <stdint.h>

void mac_clear(void);
void mac_set_config(uint8_t relu, uint8_t shift);
void mac_set_activation(int8_t activation);
void mac_set_weight(int8_t weight);
void mac_load_bias(int32_t bias);
void mac_accumulate(void);
int32_t mac_accumulator(void);
int8_t mac_result(void);
uint32_t mac_status(void);

#endif
