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
#include "wbconsole.h"
#include "testbench.h"
#include "inputparser.h"
#include "colors.h"

// Use short names for the core signals
#define wbm_addr_o m_core->wbm_addr_o
#define wbm_dat_o  m_core->wbm_dat_o
#define wbm_sel_o  m_core->wbm_sel_o
#define wbm_cyc_o  m_core->wbm_cyc_o
#define wbm_stb_o  m_core->wbm_stb_o
#define wbm_we_o   m_core->wbm_we_o
#define wbm_dat_i  m_core->wbm_dat_i
#define wbm_ack_i  m_core->wbm_ack_i
#define wbm_err_i  m_core->wbm_err_i
#define xint_meip  m_core->xint_meip_i
#define xint_mtip  m_core->xint_mtip_i
#define xint_msip  m_core->xint_msip_i

// Define parameters for RAM
#define MEMSTART 0x80000000u    // Initial address
#define MEMSZ    0x08000000u    // size: 128 MB

// syscall (benchmarks)
#define SYSCALL  64
#define TOHOST   0x80001000u  // This 'section' is aligned to 4KB to the previous section: init code.
#define FROMHOST 0x80001040u

// Device address list
#define CONSOLE_START 0x10000000u

// -----------------------------------------------------------------------------
// The testbench
class ALGOLTB: public Testbench<VAlgol> {
private:
        uint32_t m_exitCode;
public:
        // -----------------------------------------------------------------------------
        // Testbench constructor
        ALGOLTB(double frequency, double timescale=1e-9): Testbench(frequency, timescale), m_exitCode(-1) {}
        // -----------------------------------------------------------------------------
        // Print exit message
        uint32_t PrintExitMessage(const bool ok, const uint32_t time, const unsigned long max_time) const {
                uint32_t exit_code;
                if (ok) {
                        printf(ANSI_COLOR_GREEN "Simulation done. Time %u\n" ANSI_COLOR_RESET, time);
                        exit_code = 0;
                } else if (time < max_time) {
                        printf(ANSI_COLOR_RED "Simulation error. Exit code: %08X. Time: %u\n" ANSI_COLOR_RESET, m_exitCode, time);
                        exit_code = 1;
                } else {
                        printf(ANSI_COLOR_MAGENTA "Simulation error. Timeout. Time: %u\n" ANSI_COLOR_RESET, time);
                        exit_code = 2;
                }
                return exit_code;
        }
        // -----------------------------------------------------------------------------
        // check for syscall
        bool CheckTOHOST(WBMEMORY &memory, bool &ok) const {
                // Check first for TH == 1. For benchmarks, is impossible to be a valid address for syscalls
                // because it must be a pointer to valid memory, and 0x01 is not valid memory for this testbench:
                // Simulation memory is in the upper 2GB region.
                const bool isTHWrite = wbm_cyc_o and wbm_stb_o and (wbm_addr_o == TOHOST) and wbm_we_o and wbm_ack_i;
                bool       _exit     = false;
                if (isTHWrite) {
                        bool isPtr = (wbm_dat_o - MEMSTART) <= MEMSZ;
                        _exit      = wbm_dat_o == 1 || not isPtr;
                        ok         = wbm_dat_o == 1;
                        if (not _exit) {
                                const uint32_t data0 = wbm_dat_o >> 2; // byte2word
                                const uint32_t data1 = data0 + 2;      // data is 64-bit aligned.
                                if (memory[data0] == SYSCALL and memory[data1] == 1) {
                                        memory[FROMHOST >> 2] = 1;
                                        SyscallPrint(memory, data0);
                                } else {
                                        _exit = true;
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
        // Timeout for I/O devices
        void IOtimeout() {
                const uint32_t MAX_TIMEOUT  = 256;
                static uint32_t timeout_cnt = 0;

                if (wbm_cyc_o and wbm_stb_o) {
                        if (timeout_cnt++ == MAX_TIMEOUT and not (wbm_ack_i or wbm_err_i)) {
                                wbm_err_i = true;
                                fprintf(stderr, ANSI_COLOR_RED "[ALGOLTB] Access to unimplemented address: 0x%08X. Timeout: %d\n" ANSI_COLOR_RESET, wbm_addr_o, timeout_cnt);
                        }
                } else {
                        timeout_cnt = 0;
                }
        }
        // -----------------------------------------------------------------------------
        // Run the CPU model.
        int SimulateCore(const std::string &progfile, const unsigned long max_time=1000000L) {
                const std::unique_ptr<WBMEMORY> memory_ptr(new WBMEMORY(MEMSTART, MEMSZ >> 2));
                WBMEMORY &memory = *memory_ptr;
                memory.Load(progfile);
                // Create devices
                const std::unique_ptr<WBCONSOLE> stdout_ptr(new WBCONSOLE(CONSOLE_START));
                WBCONSOLE &console = *stdout_ptr;

                // initial values for unused ports
                xint_meip = false;
                xint_msip = false;
                xint_mtip = false;

                bool ok = false;
                printf(ANSI_COLOR_YELLOW "Executing file: %s\n" ANSI_COLOR_RESET, progfile.c_str());
                for (; getTime() < max_time;) {
                        Tick();
                        wbm_ack_i = false;  // set default state for ack/err
                        wbm_err_i = false;
                        // simulate memory
                        memory(wbm_addr_o, wbm_dat_o, wbm_sel_o, wbm_cyc_o, wbm_stb_o, wbm_we_o,
                               wbm_dat_i, wbm_ack_i, wbm_err_i);
                        if (CheckTOHOST(memory, ok)) {
                                m_exitCode = wbm_dat_o;
                                break;
                        }
                        // simulate devices
                        console(wbm_addr_o, wbm_dat_o, wbm_sel_o, wbm_cyc_o, wbm_stb_o, wbm_we_o,
                                wbm_dat_i, wbm_ack_i, wbm_err_i);
                        // timeout, in case of unknown device.
                        IOtimeout();
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
        printf("\tAlgol.exe --frequency <core frequency> --timeout <max simulation time> --file <filename> "
               "[--trace] [--trace-directory <trace directory>]\n");
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
