/*
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
 */

#include <chrono>
#include <atomic>
#include <signal.h>
#include "aelf.h"
#include "coretb.h"
#include "defines.h"

static std::atomic_bool quit(false);

// -----------------------------------------------------------------------------
void intHandler(int signo){
        printf("\r[SIGNAL] Quit...\n");
        fflush(stdout);
        quit = true;
        signal(SIGINT, SIG_DFL); // just in case...
}
// -----------------------------------------------------------------------------
CORETB::CORETB() : Testbench(TBFREQ, TBTS), m_exitCode(-1) {
}
// -----------------------------------------------------------------------------
int CORETB::SimulateCore(const std::string &progfile, const unsigned long max_time, const std::string &s_signature) {
        bool ok        = false;
        bool notimeout = max_time == 0;
        // Initial values
        m_top->xint_meip = 0;
        m_top->xint_mtip = 0;
        m_top->xint_msip = 0;
        // -------------------------------------------------------------
        LoadMemory(progfile);
        m_tohost          = getSymbol(progfile.data(), "tohost");
        m_fromhost        = getSymbol(progfile.data(), "fromhost");
        if (!s_signature.empty()) {
                m_begin_signature = getSymbol(progfile.data(), "begin_signature");
                m_end_signature   = getSymbol(progfile.data(), "end_signature");
        }
        Reset();
        while ((getTime() <= max_time || notimeout) && !Verilated::gotFinish() && !quit) {
                Tick();
                if (CheckTOHOST(ok))
                        break;
                CheckInterrupts();
        }
        // -------------------------------------------------------------
        Tick();
        Tick();
        Tick();
        if (!s_signature.empty())
                DumpSignature(s_signature);
        return PrintExitMessage(ok, max_time);
}
// -----------------------------------------------------------------------------
uint32_t CORETB::PrintExitMessage(const bool ok, const unsigned long max_time) {
        uint32_t exit_code;
        if (ok){
                printf(ANSI_COLOR_GREEN "Simulation done. Time %u\n" ANSI_COLOR_RESET, getTime());
                exit_code = 0;
        } else if (getTime() < max_time || max_time == 0) {
                printf(ANSI_COLOR_RED "Simulation error. Exit code: %08X. Time: %u\n" ANSI_COLOR_RESET, m_exitCode, getTime());
                exit_code = 1;
        } else {
                printf(ANSI_COLOR_MAGENTA "Simulation error. Timeout. Time: %u\n" ANSI_COLOR_RESET, getTime());
                exit_code = 2;
        }
        return exit_code;
}
// -----------------------------------------------------------------------------
bool CORETB::CheckTOHOST(bool &ok) {
        svSetScope(svGetScopeFromName("TOP.top.memory")); // Set the scope before using DPI functions
        uint32_t tohost = ram_v_dpi_read_word(m_tohost);
        if (tohost == 0)
                return false;
        bool isPtr = (tohost - MEMSTART) <= MEMSZ;
        bool _exit = tohost == 1 || not isPtr;
        ok         = tohost == 1;
        m_exitCode = tohost;
        if (not _exit) {
                const uint32_t data0 = tohost;
                const uint32_t data1 = data0 + 8; // 64-bit aligned
                if (ram_v_dpi_read_word(data0) == SYSCALL and ram_v_dpi_read_word(data1) == 1) {
                        SyscallPrint(data0);
                        ram_v_dpi_write_word(m_fromhost, 1); // reset to inital state
                        ram_v_dpi_write_word(m_tohost, 0);   // reset to inital state
                } else {
                        _exit = true;
                }
        }
        return _exit;
}
// -----------------------------------------------------------------------------
void CORETB::CheckInterrupts() {
        svSetScope(svGetScopeFromName("TOP.top.memory")); // Set the scope before using DPI functions
        m_top->xint_meip = ram_v_dpi_read_word(XINT_E) != 0;
        m_top->xint_mtip = ram_v_dpi_read_word(XINT_T) != 0;
        m_top->xint_msip = ram_v_dpi_read_word(XINT_S) != 0;
}
// -----------------------------------------------------------------------------
void CORETB::SyscallPrint(const uint32_t base_addr) const {
        svSetScope(svGetScopeFromName("TOP.top.memory")); // Set the scope before using DPI functions
        const uint64_t data_addr = ram_v_dpi_read_word(base_addr + 16); // dword 2: offset = 16 bytes.
        const uint64_t size      = ram_v_dpi_read_word(base_addr + 24); // dword 3: offset = 24 bytes.
        for (uint32_t ii = 0; ii < size; ii++) {
                printf("%c", ram_v_dpi_read_byte(data_addr + ii));
        }
}
// -----------------------------------------------------------------------------
void CORETB::LoadMemory(const std::string &progfile) {
        svSetScope(svGetScopeFromName("TOP.top.memory"));
        ram_v_dpi_load(progfile.data());
        printf(ANSI_COLOR_YELLOW "Executing file: %s\n" ANSI_COLOR_RESET, progfile.c_str());
}
// -----------------------------------------------------------------------------
void CORETB::DumpSignature(const std::string &signature) {
        FILE *fp = fopen(signature.data(), "w");
        if (fp == NULL) {
                fprintf(stderr, ANSI_COLOR_RED "Unable to open the signature file. \n" ANSI_COLOR_RESET);
                return;
        }
        // Signature from riscv-compliance is N lines of 4 words per line.
        // MSB ---- LSB
        for (uint32_t idx = m_begin_signature; idx < m_end_signature; idx = idx + 16) {
                for (uint32_t offset = 3; offset != 0xffffffff; offset--)
                        fprintf(fp, "%08x", ram_v_dpi_read_word(idx + (4*offset)));
                fprintf(fp, "\n");
        }
        fclose(fp);
}
