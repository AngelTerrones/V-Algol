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

// File: testbench.cpp
// Testbench for the RISC-V CPU core.

#include <sys/stat.h>
#include <vector>
#include <string>
#include <iostream>
#include <algorithm>
#include <verilated.h>
#include "Vtop.h"
#include "Vtop__Dpi.h"
#include "aelf.h"
#include "testbench.h"
// -----------------------------------------------------------------------------
#if defined(__WIN32__) || defined(__MINGW32__)
#define mkdir(a, b) mkdir(a) /* mkdir command on Win32 does not support file permissions */
#endif
// -----------------------------------------------------------------------------
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"
// -----------------------------------------------------------------------------
// Fixed parameters from TOP.v
#define TBFREQ   100e6
#define TBTS     1e-9
#define MEMSTART 0x80000000u    // Initial address
#define MEMSZ    0x01000000u    // size: 16 MB
// -----------------------------------------------------------------------------
#define MEMORY m_top->top->memory->mem
// syscall (benchmarks)
#define SYSCALL  64
#define TOHOST   0x80001000u
#define FROMHOST 0x80001040u

// -----------------------------------------------------------------------------
// DPI function
void c_load_mem(const svOpenArrayHandle mem_ptr, const char *filename) {
        ELFSECTION **section;
        uint8_t     *mem = static_cast<uint8_t *>(svGetArrayPtr(mem_ptr));
        if (not isELF(filename)) {
                fprintf(stderr, ANSI_COLOR_RED "[CORETB] Invalid elf: %s\n" ANSI_COLOR_RESET, filename);
                exit(EXIT_FAILURE);
        }
        elfread(filename, section);
        for (int s = 0; section[s] != nullptr; s++){
                auto start = section[s]->m_start;
                auto end   = section[s]->m_start + section[s]->m_len;
                if (start >= MEMSTART && end < MEMSTART + MEMSZ) {
                        uint32_t offset = section[s]->m_start - MEMSTART;
                        std::memcpy(mem + offset, section[s]->m_data, section[s]->m_len);
                } else {
                        fprintf(stderr, ANSI_COLOR_MAGENTA "[CORETB] WARNING: unable to fit section %d. Start: 0x%08x, End: 0x%08x\n" ANSI_COLOR_RESET, s, start, end);
                }
        }
        delete [] section;
}
// -----------------------------------------------------------------------------
// testbench
class CORETB: public Testbench<Vtop> {
private:
        uint32_t m_exitCode;
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
        bool CheckTOHOST(bool &ok) {
                uint32_t tohost = dpi_read_word(TOHOST);
                if (tohost == 0)
                        return false;
                bool isPtr = (tohost - MEMSTART) <= MEMSZ;
                bool _exit = tohost == 1 || not isPtr;
                ok         = tohost == 1;
                m_exitCode = tohost;
                if (not _exit) {
                        const uint32_t data0 = tohost;
                        const uint32_t data1 = data0 + 8; // 64-bit aligned
                        if (dpi_read_word(data0) == SYSCALL and dpi_read_word(data1) == 1) {
                                SyscallPrint(data0);
                                dpi_write_word(FROMHOST, 1); // reset to inital state
                                dpi_write_word(TOHOST, 0);   // reset to inital state
                        } else {
                                _exit = true;
                        }
                }
                return _exit;
        }
        // -----------------------------------------------------------------------------
        // For benchmarks, prints data from syscall 64.
        void SyscallPrint(const uint32_t base_addr) const {
                const uint64_t data_addr = dpi_read_word(base_addr + 16); // dword 2: offset = 16 bytes.
                const uint64_t size      = dpi_read_word(base_addr + 24); // dword 3: offset = 24 bytes.
                for (uint32_t ii = 0; ii < size; ii++) {
                        printf("%c", dpi_read_byte(data_addr + ii));
                }
        }
public:
        // -----------------------------------------------------------------------------
        // Testbench constructor
        CORETB(): Testbench(TBFREQ, TBTS), m_exitCode(-1) {}
        // -----------------------------------------------------------------------------
        // Run the CPU model.
        int SimulateCore(const std::string &progfile, const unsigned long max_time=1000000L){
                bool ok = false;
                dpi_load_mem(progfile.data());
                printf(ANSI_COLOR_YELLOW "Executing file: %s\n" ANSI_COLOR_RESET, progfile.c_str());
                for (; getTime() < max_time;) {
                        Tick();
                        if (CheckTOHOST(ok))
                                break;
                }
                Tick();
                return PrintExitMessage(ok, getTime(), max_time);
        }
};

// -----------------------------------------------------------------------------
//  from https://stackoverflow.com/questions/865668/how-to-parse-command-line-arguments-in-c
//  author: iain
class INPUTPARSER {
public:
        INPUTPARSER(int &argc, char **argv) {
                for (int ii = 0; ii < argc; ii++)
                        m_tokens.push_back(std::string(argv[ii]));
        }
        const std::string &GetCmdOption(const std::string &option) const {
                std::vector<std::string>::const_iterator itr;
                itr = std::find(m_tokens.begin(), m_tokens.end(), option);
                if (itr != m_tokens.end() && ++itr != m_tokens.end())
                        return *itr;
                static const std::string empty("");
                return empty;
        }
        bool CmdOptionExist(const std::string &option) const {
                return std::find(m_tokens.begin(), m_tokens.end(), option) != m_tokens.end();
        }
private:
        std::vector<std::string> m_tokens;
};

// -----------------------------------------------------------------------------
// Basic help
void PrintHelp() {
        printf("RISC-V CPU Verilator model.\n");
        printf("Usage:\n");
        printf("\t" EXE ".exe --file <ELF file> --timeout <max simulation time> [--trace] [--help]\n");
}

// -----------------------------------------------------------------------------
// Main
int main(int argc, char **argv) {
        INPUTPARSER input(argc, argv);
        const std::string &s_progfile = input.GetCmdOption("--file");
        const std::string &s_timeout  = input.GetCmdOption("--timeout");
        const bool trace              = input.CmdOptionExist("--trace");
        const bool help               = input.CmdOptionExist("--help");

        if (s_progfile.empty() or s_timeout.empty() or help) {
                PrintHelp();
                exit(EXIT_FAILURE);
        }
        const uint32_t timeout   = std::stoul(s_timeout);
        std::unique_ptr<CORETB> tb(new CORETB());
#ifdef DEBUG
        Verilated::scopesDump();  // this shit should be in the fucking manual (verilator)
#endif
        svSetScope(svGetScopeFromName("TOP.top.memory"));
        if (trace) {
                int status = mkdir("build/vcd", S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
                if (status && errno != EEXIST) {
                        perror("[OS]");
                        fprintf(stderr, ANSI_COLOR_RED "[CORETB] Unable to create VCD folder\n" ANSI_COLOR_RESET);
                        exit(EXIT_FAILURE);
                }
                tb->OpenTrace("build/vcd/trace.vcd");
        }
        tb->Reset();
        return tb->SimulateCore(s_progfile, timeout);
}
// -----------------------------------------------------------------------------
