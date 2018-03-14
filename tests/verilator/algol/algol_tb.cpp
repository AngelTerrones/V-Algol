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
// Testbench for the Algol RISC-V CPU core.

#include <verilated.h>
#include "VAlgol.h"
#include "wbmemory.h"
#include "testbench.h"
#include "inputparser.h"

#define TOHOST 0x1000
#define FROMHOST 0x1040
#define SYSCALL 64

// -----------------------------------------------------------------------------
// The testbench
class ALGOLTB: public Testbench<VAlgol> {
public:
        // -----------------------------------------------------------------------------
        // Testbench constructor
        ALGOLTB(double frequency, double timescale=1e-9): Testbench(frequency, timescale) {}

        // -----------------------------------------------------------------------------
        // For benchmarks, prints data from syscall 64.
        void SyscallPrint(WBMEMORY &memory, const uint32_t base_addr) {
                const uint32_t data_addr = memory[base_addr + 4];
                const uint32_t size      = memory[base_addr + 6];
                for (uint32_t ii = 0; ii < size; ii += 4) {
                        // the data_addr must be 32-bit aligned, so no need to check the lower boundary.
                        const uint32_t addr        = data_addr + ii;
                        const uint32_t data        = memory[addr >> 2];
                        const uint32_t addr_masked = addr & 0xfffffffc;
                        if (addr_masked <= data_addr + size) printf("%c", data & 0xff);
                        if (addr_masked + 1 <= data_addr + size) printf("%c", (data >> 8) & 0xff);
                        if (addr_masked + 2 <= data_addr + size) printf("%c", (data >> 16) & 0xff);
                        if (addr_masked + 3 <= data_addr + size) printf("%c", (data >> 24) & 0xff);
                }
                printf("\n");
        }

        // -----------------------------------------------------------------------------
        // Run the CPU model.
        int SimulateCore(const std::string &progfile, unsigned long max_time=1000000L) {
                std::unique_ptr<WBMEMORY> memory_ptr(new WBMEMORY(0x0, 0x20000));
                WBMEMORY &memory = *memory_ptr;
                memory.Load(progfile);

                // initial values for unused ports
                m_core->xinterrupts_i = 0;

                bool ok = false;
                printf("\nExecuting file: %s\n", progfile.c_str());
                printf("--------------------------------------------------------------------------------\n");
                for (; getTime() < max_time;) {
                        Tick();
                        memory(m_core->wbm_mem_addr_o, m_core->wbm_mem_dat_o, m_core->wbm_mem_sel_o, m_core->wbm_mem_cyc_o, m_core->wbm_mem_stb_o,
                               m_core->wbm_mem_we_o, m_core->wbm_mem_dat_i, m_core->wbm_mem_ack_i, m_core->wbm_mem_err_i);

                        // check for TOHOST
                        if (m_core->wbm_mem_addr_o == TOHOST and m_core->wbm_mem_cyc_o and m_core->wbm_mem_stb_o and m_core->wbm_mem_we_o and m_core->wbm_mem_ack_i) {
                                if (m_core->wbm_mem_dat_o != 1) {
                                        // check for syscalls (used by benchmarks)
                                        const uint32_t data0 = m_core->wbm_mem_dat_o >> 2; // byte2word
                                        const uint32_t data1 = data0 + 2;              // data is 64-bit aligned.
                                        if (memory[data0] == SYSCALL and memory[data1] == 1) {
                                                memory[FROMHOST >> 2] = 1;
                                                SyscallPrint(memory, data0);
                                        } else {
                                                // exit code != 0.
                                                break;
                                        }
                                } else {
                                        ok = true;
                                        break;
                                }
                        }
                }
                Tick();
                uint32_t time = getTime();
                uint32_t exit_code = 0;
                if (ok) {
                        printf("Simulation done. Time %u\n", time);
                        exit_code = 0;
                } else if (time < max_time) {
                        printf("Simulation error. Exit code: %08X. Time: %u\n", m_core->wbm_mem_dat_o, time);
                        exit_code = 1;
                } else {
                        printf("Simulation error. Timeout. Time: %u\n", time);
                        exit_code = 2;
                }
                return exit_code;
         }
};

// -----------------------------------------------------------------------------
// Basic help
void PrintHelp() {
        printf("Algol Verilator model.\n");
        printf("Usage:\n");
        printf("\tAlgol.exe --frequency <core frequency> --timeout <max simulation time> --file <filename> [--trace] [--trace-directory <trace directory>]\n");
}

// -----------------------------------------------------------------------------
// Main
int main(int argc, char **argv) {
        INPUTPARSER input(argc, argv);
        const std::string &s_progfile  = input.GetCmdOption("--file");
        const std::string &s_frequency = input.GetCmdOption("--frequency");
        const std::string &s_timeout   = input.GetCmdOption("--timeout");
        const std::string &s_trace_dir = input.GetCmdOption("--trace-directory");
        const bool trace               = input.CmdOptionExist("--trace");
        const bool help                = input.CmdOptionExist("--help");

        if (s_progfile.empty() or s_frequency.empty() or s_timeout.empty() or help) {
                PrintHelp();
                exit(0);
        }
        const double frequency = std::stod(s_frequency);
        const uint32_t timeout = std::stoul(s_timeout);
        std::unique_ptr<ALGOLTB> tb(new ALGOLTB(frequency));
        if (trace) {
                std::string bf = s_progfile.substr(s_progfile.find_last_of("/\\") + 1);
                std::string::size_type const p(bf.find_last_of('.'));
                std::string binfile = bf.substr(0, p);
                std::string vcdfile = (s_trace_dir.empty() ? "." : s_trace_dir) + "/Algol_" + binfile + ".vcd";
                tb->OpenTrace(vcdfile.data());
        }
        tb->Reset();
        int result = tb->SimulateCore(s_progfile, timeout);

        return result;
}
