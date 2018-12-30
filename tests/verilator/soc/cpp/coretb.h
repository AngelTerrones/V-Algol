/*
 * Copyright (C) 2018 Angel Terrones <angelterrones@gmail.com>
 */

#ifndef CORETB_H
#define CORETB_H

#include "Valgolsoc.h"
#include "testbench.h"

class CORETB: public Testbench<Valgolsoc> {
public:
        CORETB();
        int SimulateCore(const std::string &progfile, const unsigned long max_time, const std::string &signature, bool use_uart);
private:
        uint32_t PrintExitMessage (const bool ok, const unsigned long max_time);
        void     LoadMemory       (const std::string &progfile);
        void     DumpSignature    (const std::string &signature);
        void     UARTRx           ();
        bool     CheckTOHOST      (bool &ok);
        //
        uint32_t m_exitCode;
        uint32_t m_tohost;
        uint32_t m_fromhost;
        uint32_t m_begin_signature;
        uint32_t m_end_signature;
        uint8_t *m_mem;
        uint8_t  m_uartrx;
};

#endif
