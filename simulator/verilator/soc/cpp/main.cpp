/*
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
 */

#include <thread>
#include <sys/stat.h>
#include "coretb.h"
#include "defines.h"
#include "inputparser.h"

void printHelp() {
        printf("RISC-V CPU Verilator model.\n");
        printf("Usage:\n");
        printf("\t" EXE ".exe --file <ELF file> [--timeout <max time>] [--signature <signature file>] [--trace]\n");
        printf("\t" EXE ".exe --help\n");
}

// -----------------------------------------------------------------------------
// Main
int main(int argc, char **argv) {
        INPUTPARSER input(argc, argv);
        const std::string &s_progfile  = input.GetCmdOption("--file");
        const std::string &s_timeout   = input.GetCmdOption("--timeout");
        const std::string &s_signature = input.GetCmdOption("--signature");
        const bool         use_uart    = input.CmdOptionExist("--use-uart");
        const bool         trace       = input.CmdOptionExist("--trace");
        // help
        const bool         help        = input.CmdOptionExist("--help");
        //
        bool     badParams = false;
        uint32_t timeout   = 0;
        // ---------------------------------------------------------------------
        // process options
        if (s_progfile.empty()) {
                badParams = true;
        } else if (s_timeout.empty()) {
                printf("Executing without time limit\n");
        } else {
                timeout = std::stoul(s_timeout);
        }
        // check for help
        if (badParams || help) {
                printHelp();
                exit(EXIT_FAILURE);
        }
        // ---------------------------------------------------------------------
        CORETB *tb =new CORETB();
#ifdef DEBUG
        Verilated::scopesDump();
#endif
        if (trace) {
                int status = mkdir("vcd", S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
                if (status && errno != EEXIST) {
                        perror("[OS]");
                        fprintf(stderr, ANSI_COLOR_RED "[CORETB] Unable to create VCD folder\n" ANSI_COLOR_RESET);
                        exit(EXIT_FAILURE);
                }
                tb->OpenTrace("vcd/trace.vcd");
        }
        int exitCode = tb->SimulateCore(s_progfile, timeout, s_signature, use_uart);
        delete tb;
        return exitCode;
}
// -----------------------------------------------------------------------------
