/*
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

// File: wbconsole.h
// Wishbone dummy device for device/interrupt testing.
// 32-bits address & data bus.

#include <memory>
#include <cstring>
#include "wbconsole.h"
#include "colors.h"

#define STDOUTSZ 256
#define DEVICESZ 1024

// -----------------------------------------------------------------------------
// Constructor.
WBCONSOLE::WBCONSOLE(const uint32_t base_addr) : m_stdout(STDOUTSZ, 0) {
        m_base_addr = base_addr;
        m_delay_cnt = 0;
        m_buff_ptr  = 0;
}

// -----------------------------------------------------------------------------
// Destructor.
WBCONSOLE::~WBCONSOLE() {
}

// -----------------------------------------------------------------------------
// Execute model: read/write operations.
void WBCONSOLE::operator()(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                           const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                           uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o) {
        /*
         * Memory map:
         * 0: input buffer. Word.
         * 4: flush buffer. Word.
         * 8: invalid address.
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
        //
        char value = wbs_dat_i & 0x000000FF;
        bool flush = false;
        // access device
        if (m_delay_cnt++ == 1) {
                switch (addr) {
                case 0:
                        if (wbs_we_i and wbs_sel_i == 0xF) {
                                // WARNING: no errors in case of buffer overflow.
                                m_stdout[m_buff_ptr++] = value;
                                flush                  = value == '\n';
                        }
                        wbs_ack_o = 1;
                        break;
                case 4:
                        if (wbs_we_i and wbs_sel_i == 0xF) {
                                m_buff_ptr = 0;
                                flush      = true;
                        }
                        wbs_ack_o  = 1;
                        break;
                default:
                        wbs_err_o = true;
                        fprintf(stderr, ANSI_COLOR_RED "[WBCONSOLE] Invalid bus address: 0x%08X\n" ANSI_COLOR_RESET, wbs_addr_i);
                        break;
                }

                if (flush) {
                        // write a null character, print data, reset pointer for the next write.
                        m_stdout[m_buff_ptr] = 0;;
                        printf("%s", m_stdout.data());
                        m_buff_ptr = 0;
                }
                m_delay_cnt = 0;
        }
}
