// *****************************************************************************
// Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
// *****************************************************************************

#include <chrono>
#include <atomic>
#include <signal.h>
#include "coretb.h"
#include "defines.h"
#include "aelf.h"
#include "Valgolsoc_algolsoc.h"
#include "Valgolsoc_ram__Rf.h" // random name?

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
        m_mem = reinterpret_cast<uint8_t *>(m_top->algolsoc->ram0->mem);
        m_uartrx = 0;
}
// -----------------------------------------------------------------------------
int CORETB::SimulateCore(const std::string &progfile, const unsigned long max_time, const std::string &s_signature, bool use_uart) {
        bool ok        = false;
        bool notimeout = max_time == 0;
        // -------------------------------------------------------------
        m_top->uart_rx = 1;
        LoadMemory(progfile);
        if (!use_uart) {
                m_tohost   = getSymbol(progfile.data(), "tohost");
                m_fromhost = getSymbol(progfile.data(), "fromhost");
        }
        if (!s_signature.empty()) {
                m_begin_signature = getSymbol(progfile.data(), "begin_signature");
                m_end_signature   = getSymbol(progfile.data(), "end_signature");
        }
        Reset();
        while ((getTime() <= max_time || notimeout) && !Verilated::gotFinish() && !quit) {
                Tick();
                if (use_uart) {
                        UARTRx();
                        if (m_uartrx == 0xff) {
                                ok = true;
                                break;
                        }
                } else {
                        if (CheckTOHOST(ok))
                                break;
                }
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
void CORETB::UARTRx(){
        static uint8_t bitcnt = 0;
        static uint32_t clkdiv = 0xffffffff;

        if (bitcnt == 0) {
                if (!m_top->uart_tx) {
                        bitcnt = 10;
                        clkdiv = TBFREQ/(2 * BAUDRATE);
                }
        } else {
                if (--clkdiv == 0) {
                        if (bitcnt == 10) {
                                if (!m_top->uart_tx){
                                        bitcnt--;
                                        clkdiv = TBFREQ/BAUDRATE;
                                } else {
                                        bitcnt = 0;
                                }
                        } else if (bitcnt == 1) {
                                bitcnt = 0;
                                if (m_top->uart_tx) {
                                        printf("%c", m_uartrx);
                                }
                        } else {
                                m_uartrx = (m_uartrx >> 1) | (m_top->uart_tx << 7);
                                bitcnt--;
                                clkdiv = TBFREQ/BAUDRATE;
                        }
                }
        }
}
// -----------------------------------------------------------------------------
bool CORETB::CheckTOHOST(bool &ok) {
        uint32_t addr   = m_tohost - MEMSTART;
        uint32_t tohost = ((uint32_t *)m_mem)[addr >> 2];
        ok              = tohost == 1;
        m_exitCode      = tohost;
        if (tohost == 0)
                return false;
        return true;
}
// -----------------------------------------------------------------------------
void CORETB::LoadMemory(const std::string &progfile) {
        ELFSECTION **section;
        const char *filename = progfile.data();

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
                        std::memcpy(m_mem + offset, section[s]->m_data, section[s]->m_len);
                } else {
                        fprintf(stderr, ANSI_COLOR_MAGENTA "[CORETB] WARNING: unable to fit section %d. Start: 0x%08x, End: 0x%08x\n" ANSI_COLOR_RESET, s, start, end);
                }
        }
        delete [] section;
        printf(ANSI_COLOR_YELLOW "Executing file: %s\n" ANSI_COLOR_RESET, progfile.c_str());
}
// -----------------------------------------------------------------------------
void CORETB::DumpSignature(const std::string &signature) {
        FILE *fp = fopen(signature.data(), "w");
        if (fp == NULL) {
                fprintf(stderr, ANSI_COLOR_RED "Unable to open the signature file. \n" ANSI_COLOR_RESET);
                return;
        }
        // Signature from riscv-compliance: 1 word per line
        for (uint32_t idx = m_begin_signature; idx < m_end_signature; idx = idx + 4) {
                uint32_t addr = idx - MEMSTART;
                fprintf(fp, "%08x\n", ((uint32_t *)m_mem)[addr >> 2]); // FIXME ??
        }
        fclose(fp);
}
