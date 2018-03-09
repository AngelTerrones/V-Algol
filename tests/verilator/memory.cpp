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
#include <fstream>
#include <iostream>
#include "aelf.h"
#include "memory.h"

// -----------------------------------------------------------------------------
// Constructor.
WBMEMORY::WBMEMORY(const uint32_t base_addr, const uint32_t nwords, const uint32_t delay) {
        uint32_t next;
        // get the address mask, and memory size (power of 2)
        for(next = 1; next < nwords; next <<= 1);
        m_size      = next;
        m_mask      = next - 1;
        m_memory    = new std::vector<uint32_t>(m_size, 0);
        m_delay     = delay;
        m_delay_cnt = 0;
        m_base_addr = base_addr;
}

// -----------------------------------------------------------------------------
// Destructor.
WBMEMORY::~WBMEMORY(){
        m_memory->clear();  // (._.') ??
        delete m_memory;
}

// -----------------------------------------------------------------------------
// Load/initialize memory.
void WBMEMORY::Load(const std::string &filename) {
        // WARNING: this will silently ignore loads if the memory is not large enough to hold the data.
        uint32_t     entry;
        ELFSECTION **section;
        const char  *fn       = filename.data();
        char        *mem_ptr  = reinterpret_cast<char *>(m_memory->data());
        uint32_t     mem_size = m_size * sizeof(uint32_t);

        if (not isELF(fn)){
                std::cerr << "Invalid elf: " << filename << std::endl;
                exit(EXIT_FAILURE);
        }

        elfread(fn, entry, section);
        for (int s = 0; section[s] != NULL; s++){
                if (section[s]->m_start >= m_base_addr && section[s]->m_start + section[s]->m_len <= m_base_addr + mem_size){
                        uint32_t offset = section[s]->m_start - m_base_addr;
                        memcpy(mem_ptr + offset, section[s]->m_data, section[s]->m_len);
                }
        }
        delete[] section;
}

// -----------------------------------------------------------------------------
// Execute model: read/write operations.
void WBMEMORY::operator()(const uint32_t wbs_addr_i, const uint32_t wbs_dat_i, const uint8_t wbs_sel_i,
                          const uint8_t wbs_cyc_i, const uint8_t wbs_stb_i, const uint8_t wbs_we_i,
                          uint32_t &wbs_data_o, uint8_t &wbs_ack_o, uint8_t &wbs_err_o){
        // assume this is called every clock cycle
        wbs_data_o = 0xdeadf00d;
        wbs_ack_o  = 0;
        wbs_err_o  = 0;

        auto addr = (wbs_addr_i >> 2) & m_mask; // Byte address to word address.

        if (wbs_cyc_i and wbs_stb_i){
                if (m_delay_cnt++ == m_delay){
                        if (wbs_we_i){
                                auto b0 = (wbs_sel_i & 0x01 ? wbs_dat_i : (*m_memory)[addr]) & 0x000000ff;
                                auto b1 = (wbs_sel_i & 0x02 ? wbs_dat_i : (*m_memory)[addr]) & 0x0000ff00;
                                auto b2 = (wbs_sel_i & 0x04 ? wbs_dat_i : (*m_memory)[addr]) & 0x00ff0000;
                                auto b3 = (wbs_sel_i & 0x08 ? wbs_dat_i : (*m_memory)[addr]) & 0xff000000;
                                (*m_memory)[addr] = b3 | b2 | b1 | b0;
                        }
                        wbs_data_o  = (*m_memory)[addr];
                        wbs_ack_o   = 1;
                        wbs_err_o   = 0;
                        m_delay_cnt = 0;
                }
        }
}

// -----------------------------------------------------------------------------
uint32_t &WBMEMORY::operator[](const uint32_t addr){
        return (*m_memory)[addr];
}
