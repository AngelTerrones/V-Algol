/*
 * Algol - A RISC-V (RV32I) Processor Core.
 *
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

// File: wbdevice.h
// Wishbone dummy device for testing the external interrupts:
// - Timer
// - Software
// - External
// 32-bits address & data bus.

#include <vector>
#include <string>
#include <cstdint>

#ifndef __WBDEVICE_H
#define __WBDEVICE_H

class WBDEVICE {
public:
        WBDEVICE(const uint32_t base_addr);
        ~WBDEVICE();

        void operator()(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                        const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                        uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o,
                        uint8_t &meip, uint8_t &mtip, uint8_t &msip);
private:
        uint32_t m_base_addr;
        uint32_t m_delay_cnt;
};

#endif // __WBDUMMY_H
