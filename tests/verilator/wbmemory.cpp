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

// File: memory.h
// Wishbone memory device.
// 32-bits address & data bus.

#include <memory>
#include <cstring>
#include "aelf.h"
#include "wbmemory.h"
#include "colors.h"

// -----------------------------------------------------------------------------
// Constructor.
WBMEMORY::WBMEMORY(const uint32_t base_addr, const uint32_t nwords, const uint32_t delay) {
        uint32_t next;
        // get the address mask, and memory size (power of 2)
        for (next = 1; next < nwords; next <<= 1);
        m_size      = next;
        m_mask      = next - 1;
        m_memory    = new std::vector<uint32_t>(m_size, 0);
        m_delay     = delay;
        m_delay_cnt = 0;
        m_base_addr = base_addr;
        printf(ANSI_COLOR_YELLOW "Memory size: 0x%08X bytes\n" ANSI_COLOR_RESET, uint32_t(m_memory->size() << 2));
}

// -----------------------------------------------------------------------------
// Destructor.
WBMEMORY::~WBMEMORY() {
        m_memory->clear();  // (._.') ??
        delete m_memory;
}

// -----------------------------------------------------------------------------
// Load/initialize memory.
void WBMEMORY::Load(const std::string &filename) {
        ELFSECTION **section;
        const char  *fn       = filename.data();
        char        *mem_ptr  = reinterpret_cast<char *>(m_memory->data());
        uint32_t     mem_size = m_size * sizeof(uint32_t);

        if (not isELF(fn)) {
                fprintf(stderr, ANSI_COLOR_RED "[WBMEMORY] Invalid elf: %s\n" ANSI_COLOR_RESET, filename.c_str());
                exit(EXIT_FAILURE);
        }

        elfread(fn, section);
        for (int s = 0; section[s] != nullptr; s++) {
                auto start = section[s]->m_start;
                auto end   = section[s]->m_start + section[s]->m_len;
                if (start >= m_base_addr && end <= m_base_addr + mem_size) {
                        uint32_t offset = section[s]->m_start - m_base_addr;
                        std::memcpy(mem_ptr + offset, section[s]->m_data, section[s]->m_len);
                } else {
                        fprintf(stderr, ANSI_COLOR_MAGENTA "[WBMEMORY] WARNING: unable to fit section %d. Start: 0x%08x, End: 0x%08x\n" ANSI_COLOR_RESET, s, start, end);
                }
        }
        delete[] section;
}

// -----------------------------------------------------------------------------
// Execute model: read/write operations.
// Return FALSE for normal operation, TRUE for critical error: out-of-bound access
void WBMEMORY::operator()(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                          const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o) {
        auto addr     = ((wbs_addr_i - m_base_addr) >> 2) & m_mask; // Byte address to word address.
        auto mem_size = m_size << 2;
        // check for access
        if (!(wbs_cyc_i && wbs_stb_i)){
                // Reset the counter: transaction have been aborted.
                m_delay_cnt = 0;
                return;
        }
        // check if the address is out of memory range.
        if (wbs_addr_i < m_base_addr || wbs_addr_i >= m_base_addr + mem_size)
                return;
        // Default state for memory
        wbs_data_o = 0xdeadf00d;
        wbs_ack_o  = 0;
        wbs_err_o  = 0;
        // access memory
        if (m_delay_cnt++ == m_delay) {
                if (wbs_we_i) {
                        auto b0 = (wbs_sel_i & 0x01 ? wbs_dat_i : (*m_memory)[addr]) & 0x000000ff;
                        auto b1 = (wbs_sel_i & 0x02 ? wbs_dat_i : (*m_memory)[addr]) & 0x0000ff00;
                        auto b2 = (wbs_sel_i & 0x04 ? wbs_dat_i : (*m_memory)[addr]) & 0x00ff0000;
                        auto b3 = (wbs_sel_i & 0x08 ? wbs_dat_i : (*m_memory)[addr]) & 0xff000000;
                        (*m_memory)[addr] = b3 | b2 | b1 | b0;
                }
                wbs_data_o  = (*m_memory)[addr];
                wbs_ack_o   = wbs_cyc_i && wbs_stb_i;
                wbs_err_o   = 0;
                m_delay_cnt = 0;
        }
}

// -----------------------------------------------------------------------------
uint32_t &WBMEMORY::operator[](const uint32_t addr) {
        // WARNING: addr is in word space. NOT BY
        const uint32_t _addr = addr - (m_base_addr >> 2);
        if (_addr >= m_size) {
                fprintf(stderr, ANSI_COLOR_RED "[WBMEMORY] Invalid access: 0x%08x\n" ANSI_COLOR_RESET, addr);
                exit(EXIT_FAILURE);
        }
        return (*m_memory)[_addr];
}
