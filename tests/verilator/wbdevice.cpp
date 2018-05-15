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
// Wishbone dummy device for device/interrupt testing.
// 32-bits address & data bus.

#include "wbdevice.h"
#include "colors.h"

#define DEVICESZ 1024

// -----------------------------------------------------------------------------
// Constructor.
WBDEVICE::WBDEVICE(const uint32_t base_addr) {
        m_base_addr = base_addr;
        m_delay_cnt = 0;
}

// -----------------------------------------------------------------------------
// Destructor.
WBDEVICE::~WBDEVICE() {
}

// -----------------------------------------------------------------------------
// Execute model: read/write operations.
void WBDEVICE::operator()(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                          const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o,
                          uint8_t &meip, uint8_t &mtip, uint8_t &msip) {
        /*
         * Memory map:
         * 0: Trigger Software interrupt.
         * 4: Trigger Timer interrupt.
         * 8: Trigger External interrupt.
         */
        auto addr = wbs_addr_i - m_base_addr;
        // check for access
        if (!(wbs_cyc_i && wbs_stb_i))
                return;
        // check memory range. This device have a asigned size of DEVICESZ bytes
        if (wbs_addr_i < m_base_addr or wbs_addr_i > m_base_addr + DEVICESZ)
                return;

        // Default state for output port
        wbs_data_o = 0x0badf00d;
        wbs_ack_o  = 0;
        wbs_err_o  = 0;
        // msip       = false;
        // mtip       = false;
        // meip       = false;
        //
        if (m_delay_cnt++ == 1){
                switch (addr) {
                case 0:
                        if (wbs_we_i and wbs_sel_i == 0xF)
                                msip = wbs_dat_i != 0;
                        printf("[WBDEVICE] Access to Software Interrupt: %d\n", msip);
                        wbs_ack_o = true;
                        break;
                case 4:
                        if (wbs_we_i and wbs_sel_i == 0xF)
                                mtip = wbs_dat_i != 0;
                        printf("[WBDEVICE] Access to Timer Interrupt: %d\n", mtip);
                        wbs_ack_o = true;
                        break;
                case 8:
                        if (wbs_we_i and wbs_sel_i == 0xF)
                                meip = wbs_dat_i != 0;
                        printf("[WBDEVICE] Access to External Interrupt: %d\n", meip);
                        wbs_ack_o = true;
                        break;
                default:
                        wbs_err_o = true;
                        fprintf(stderr, ANSI_COLOR_RED "[WBDEVICE] Invalid bus address: 0x%08X\n" ANSI_COLOR_RESET, wbs_addr_i);
                        break;
                }
                m_delay_cnt = 0;
        }
}
