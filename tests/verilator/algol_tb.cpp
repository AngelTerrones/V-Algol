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

// File: algol_tb.cpp
// Testbench for the V-ALGOL RISC-V CPU core.

#include <assert.h>
#include <cstdint>
#include <memory>
#include <string>
#include <iostream>
#include <verilated.h>

#include "Valgol.h"
#include "testbench.h"
#include "memory.h"

#define TOHOST 0x1000

//
class ALGOLTB: public Testbench<Valgol>{
public:
        ALGOLTB(double frequency, double timescale=1e-9): Testbench(frequency, timescale){}

        int SimulateCore(std::string &progfile, unsigned long max_time=1000000L){
                std::unique_ptr<WBMEMORY> memory_ptr(new WBMEMORY(0x20000));
                WBMEMORY &memory = *memory_ptr;
                memory.Load(progfile);

                // initial values for unused ports
                m_core->xint_meip_i = 0;
                m_core->xint_mtip_i = 0;
                m_core->xint_msip_i = 0;

                bool ok = false;

                std::cout << "Executing file: " << progfile << std::endl;
                for(; getTime() < max_time;){
                        Tick();
                        memory(m_core->wbm_addr_o, m_core->wbm_dat_o, m_core->wbm_sel_o, m_core->wbm_cyc_o, m_core->wbm_stb_o,
                               m_core->wbm_we_o, m_core->wbm_dat_i, m_core->wbm_ack_i, m_core->wbm_err_i);

                        // check for TOHOST  asd
                        if(m_core->wbm_addr_o == TOHOST and m_core->wbm_cyc_o and m_core->wbm_stb_o and m_core->wbm_we_o){
                                ok = m_core->wbm_dat_o == 1;
                                break;
                        }
                }
                uint32_t time = getTime();
                if (ok){
                        printf("Simulation done. Time %u\n", time);
                        return 0;
                }else if(time < max_time){
                        printf("Simulation error. Exit code: %08X. Time: %u\n", m_core->wbm_dat_o, time);
                        return m_core->wbm_dat_o;
                }else{
                        printf("Simulation error. Timeout. Time: %u\n", time);
                        return 1;
                }
         }
};

//
void parseCommandLine(int argc, char **argv, std::string &elffile)
{
        const std::string helpMessage = "\nUsage: algol <binary file>";

        if(argc == 1){
                std::cerr << helpMessage << std::endl;
                exit(-1);
        }

        elffile = argv[1];

        // check for extra arguments: abort if > 1
        argc -= 2;
        argv += 2;
        if(argc != 0){
                std::cerr << helpMessage << std::endl;
                for(int ii = 0; ii < argc; ii++)
                        std::cerr << "Unknown parameter: " << argv[ii] << std::endl;
                exit(-1);
        }
}

// Main
int main(int argc, char **argv){
        Verilated::commandArgs(argc, argv);
        std::string progfile;
        parseCommandLine(argc, argv, progfile);
        std::unique_ptr<ALGOLTB> tb(new ALGOLTB(10e6));
        tb->OpenTrace("algol.vcd");
        tb->Reset();
        int result = tb->SimulateCore(progfile);

        return result;
}
