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
#include "colors.h"

#define SYSCALL  64
// TODO: read this variables from the ELF file.
#define TOHOST   0x20001000u
#define FROMHOST 0x20001040u

// -----------------------------------------------------------------------------
// The testbench
class ALGOLTB: public Testbench<VAlgol> {
public:
        // -----------------------------------------------------------------------------
        // Testbench constructor
        ALGOLTB(double frequency, double timescale=1e-9): Testbench(frequency, timescale) {}

        // -----------------------------------------------------------------------------
        // Print exit message
        uint32_t PrintExitMessage(const bool ok, const uint32_t time, const unsigned long max_time) const {
                uint32_t exit_code;
                if (ok) {
                        printf(ANSI_COLOR_GREEN "Simulation done. Time %u\n" ANSI_COLOR_RESET, time);
                        exit_code = 0;
                } else if (time < max_time) {
                        printf(ANSI_COLOR_RED "Simulation error. Exit code: %08X. Time: %u\n" ANSI_COLOR_RESET, m_core->wbm_mem_dat_o, time);
                        exit_code = 1;
                } else {
                        printf(ANSI_COLOR_MAGENTA "Simulation error. Timeout. Time: %u\n" ANSI_COLOR_RESET, time);
                        exit_code = 2;
                }
                return exit_code;
        }

        // -----------------------------------------------------------------------------
        // check for syscall
        bool CheckTOHOST(const bool benchmark, WBMEMORY &memory, bool &ok) const {
                // tohost should live in RAM1: use mem_1 port.
                const bool transaction = m_core->wbm_mem_cyc_o and m_core->wbm_mem_stb_o;
                const bool isTH        = m_core->wbm_mem_addr_o == TOHOST;
                bool       _exit       = false;
                if (isTH and transaction and m_core->wbm_mem_we_o and m_core->wbm_mem_ack_i) {
                        ok    = m_core->wbm_mem_dat_o == 1;
                        _exit = ok;
                        if (!ok) {
                                _exit = !benchmark;
                                if (benchmark) {
                                        // check for syscall
                                        const uint32_t data0 = m_core->wbm_mem_dat_o >> 2; // byte2word
                                        const uint32_t data1 = data0 + 2;                    // data is 64-bit aligned.
                                        if (memory[data0] == SYSCALL and memory[data1] == 1) {
                                                memory[FROMHOST >> 2] = 1;
                                                SyscallPrint(memory, data0);
                                        } else {
                                                _exit = true;
                                        }
                                }
                        }
                }
                return _exit;
        }
        // -----------------------------------------------------------------------------
        // For benchmarks, prints data from syscall 64.
        void SyscallPrint(WBMEMORY &memory, const uint32_t base_addr) const {
                const uint32_t data_addr = memory[base_addr + 4];
                const uint32_t size      = memory[base_addr + 6];
                for (uint32_t ii = 0; ii < size; ii += 4) {
                        // the data_addr must be 32-bit aligned, so no need to check the lower boundary.
                        const uint32_t addr        = data_addr + ii;
                        const uint32_t data        = memory[addr >> 2];
                        const uint32_t addr_masked = addr & 0xfffffffc;
                        if (addr_masked < data_addr + size) printf("%c", data & 0xff);
                        if (addr_masked + 1 < data_addr + size) printf("%c", (data >> 8) & 0xff);
                        if (addr_masked + 2 < data_addr + size) printf("%c", (data >> 16) & 0xff);
                        if (addr_masked + 3 < data_addr + size) printf("%c", (data >> 24) & 0xff);
                }
        }

        // -----------------------------------------------------------------------------
        // Run the CPU model.
        int SimulateCore(const std::string &progfile, const std::string &bootfile, const unsigned long max_time=1000000L, const bool benchmark=false) {
                /*
                  This assumes a simulation memory of 128MB, with 64MB for Mregion, and 64MB for Uregion.
                  The boot address, in *.ini file must be the physical address of the 64MB Mregion, in this
                  case, 0x1C000000 (448 MB)
                 */
                const uint32_t MEMSZ    = 0x08000000; // 128 MB
                const uint32_t MEMSTART = 0x1C000000; // 448 MB
                const std::unique_ptr<WBMEMORY> memory_ptr(new WBMEMORY(MEMSTART, MEMSZ >> 2));
                WBMEMORY &memory = *memory_ptr;
                if (!bootfile.empty()){
                        printf(ANSI_COLOR_YELLOW "Loading bootstrap: %s\n" ANSI_COLOR_RESET, bootfile.c_str());
                        memory.Load(bootfile);
                }
                memory.Load(progfile);

                // initial values for unused ports
                m_core->xinterrupts_i = 0;

                bool ok = false;
                printf(ANSI_COLOR_YELLOW "Executing file: %s\n" ANSI_COLOR_RESET, progfile.c_str());
                for (; getTime() < max_time;) {
                        Tick();
                        auto mem1bad = memory(m_core->wbm_mem_addr_o, m_core->wbm_mem_dat_o, m_core->wbm_mem_sel_o, m_core->wbm_mem_cyc_o, m_core->wbm_mem_stb_o,
                                              m_core->wbm_mem_we_o, m_core->wbm_mem_dat_i, m_core->wbm_mem_ack_i, m_core->wbm_mem_err_i);
                        if (mem1bad or CheckTOHOST(benchmark, memory, ok))
                                break;
                }
                Tick();
                return PrintExitMessage(ok, getTime(), max_time);
         }
};

// -----------------------------------------------------------------------------
// Basic help
void PrintHelp() {
        printf("Algol Verilator model.\n");
        printf("Usage:\n");
        printf("\tAlgol.exe --frequency <core frequency> --timeout <max simulation time> --file <filename> [--boot <filename>]"
               "[--benchmark] [--trace] [--trace-directory <trace directory>]\n");
}

// -----------------------------------------------------------------------------
// Main
int main(int argc, char **argv) {
        INPUTPARSER input(argc, argv);
        const std::string &s_progfile  = input.GetCmdOption("--file");
        const std::string &s_bootfile  = input.GetCmdOption("--boot");
        const std::string &s_frequency = input.GetCmdOption("--frequency");
        const std::string &s_timeout   = input.GetCmdOption("--timeout");
        const std::string &s_trace_dir = input.GetCmdOption("--trace-directory");
        const bool benchmark           = input.CmdOptionExist("--benchmark");
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
        int result = tb->SimulateCore(s_progfile, s_bootfile, timeout, benchmark);

        return result;
}
